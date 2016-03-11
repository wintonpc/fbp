defmodule Flow do
  import Enum
  import Enum2
  import Hacks

  defstruct2 Input, [name, send]
  defstruct2 Emitter, [emit]

  # messages
  # {:value, dest_port_name, value}
  #   Represents a value being sent to the receiving process/node's input port.
  # {:subscribe, sink_map}
  #   Instructs the receiving process/node to connect its output ports to the specified sinks.
  #   - sink_map is a keyword list of output_port -> senders
  #   - senders is a list of send functions
  #   - a send function receives a value and provides it to a sink port
  
  # spec is a NodeSpec or GraphSpec
  def run(spec, opts) do
    args = opts[:args] || []
    validate_args(args, spec)
    {sinks, subscribe} = wire(spec)
    each(sinks, {name, send} ~> send.(args[name]))
    subscribe.(map(spec.outputs, {name, _} ~> {name, [make_sender(self, name)]}))
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
        validate_type(value, type) # should this be on the server side?
        new_remaining = remaining -- [name]
        if new_remaining == remaining, do: raise "unexpected value #{name}!"
        receive_values([{name, value}|acc], new_remaining, expected)
    end
  end

  # returns {sinks, subscribe_func}
  # sinks is a keyword list of input_port_name -> send_func
  # subscribe_func takes a sink_map
  defp wire(%NodeSpec{inputs: inputs} = spec) do
    node_pid = spawn_link(fn -> run_node(spec) end)
    sinks = map(inputs, {name, _} ~> {name, make_sender(node_pid, name)})
    subscribe = sink_map ~> send(node_pid, {:subscribe, sink_map})
    {sinks, subscribe}
  end

  defp wire(%GraphSpec{}) do
    :ok
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
    emitters = map(outputs, {name, _} ~> make_emitter(sink_map[name]))
    apply(f, args ++ emitters) # TODO: order according to inputs
  end

  defp accept_sink_map do
    receive do
      {:subscribe, sink_map} -> sink_map
    end
  end

  defp make_emitter(sinks) do
    %Emitter{emit: value ~> each(sinks, &(&1.(value)))}
  end

  defp validate_type(value, type) do
    :ok # TODO: implement
  end
end
