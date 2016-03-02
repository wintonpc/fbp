import GraphSpec

defmodule NodeSpecs do
  defnode squarer(x: Number, returns: [r: Number]) do
    x * x
  end
  
  defnode stringer(x: Any, returns: [r: String]) do
    to_string(x)
  end
end

g = GraphSpec.new(inputs: [gin: Number], outputs: [gout: String])
g = GraphSpec.add_nodes(g,
                        squarer: NodeSpecs.squarer,
                        stringer: NodeSpecs.stringer)
GraphSpec.connect_many(g) do
  squarer.r -> stringer.x
  gin -> squarer.x
  stringer.s -> gout
end
GraphSpec.to_dot(g, "d")
