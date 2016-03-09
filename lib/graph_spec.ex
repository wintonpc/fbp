defmodule GraphSpec do
  import Hacks
  import Enum
  defstruct type: nil, nodes: nil, edges: nil, inputs: nil, outputs: nil
  defstruct2 NodeInst, [id, name, spec]
  
  def new(type, opts \\ []) do
    inputs = opts[:inputs] || []
    outputs = opts[:outputs] || []
    nodes = opts[:nodes] || []
    connections = opts[:connections] || []
    node_insts = instantiate_nodes(nodes)
    g = %GraphSpec{type: type, nodes: node_insts, edges: connections, inputs: inputs, outputs: outputs}
    validate(g)
  end

  defp id_for_name(name, nodes) do
    nodes
    |> filter(&(&1.name == name))
    |> map(&(&1.id))
    |> List.first
  end

  def find_node_by_name(g, name) do
    g.nodes
    |> filter(&(&1.name == name))
    |> List.first
  end

  defp duplicate(%NodeSpec{} = n), do: n
  defp duplicate(%GraphSpec{} = g) do
    %GraphSpec{g | nodes: instantiate_nodes(map(g.nodes, &{&1.name, &1.spec}))}
  end
  
  # def add_nodes(g, node_specs) do
  #   %GraphSpec{g | nodes: g.nodes ++ node_specs}
  # end

  defp instantiate_nodes(specs) do
    map specs, fn
      ({name, spec}) ->
        %NodeInst{id: make_id(name), name: name, spec: duplicate(spec)}
      (spec) ->
        %NodeInst{id: make_id(spec.type), name: spec.type, spec: duplicate(spec)}
    end
  end

  def make_id(name) do
    "#{name}_#{String.replace(UUID.uuid1(), "-", "")}"
  end
  
  defp validate(g) do
    duplicate_names = g.nodes
    |> group_by(&(&1.name))
    |> filter(fn {_, nodes} -> length(nodes) > 1 end)
    |> map(fn {name, _} -> name end)
    
    if any?(duplicate_names) do
      raise "Error: graph has duplicate node names: #{inspect(duplicate_names)}"
    else
      g
    end
  end
  
  def connect(g, src_port, dst_port) do
    %GraphSpec{g | edges: [{src_port, dst_port}|g.edges]}
  end

  def make_node(name, f, opts \\ []) do
    NodeSpec.from_cps1(name, Cps.to_cps1(f), opts)
  end
  
  defmacro defnode({name, _, [kws]}, [do: body]) do
    {[returns: outputs], inputs} = Enum.partition(kws, fn {k, _} -> k == :returns end)
    params = Enum.map(Enum.concat(inputs, outputs), &{elem(&1, 0), [], nil})
    quote do
      def unquote({name, [], nil}) do
        GraphSpec.make_node(unquote(name), fn unquote_splicing(params) -> unquote(body) end,
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
  defp fqport({port, _, _}), do: {nil, port}
end
