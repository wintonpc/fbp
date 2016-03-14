defmodule GraphSpecTest do
  use ExUnit.Case
  #use Types
  import GraphSpec
  
  defnode a(i: String, outputs: [o: String]) do
    o.emit(i)
  end

  defnode b(i: String, x: String, outputs: [o: String]) do
    o.emit(i + x)
  end

  defgraph a_and_b(
    inputs: [i: String, x: String],
    outputs: [o: String],
    nodes: [a, b],
    connections: edges do
      this.i -> a.i
      a.o -> b.i
      b.o -> this.o
      this.x -> b.x
    end)

  defgraph twice(
    inputs: [i: String, x: String],
    outputs: [o: String],
    nodes: [g: a_and_b, h: a_and_b],
    connections: edges do
      this.x -> g.x
      this.x -> h.x
      this.i -> g.i
      g.o -> h.i
      h.o -> this.o
    end)

  test "new graph" do
    #GraphSpec.Dot.render_dot(twice, "twice")
  end

end
