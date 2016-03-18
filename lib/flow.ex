defmodule Flow do
  import Enum
  import Enum2
  import Hacks
  import GraphSpec
  
  defstruct2 Input, [name, send]
  defstruct2 Emitter, [emit]

  defmodule WiredNode do
    defstruct spec: nil, send_fns: nil, subscribe_fn: nil, run_fn: nil

    def send(%WiredNode{send_fns: send_fns}, port_name, value) do
      send_fns[port_name].(value)
    end

    def run(%WiredNode{run_fn: run_fn}) do
      run_fn.()
    end

    def subscribe(%WiredNode{subscribe_fn: subscribe_fn}, out_port_name, send_fn) do
      subscribe_fn.({out_port_name, send_fn})
    end
  end

  # messages
  # {:value, dest_port_name, value}
  #   Represents a value being sent to the receiving process/node's input port.
  # {:subscribe, src_port_name, send_fn}
  #   Instructs the receiving process/node to connect an output port to the specified sink.
  #   - send_fn receives a value and provides it to a sink port
  
  # spec is a NodeSpec or GraphSpec
  def run(spec, opts, env \\ nil) do
    args = opts[:args] || []
    validate_args(args, spec)
    wired_node = wire(spec, env)
    each(args, {name, value} ~> WiredNode.send(wired_node, name, value))
    each(out_port_names(spec), &WiredNode.subscribe(wired_node, &1, make_sender(self, &1)))
    WiredNode.run(wired_node)
    [values: receive_values(spec.outputs)]
  end

  defp validate_args(args, spec) do
    if length(args) != length(spec.inputs) do
      raise "Arguments mismatch.\n  inputs = #{inspect(spec.inputs)}\n  args = #{inspect(args)}"
    end
    # TODO: robustfy
  end
  
  # expected is a keyword list, value_name -> value_type
  defp receive_values(expected), do: receive_values([], Keyword.keys(expected), expected)
  defp receive_values(acc, [], expected), do: reorder(acc, Keyword.keys(expected), {name, _} ~> name)
  defp receive_values(acc, remaining, expected) do
    #IO.puts "receiving values..."
    receive do
      {:value, name, value} ->
        #IO.puts "received #{inspect({name, value})}"
        type = expected[name]
        validate_type(name, value, type)
        new_remaining = remaining -- [name]
        if new_remaining == remaining do
          raise "unexpected value #{name}!"
        end
        receive_values([{name, value}|acc], new_remaining, expected)
      {:DOWN, _, _, _, {exception, stacktrace}} = msg ->
        reraise exception, stacktrace
    end
  end

  defp validate_type(port_name, value, type) do
    unless Type.is_type(type, value) do
      raise "Expected \"#{port_name}\" to be a #{String.replace(to_string(type.name), "Elixir.", "")} " <>
        "but got #{inspect(value)}"
    end
  end
  
  # node process code
  defp run_node(%NodeSpec{inputs: inputs, outputs: outputs, f: f}, env) do
    sink_map = accept_sink_map
    args = Keyword.values(receive_values(inputs))
    emitters = map(outputs, {name, _} ~> make_emitter(sink_map[name]))
    apply(f, args ++ emitters ++ [env]) # TODO: order according to inputs
  end

  defp accept_sink_map, do: accept_sink_map([])
  defp accept_sink_map(acc) do
    receive do
      {:subscribe, src_port_name, send_fn} ->
        accept_sink_map(Keyword.update(acc, src_port_name, [send_fn], senders ~> [send_fn|senders]))
      :run ->
        acc
    after 3000 ->
        raise "subscribe much?!"
    end
  end

  defp make_emitter(send_fns) do
    %Emitter{emit: value ~> multi_call(send_fns, value)}
  end
  
  def emit(%Emitter{emit: emit}, value) do
    emit.(value)
  end

  defp wire(%NodeSpec{inputs: inputs} = spec, env) do
    node_pid = spawn(thunk(run_node(spec, env)))
    subscribe_fn = fn {out_port_name, send_fn} ->
      Process.monitor(node_pid)
      send_subscription(node_pid, out_port_name, send_fn)
    end
    %WiredNode{spec: spec,
               send_fns: map(in_port_names(spec), name ~> {name, make_sender(node_pid, name)}),
               subscribe_fn: subscribe_fn,
               run_fn: thunk(send_run(node_pid))}
  end

  defp wire(%GraphSpec{nodes: node_insts, edges: edges} = gspec, env) do
    wired_nodes = map(node_insts, %GraphSpec.NodeInst{name: name, spec: spec} ~> {name, wire(spec, env)})

    # subscribe the nodes to each other
    for {node_name, wn} <- wired_nodes,
        out_port <- out_ports(node_name, wn.spec),
        send_fn <- dst_send_fns(out_port, gspec, wired_nodes),
        do: WiredNode.subscribe(wn, name(out_port), send_fn)

    # send_fns for the exposed input ports delegate to internal send_fns
    send_fns = map in_ports(gspec), fn in_port ->
      internal_send_fns = dst_send_fns(in_port, gspec, wired_nodes)
      {name(in_port), value ~> multi_call(internal_send_fns, value)}
    end

    # subscribe_fn delegates to the internal subscribe_fns
    publisher_map = map out_ports(gspec), fn out_port ->
      {src_node_name, src_port_name} = src_port(gspec, out_port)
      src_wn = wired_nodes[src_node_name]
      {name(out_port), send_fn ~> WiredNode.subscribe(src_wn, src_port_name, send_fn)}
    end

    subscribe_fn = fn {out_port_name, send_fn} ->
      # find which node to actually subscribe to
      subscribe_to_port_fn = publisher_map[out_port_name]
      subscribe_to_port_fn.(send_fn)
    end

    run_all = thunk(each(wired_nodes, {_, wn} ~> WiredNode.run(wn)))
    
    %WiredNode{spec: gspec, send_fns: send_fns, subscribe_fn: subscribe_fn, run_fn: run_all}
  end

  defp dst_send_fns(src_port, gspec, wired_nodes) do
    dps = reject(dst_ports(gspec, src_port), &exposed_port?/1)
    map(dps, &find_send_fn(&1, wired_nodes))
  end

  defp find_send_fn({node_name, port_name}, wired_nodes) do
    wired_nodes[node_name].send_fns[port_name]
  end

  defp make_sender(pid, port_name) do
    value ~> send_value(pid, port_name, value)
  end

  defp send_value(pid, name, value) do
    send(pid, {:value, name, value})
  end

  defp send_subscription(pid, src_port_name, send_fn) do
    send(pid, {:subscribe, src_port_name, send_fn})
  end

  defp send_run(pid) do
    send(pid, :run)
  end
end
