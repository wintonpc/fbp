defmodule FlowTest do
  use ExUnit.Case
  import GraphSpec
  import Flow, only: [emit: 2]
  
  defnode adder(a: Number, b: Number, outputs: [sum: Number]) do
    IO.puts "in adder, a = #{a}, b = #{b}"
    emit(sum, a + b)
  end

  defnode multiplier(a: Number, b: Number, outputs: [prod: Number]) do
    emit(prod, a * b)
  end

  test "primitive node flow" do
    [values: [sum: s]] = Flow.run(adder, args: [a: 1, b: 2])
    assert s == 3
  end

  defgraph multi1(
    inputs: [a: Number, b: Number, c: Number],
    outputs: [o: Number],
    nodes: [s: adder, m: multiplier],
    connections: edges do
      this.a -> s.a
      this.b -> s.b
      s.sum -> m.a
      this.c -> m.b
      m.prod -> this.o
    end)
  
  test "graph flow" do
    [values: [o: result]] = Flow.run(multi1, args: [a: 1, b: 2, c: 3])
    assert result == 9
  end
  
end
