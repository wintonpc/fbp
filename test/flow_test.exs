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
    #GraphSpec.Dot.render_dot(multi1, "graph")
    [values: [o: result]] = Flow.run(multi1, args: [a: 1, b: 2, c: 3])
    assert result == 9
  end

  defgraph multi2(
    inputs: [a: Number, b: Number, c: Number, d: Number],
    outputs: [o: Number, z: Number],
    nodes: [adder, p: multi1, q: multi1],
    connections: edges do
      this.a -> p.a
      this.a -> q.a
      this.b -> p.b
      this.b -> q.b
      this.c -> p.c
      this.d -> q.c
      p.o -> adder.a
      q.o -> adder.b
      q.o -> this.z
      adder.sum -> this.o
    end)

  test "graph flow 2" do
    #GraphSpec.Dot.render_dot(multi2, "graph")
    [values: [o: result, z: z]] = Flow.run(multi2, args: [a: 1, b: 2, c: 3, d: 10])
    assert result == 39
    assert z == 30
  end
  
end
