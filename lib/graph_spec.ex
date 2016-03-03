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

  ############################################################

  defmacro defnode({name, _, [kws]}, [do: body]) do
    {[returns: outputs], inputs} = Enum.partition(kws, fn {k, _} -> k == :returns end)
    params = Enum.map(inputs, &{elem(&1, 0), [], nil})
    quote do
      def unquote({name, [], nil}) do
        NodeSpec.from_cps1(Cps.to_cps1(fn unquote_splicing(params) -> unquote(body) end),
        inputs: unquote(inputs),
        outputs: unquote(outputs))
      end
    end
  end
  
  defmacro connect_many(g, [do: []]), do: g
  defmacro connect_many(g, [do: [{:->, _, [[src], dst]}|rest]]) do
    quote do
      connect_many(GraphSpec.connect(unquote(g), unquote(fqport(src)), unquote(fqport(dst))), do: unquote(rest))
    end
  end

  defmacro edges([do: es]) do
    Enum.map es, fn {:->, _, [[src], dst]} ->
      {fqport(src), fqport(dst)}
    end
  end

  defp fqport({{:., _, [{name, _, _}, port]}, _, _}), do: {name, port}
  defp fqport({name, _, _}), do: name

  def render_dot(g, name, opts \\ []) do
    to_dot(g, name, opts)
    {output, 0} = System.cmd("dot", ["-Tpng", "-o", name <> ".png", name <> ".dot"])
    spawn fn ->
      {output, 0} = System.cmd("xdg-open", [name <> ".png"])
    end
  end
  
  def to_dot(g, name, opts \\ []) do
    show_ports = opts[:show_ports]
    file = File.open!(name <> ".dot", [:write])
    IO.puts(file, "digraph {")
    IO.puts(file, "rankdir=LR")
    IO.puts(file, "node [fontname=\"Bitstream Vera Sans\", fontsize=12]")
    IO.puts(file, "edge [fontname=\"Bitstream Vera Sans\", fontsize=8]")

    for {name, _} <- g.inputs, do: IO.puts(file, "#{name} [color=\"white\"]")
    for {name, _} <- g.outputs, do: IO.puts(file, "#{name} [color=\"white\"]")

    IO.puts(file, "subgraph cluster0 {")
    for {name, _} <- g.nodes, do: IO.puts(file, to_string(name))
    IO.puts(file, "}")

    Enum.each g.edges, fn {src, dst} ->
      case {src, dst} do
        {{src_name, src_port}, {dst_name, dst_port}} ->
          type = output_type(g, src_name, src_port)
          draw_edge(file, g, type, src_name, src_port, dst_name, dst_port, show_ports)
        {ext_name, {int_name, int_port}} ->
          type = input_type(g, int_name, int_port)
          draw_edge(file, g, type, ext_name, nil, int_name, int_port, show_ports)
        {{int_name, int_port}, ext_name} ->
          type = output_type(g, int_name, int_port)
          draw_edge(file, g, type, int_name, int_port, ext_name, nil, show_ports)
      end
    end
    
    IO.puts(file, "}")
    File.close(file)
  end

  defp input_type(g, node_name, port_name) do
    find_node(g, node_name) |> NodeSpec.find_input(port_name)
  end

  defp output_type(g, node_name, port_name) do
    find_node(g, node_name) |> NodeSpec.find_output(port_name)
  end
  
  defp find_node(g, name) do
    Keyword.fetch!(g.nodes, name)
  end

  defp draw_edge(file, g, type, sn, sl, dn, dl, show_ports) do
    type_string = List.last(Module.split(type))
    if show_ports do
      IO.puts(file, "#{dot_edge(sn, dn)} [label=\"#{type_string}\", taillabel=\"#{sl}\", headlabel=\"#{dl}\"]")
    else
      IO.puts(file, "#{dot_edge(sn, dn)} [label=\"#{type_string}\"]")
    end
  end

  defp dot_edge(src, dst) do
    "#{src} -> #{dst}"
  end
end
