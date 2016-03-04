defmodule GraphSpec do
  defstruct nodes: nil, edges: nil, inputs: nil, outputs: nil

  def new(opts \\ []) do
    inputs = opts[:inputs] || []
    outputs = opts[:outputs] || []
    nodes = opts[:nodes] || []
    connections = opts[:connections] || []
    g = %GraphSpec{nodes: [], edges: connections, inputs: inputs, outputs: outputs}
    add_nodes(g, nodes)
  end

  def add_nodes(g, node_specs) do
    %GraphSpec{g | nodes: g.nodes ++ node_specs}
  end
  
  def connect(g, src_port, dst_port) do
    %GraphSpec{g | edges: [{src_port, dst_port}|g.edges]}
  end

  def make_node(f, opts \\ []) do
    NodeSpec.from_cps1(Cps.to_cps1(f), opts)
  end
  
  defmacro defnode({name, _, [kws]}, [do: body]) do
    {[returns: outputs], inputs} = Enum.partition(kws, fn {k, _} -> k == :returns end)
    params = Enum.map(Enum.concat(inputs, outputs), &{elem(&1, 0), [], nil})
    quote do
      def unquote({name, [], nil}) do
        GraphSpec.make_node(fn unquote_splicing(params) -> unquote(body) end,
        inputs: unquote(inputs),
        outputs: unquote(outputs))
      end
    end
  end
  
  defmacro edges([do: es]) do
    Enum.map es, fn {:->, _, [[src], dst]} ->
      {fqport(src), fqport(dst)}
    end
  end

  defp fqport({{:., _, [{name, _, _}, port]}, _, _}), do: {name, port}
  defp fqport({name, _, _}), do: name
end
