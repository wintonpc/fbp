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
          type_string = List.last(Module.split(type))
          IO.puts(file, "#{dot_edge(src_name, dst_name)} [label=\"#{type_string}\", taillabel=\"#{src_port}\", headlabel=\"#{dst_port}\"]")
        {ext_name, {int_name, int_port}} ->
          type = g.nodes[int_name].inputs[int_port]
          type_string = List.last(Module.split(type))
          IO.puts(file, "#{dot_edge(ext_name, int_name)} [label=\"#{type_string}\", headlabel=\"#{int_port}\"]")
        {{int_name, int_port}, ext_name} ->
          type = g.nodes[int_name].outputs[int_port]
          type_string = List.last(Module.split(type))
          IO.puts(file, "#{dot_edge(int_name, ext_name)} [label=\"#{type_string}\", taillabel=\"#{int_port}\"]")
        _ -> :ok
      end
    end
    
    IO.puts(file, "}")
    File.close(file)
  end

  defp dot_edge(src, dst) do
    "#{src} -> #{dst}"
  end
end
