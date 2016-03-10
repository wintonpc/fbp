defmodule Flow do
  import Enum
  import Hacks

  defstruct2 Input, [name, proc, send]
  defstruct2 Subscriber, [subscribe]
  defstruct2 Emitter, [emit]
  
  def run(node, opts) do
    args = opts[:args] || []
    validate_args(args, node)
    {p, inputs, subscriber} = wire(node)
    each(inputs, &(&1.send.(args[&1.name])))
    subscriber.subscribe.(map(node.outputs, fn {name, _} -> {name, [self]} end))
    [values: receive_values(Keyword.keys(node.outputs))]
  end

  defp receive_values(expected), do: receive_values([], expected)
  defp receive_values(acc, []), do: acc
  defp receive_values(acc, expected) do
    IO.puts "receiving values..."
    receive do
      {:value, name, value} ->
        IO.puts "received #{inspect({name, value})}"
        new_expected = expected -- [name]
        if new_expected == expected do
          raise "unexpected value #{name}!"
        end
        receive_values([{name, value}|acc], new_expected)
    end
  end

  def validate_args(args, node) do
    if length(args) != length(node.inputs) do
      raise "Arguments mismatch.\n  inputs = #{inspect(node.inputs)}\n  args = #{inspect(args)}"
    end
    # TODO: robustfy
  end
  
  def wire(%NodeSpec{inputs: inputs} = node) do
    p = spawn_link(fn -> node_loop(node) end)
    inps = map inputs, fn {name, type} ->
      send_func = fn value ->
        validate_type(value, type) # should this be on the server side?
        send(p, {:value, name, value})
      end
      %Input{name: name, proc: p, send: send_func}
    end
    subscriber = %Subscriber{subscribe: fn subscribers -> send(p, {:subscribers, subscribers}) end}
    {p, inps, subscriber}
  end

  def wire(%GraphSpec{}) do
    :ok
  end

  def node_loop(%NodeSpec{} = node) do
    subscriber_map = receive do
      {:subscribers, subscriber_map} -> subscriber_map
    end
    args = reorder2(receive_values(Keyword.keys(node.inputs)), node.inputs)
    emitters = reorder2(map(node.outputs, fn {name, _} -> {name, make_emitter(self, name, subscriber_map[name])} end), node.outputs)
    apply(node.f, args ++ emitters) # TODO: order according to inputs
  end

  def make_emitter(node_proc, name, subscribers) do
    %Emitter{emit: fn value -> broadcast(subscribers, {:value, name, value}) end}
  end

  def broadcast(procs, msg) do
    each(procs, &send(&1, msg))
  end

  def validate_type(value, type) do
    :ok # TODO: implement
  end

  defp reorder(xs, order, get_key) do
    Enum.map(order, fn o -> Enum.find(xs, fn x -> get_key.(x) == o end) end)
  end

  defp reorder2(named_values, inputs_or_outputs) do
    Keyword.values(reorder(named_values, Keyword.keys(inputs_or_outputs), fn {name, _} -> name end))
  end
end
