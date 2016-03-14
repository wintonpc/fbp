defmodule GraphSpec do
  import Hacks
  import Enum
  import Enum2
  
  defstruct type: nil, nodes: nil, edges: nil, inputs: nil, outputs: nil
  defstruct2 NodeInst, [id, name, spec]
  
  def new(type, opts \\ []) do
    expect_keywords(opts, [:inputs, :outputs, :nodes, :connections])
    inputs = opts[:inputs] || []
    outputs = opts[:outputs] || []
    nodes = opts[:nodes] || []
    connections = opts[:connections] || []
    node_insts = instantiate_nodes(nodes)
    g = %GraphSpec{type: type, nodes: node_insts, edges: connections,
                   inputs: reify_types(inputs),
                   outputs: reify_types(outputs)}
    GraphSpec.Validation.validate(g)
    g
  end

  def reify_types(port_specs) do
    map(port_specs, {name, type} ~> {name, Type.get_type(type)})
  end

  defp id_for_name(name, nodes) do
    nodes
    |> filter(&(&1.name == name))
    |> map(&(&1.id))
    |> List.first
  end

  def find_node_by_name(g, nil), do: g
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
    NodeSpec.make(name, f, opts)
  end

  def dst_ports(%GraphSpec{edges: edges}, src_port) do
    paired_ports(edges, src_port)
  end

  def src_port(%GraphSpec{edges: edges}, dst_port) do
    single(paired_ports(map(edges, &flip_tuple/1), dst_port))
  end

  defp paired_ports(edges, first_port) do
    filter_map(edges,
               {a, _} ~> (a == first_port),
               {_, b} ~> b)
  end

  def in_ports(%GraphSpec{inputs: inputs}) do
    map(inputs, {port_name, _type} ~> {nil, port_name})
  end

  def out_ports(%GraphSpec{outputs: outputs}) do
    map(outputs, {port_name, _type} ~> {nil, port_name})
  end

  def in_ports(node_name, spec) do
    map(in_port_names(spec), &{node_name, &1})
  end

  def out_ports(node_name, spec) do
    map(out_port_names(spec), &{node_name, &1})
  end

  def in_port_names(spec) do
    map(spec.inputs, {name, _type} ~> name)
  end

  def out_port_names(spec) do
    map(spec.outputs, {name, _type} ~> name)
  end

  def name({_node_name, port_name} = _port), do: port_name

  defp flip_tuple({a, b}), do: {b, a}

  def exposed_port?({node_name, _port_name}), do: node_name == nil
  
  defmacro defnode({name, _, [kws]}, [do: body]) do
    {[outputs: outputs], inputs} = Enum.partition(kws, fn {k, _} -> k == :outputs end)
    params = Enum.map(Enum.concat(inputs, outputs), &{elem(&1, 0), [], nil})
    quote do
      def unquote({name, [], nil}) do
        GraphSpec.make_node(unquote(name), fn unquote_splicing(params) -> unquote(body) end,
        inputs: unquote(inputs),
        outputs: unquote(outputs))
      end
    end
  end

  defmacro defgraph({name, _, [kws]}) do
    quote do
      def unquote({name, [], nil}) do
        GraphSpec.new(unquote(name), unquote(kws))
      end
    end
  end

  defmacro edges([do: es]) do
    Enum.map es, fn {:->, _, [[src], dst]} ->
      {fqport(src), fqport(dst)}
    end
  end

  defp expect_keywords(kws, expected_keys) do
    unexpected = Keyword.keys(kws) -- expected_keys
    if any?(unexpected) do
      raise "Unexpected keywords: #{inspect(unexpected)}"
    end
  end

  defp fqport({{:., _, [{:this, _, _}, port]}, _, _}), do: {nil, port}
  defp fqport({{:., _, [{name, _, _}, port]}, _, _}), do: {name, port}
  defp fqport(_), do: {nil, nil} # hack for demo (split/merge)
end
