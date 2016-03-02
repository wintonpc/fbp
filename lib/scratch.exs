square = fn x -> x * x end

square_cps = Cps.to_cps1(square)

square_cps.(5, fn result -> IO.puts("result = #{result}") end)

sleep_cps = fn ms, k ->
  spawn fn ->
    k.(:timer.sleep(ms))
  end
end

sleep_cps.(1000, fn _ -> IO.puts("done") end)

sleep2 = Cps.from_cps1(sleep_cps)

sleep2.(1000)

square_ns = NodeSpec.from_cps1(Cps.to_cps1(square),
                               inputs: [x: Number],
                               outputs: [r: Number])

to_string_ns = NodeSpec.from_cps1(Cps.to_cps1(&to_string(&1)),
                                  inputs: [x: Any],
                                  outputs: [s: String])

g = GraphSpec.new(inputs: [gin: Number], outputs: [gout: String])
g = GraphSpec.add_nodes(g, squarer: square_ns, stringer: to_string_ns)
GraphSpec.connect_many(g) do
  squarer.r -> stringer.x
  gin -> squarer.x
  stringer.s -> gout
end
GraphSpec.to_dot(g, "d")
