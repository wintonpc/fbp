import GraphSpec

defmodule NodeSpecs do
  defnode squarer(i: Number, returns: [o: Number]) do
    i * i
  end  
  defnode stringer(i: Any, returns: [o: String]) do
    to_string(i)
  end
end

g = GraphSpec.new(inputs: [gin: Number], outputs: [gout: String])

g = GraphSpec.add_nodes(g, squarer: NodeSpecs.squarer, stringer: NodeSpecs.stringer)

g = GraphSpec.connect_many(g) do
  gin -> squarer.i
  squarer.o -> stringer.i
  stringer.o -> gout
end

GraphSpec.render_dot(g, "d")
