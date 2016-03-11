defmodule Flow do
  import Enum
  import Enum2
  import Hacks

  defstruct2 Input, [name, send]
  defstruct2 Emitter, [emit]
  defstruct2 WiredNode, [spec, sinks, subscribe, run]

  # messages
  # {:value, dest_port_name, value}
  #   Represents a value being sent to the receiving process/node's input port.
  # {:subscribe, src_port_name, send_func}
  #   Instructs the receiving process/node to connect an output port to the specified sink.
  #   - send_func receives a value and provides it to a sink port
  
  # spec is a NodeSpec or GraphSpec
  def run(spec, opts) do
    args = opts[:args] || []
    validate_args(args, spec)
    wn = wire(spec)
    each(wn.sinks, {name, send} ~> send.(args[name]))
    each(spec.outputs, {name, _} ~> wn.subscribe.(name, make_sender(self, name)))
    wn.run.()
    [values: receive_values(spec.outputs)]
  end

  defp validate_args(args, spec) do
    if length(args) != length(spec.inputs) do
      raise "Arguments mismatch.\n  inputs = #{inspect(spec.inputs)}\n  args = #{inspect(args)}"
    end
    # TODO: robustfy
  end
  
  def emit(%Emitter{emit: emit}, value) do
    emit.(value)
  end

  # expected is a keyword list, value_name -> value_type
  defp receive_values(expected), do: receive_values([], Keyword.keys(expected), expected)
  defp receive_values(acc, [], expected), do: reorder(acc, Keyword.keys(expected), {name, _} ~> name)
  defp receive_values(acc, remaining, expected) do
    IO.puts "receiving values..."
    receive do
      {:value, name, value} ->
        IO.puts "received #{inspect({name, value})}"
        type = expected[name]
        validate_type(value, type)
        new_remaining = remaining -- [name]
        if new_remaining == remaining do
          raise "unexpected value #{name}!"
        end
        receive_values([{name, value}|acc], new_remaining, expected)
    end
  end

  # returns {sinks, subscribe_func}
  # sinks is a keyword list of input_port_name -> send_func
  # subscribe_func takes a sink_map
  defp wire(%NodeSpec{inputs: inputs} = spec) do
    node_pid = spawn_link(fn -> run_node(spec) end)
    sinks = map(inputs, {name, _} ~> {name, make_sender(node_pid, name)})
    subscribe = fn (src_port_name, send_func) -> send(node_pid, {:subscribe, src_port_name, send_func}) end
    %WiredNode{spec: spec, sinks: sinks, subscribe: subscribe, run: fn -> send(node_pid, {:run}) end}
  end

  defp wire(%GraphSpec{nodes: node_insts, edges: edges} = gspec) do
    wired_nodes = map(node_insts, %GraphSpec.NodeInst{name: name, spec: spec} ~> {name, wire(spec)})
    each wired_nodes, fn {src_node_name, %WiredNode{spec: spec, subscribe: subscribe}} ->
      src_ports = map(spec.outputs, {src_port_name, _} ~> {src_node_name, src_port_name})
      each src_ports, fn ({src_node_name, src_port_name} = src_port) ->
        dst_send_funcs = dst_sinks(src_port, edges, wired_nodes)
        each dst_send_funcs, fn send_func ->
          subscribe.(src_port_name, send_func)
        end
      end
    end

    in_ports = map(gspec.inputs, {port_name, _} ~> {nil, port_name})
    sinks = map in_ports, fn ({_, port_name} = in_port) ->
      inner_sinks = dst_sinks(in_port, edges, wired_nodes)
      {port_name, value ~> each(inner_sinks, &(&1.(value)))}
    end


    out_ports = map(gspec.outputs, {port_name, _} ~> {nil, port_name})
    out_subscriber_map = map out_ports, fn ({_, op_name} = op) ->
      {src_node_name, src_port_name} = src_port(op, edges)
      wn = Keyword.fetch!(wired_nodes, src_node_name)
      {op_name, sink ~> wn.subscribe.(src_port_name, sink)}
    end
    
    subscribe = fn (ext_port_name, sink) ->
      sub_port = Keyword.fetch!(out_subscriber_map, ext_port_name)
      sub_port.(sink)
    end

    run_all = fn -> each(wired_nodes, {_, wn} ~> wn.run.()) end
    
    %WiredNode{spec: gspec, sinks: sinks, subscribe: subscribe, run: run_all}
  end

  defp dst_sinks(src_port, edges, wired_nodes) do
    dps = dst_ports(src_port, edges)
    map(dps, &find_sink(&1, wired_nodes))
  end

  defp dst_ports(src_port, edges) do
    edges
    |> filter({src, {dn, _} = dst} ~> (src == src_port && dn != nil)) # reject graph outputs. those will be subscribed later.
    |> map({_, dst} ~> dst)
  end

  defp src_port(dst_port, edges) do
    edges
    |> filter({_, dst} ~> (dst == dst_port))
    |> map({src, _} ~> src)
    |> single
  end

  defp find_sink({node_name, port_name}, wired_nodes) do
    Keyword.fetch!(Keyword.fetch!(wired_nodes, node_name).sinks, port_name)
  end

  defp make_sender(pid, port_name) do
    value ~> send_value(pid, port_name, value)
  end

  defp send_value(pid, name, value) do
    send(pid, {:value, name, value})
  end

  # node process code
  defp run_node(%NodeSpec{inputs: inputs, outputs: outputs, f: f}) do
    sink_map = accept_sink_map
    args = Keyword.values(receive_values(inputs))
    emitters = map(outputs, {name, _} ~> make_emitter(Keyword.fetch!(sink_map, name)))
    apply(f, args ++ emitters) # TODO: order according to inputs
  end

  defp accept_sink_map, do: accept_sink_map([])
  defp accept_sink_map(acc) do
    receive do
      {:subscribe, src_port_name, send_func} ->
        accept_sink_map(Keyword.update(acc, src_port_name, [send_func], senders ~> [send_func|senders]))
      {:run} ->
        acc
    after 3000 ->
        raise "subscribe much?!"
    end
  end

  defp make_emitter(sinks) do
    %Emitter{emit: value ~> each(sinks, &(&1.(value)))}
  end

  defp validate_type(value, type) do
    :ok # TODO: implement
  end
end
