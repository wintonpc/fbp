defmodule FlowTest do
  use ExUnit.Case
  import GraphSpec
  import Flow, only: [emit: 2]
  import TestUtil

  setup do
    Types.define_all
  end
  
  defnode adder(a: Number, b: Number, outputs: [sum: Number]) do
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

  test "bad input types" do
    assert_error(Flow.run(adder, args: [a: 1, b: "two"]),
                 "Expected \"b\" to be a Number but got \"two\"")
  end
  
  defnode bad_adder(a: Number, b: Number, outputs: [sum: Number]) do
    emit(sum, "a + b")
  end

  test "bad output types" do
    assert_error(Flow.run(bad_adder, args: [a: 1, b: 2]),
                 "Expected \"sum\" to be a Number but got \"a + b\"")
  end

  defnode bad_adder2(a: Number, b: Number, outputs: [sum: Number]) do
    emit(sum, a + b)
    raise "oops"
  end

  test "error after everything emitted" do
    # doesn't affect downstream nodes
    [values: [sum: 3]] = Flow.run(bad_adder2, args: [a: 1, b: 2])
  end


  defnode add2(a: Number, b: Number, outputs: [sum: Number]) do
    emit(sum, a + b)
  end

  defgraph add3(inputs: [a: Number, b: Number, c: Number],
                outputs: [sum: Number],
                nodes: [x: add2, y: add2],
                connections: edges do
                  this.a -> x.a
                  this.b -> x.b
                  x.sum -> y.a
                  this.c -> y.b
                  y.sum -> this.sum
                end)
  
  test "readme" do
    GraphSpec.Dot.render_dot(add2, "add2")
    GraphSpec.Dot.render_dot(add3, "add3")
  end
    
end
