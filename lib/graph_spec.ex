defmodule GraphSpec do
  defstruct nodes: nil, edges: nil, inputs: nil, outputs: nil

  def new(opts \\ []) do
    inputs = opts[:inputs] || []
    outputs = opts[:outputs] || []
    %GraphSpec{nodes: [], edges: [], inputs: inputs, outputs: outputs}
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
    quote do
      def unquote({name, [], nil}) do
        NodeSpec.from_cps1(Cps.to_cps1(&(&1)),
                           inputs: unquote(inputs),
                           outputs: unquote(outputs))
      end
    end
  end
  
  defmacro connect_many(g, [do: edges]) do
    quote do
      unquote_splicing(
        Enum.map edges, fn {:->, _, [[src], dst]} ->
          quote do
            unquote(g) = GraphSpec.connect(unquote(g), unquote(fqport(src)), unquote(fqport(dst)))
          end
        end)
    end
  end

  defp fqport({{:., _, [{name, _, _}, port]}, _, _}), do: {name, port}
  defp fqport({name, _, _}), do: name
  
  def to_dot(g, name) do
    file = File.open!(name <> ".dot", [:write])
    IO.puts(file, "digraph {")
    IO.puts(file, "rankdir=LR")

    for {name, _} <- g.inputs, do: IO.puts(file, "#{name} [color=\"white\"]")
    for {name, _} <- g.outputs, do: IO.puts(file, "#{name} [color=\"white\"]")

    IO.puts(file, "subgraph cluster0 {")
    for {name, _} <- g.nodes, do: IO.puts(file, to_string(name))
    IO.puts(file, "}")

    Enum.each g.edges, fn {src, dst} ->
      case {src, dst} do
        {{src_name, src_port}, {dst_name, dst_port}} ->
          type = g.nodes[src_name].outputs[src_port]
          draw_edge(file, g, type, src_name, src_port, dst_name, dst_port)
        {ext_name, {int_name, int_port}} ->
          type = g.nodes[int_name].inputs[int_port]
          draw_edge(file, g, type, ext_name, nil, int_name, int_port)
        {{int_name, int_port}, ext_name} ->
          type = g.nodes[int_name].outputs[int_port]
          draw_edge(file, g, type, int_name, int_port, ext_name, nil)
      end
    end
    
    IO.puts(file, "}")
    File.close(file)
  end

  defp draw_edge(file, g, type, sn, sl, dn, dl) do
    type_string = List.last(Module.split(type))
    IO.puts(file, "#{dot_edge(sn, dn)} [label=\"#{type_string}\", taillabel=\"#{sl}\", headlabel=\"#{dl}\"]")
  end

  defp dot_edge(src, dst) do
    "#{src} -> #{dst}"
  end
end
