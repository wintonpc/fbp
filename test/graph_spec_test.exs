defmodule GraphSpecTest do
  use ExUnit.Case
  use Types
  import GraphSpec
  
  test "new graph" do
    g = GraphSpec.new(
      :a_and_b,
      inputs: [i: String, x: String],
      outputs: [o: String],
      nodes: [a: node_a, b: node_b],
      connections: edges do
        i -> a.i
        a.o -> b.i
        b.o -> o
        x -> b.x
      end)

    sg = GraphSpec.new(
      :super,
      inputs: [i: String, x: String],
      outputs: [o: String],
      nodes: [g: g, h: g],
      connections: edges do
        x -> g.x
        x -> h.x
        i -> g.i
        g.o -> h.i
        h.o -> o
      end)
    GraphSpec.Dot.render_dot(sg, "sg")
  end

  def node_a do
    make_node(
      :a, &(&1),
      inputs: [i: String],
      outputs: [o: String])
  end

  def node_b do
    make_node(
      :b, &(&1),
      inputs: [i: String, x: String],
      outputs: [o: String])
  end
  
end
