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

GraphSpec.edges do
  a.x -> b.c
  q -> p
end

quote do
  GraphSpec.edges do
    a.x -> b.y
    q -> p
  end
end

IO.puts(Macro.to_string(Macro.expand_once(quote do
                                           GraphSpec.edges do
                                             a.x -> b.y
                                             q -> p
                                           end
        end, __ENV__)))

IO.puts(Macro.to_string(Macro.expand_once(quote do
                                           GraphSpec.edges([{:do, [q] -> p}])
        end, __ENV__)))
