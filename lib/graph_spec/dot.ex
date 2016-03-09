defmodule GraphSpec.Dot do
  import Enum
  
  def render_dot(g, name, opts \\ []) do
    to_dot(g, name, opts)
    case System.cmd("dot", ["-Tpng", "-o", name <> ".png", name <> ".dot"]) do
      {output, 0} ->
        spawn fn ->
          {output, 0} = System.cmd("xdg-open", [name <> ".png"])
        end
      _ ->
        raise "dot failed"
    end
  end
  
  def to_dot(g, name, opts \\ []) do
    show_ports = opts[:show_ports]
    file = File.open!(name <> ".dot", [:write])
    IO.puts(file, "digraph {")
    IO.puts(file, "rankdir=LR")
    IO.puts(file, "node [fontname=\"Bitstream Vera Sans\", fontsize=12, shape=rect, style=rounded]")
    IO.puts(file, "edge [fontname=\"Bitstream Vera Sans\", fontsize=8]")

    gen = Incrementor.new(0, &"n#{&1}")
    write(file, GraphSpec.make_id("nil"), nil, g, gen)
    
    IO.puts(file, "}")
    File.close(file)
  end

  defp write(f, id, name, %GraphSpec{} = g, gen) do
    IO.puts(f, "subgraph cluster_#{id} {")
    IO.puts(f, header_label(name, g.type))
    write_port_group(f, id, g.inputs, gen)
    write_port_group(f, id, g.outputs, gen)
    for n <- g.nodes, do: write(f, n.id, n.name, n.spec, gen)
    node_name_to_id = Map.new(g.nodes, &{&1.name, &1.id})
    each g.edges, fn {src, dst} ->
      {sn, _} = src
      src_node = GraphSpec.find_node_by_name(g, sn)
      connect(f, id, src_node, src, dst, node_name_to_id)
    end
    IO.puts(f, "}")
    if name == nil do # outermost graph
      write_external_connections(f, id, g, node_name_to_id, gen)
    end
  end

  defp write_external_connections(f, id, g, node_name_to_id, gen) do
    each g.inputs, fn {port_name, type} ->
      n = Incrementor.next(gen)
      IO.puts(f, "#{n} [label=\"#{format_type(type)}\", shape=plaintext, fontsize=8]")
      IO.puts(f, "#{n} -> #{port(id, {nil, port_name}, node_name_to_id)}")
    end
    each g.outputs, fn {port_name, type} ->
      n = Incrementor.next(gen)
      IO.puts(f, "#{n} [label=\"#{format_type(type)}\", shape=plaintext, fontsize=8]")
      IO.puts(f, "#{port(id, {nil, port_name}, node_name_to_id)} -> #{n}")
    end
  end

  defp connect(f, id, src_node, {sn, sp} = src, {dn, dp} = dst, node_name_to_id) do
    style = if sn == nil || dn == nil do
      "[arrowhead=none]"
    else
      type = (src_node.spec.outputs)[sp]
      "[label=\"#{format_type(type)}\"]"
    end
    src_id = port(id, src, node_name_to_id)
    dst_id = port(id, dst, node_name_to_id)
    IO.puts(f, "#{src_id} -> #{dst_id} #{style}")
  end

  def format_type(%GenericType{name: name, argument: arg}) do
    "#{format_type(name)}.of(#{format_type(arg)})"
  end

  def format_type(%StructType{name: name}) do
    format_type(name)
  end
  
  def format_type(%BasicType{name: name}) do
    format_type(name)
  end
  
  def format_type(type) do
    #String.replace(to_string(type), "Elixir.", "")
    List.last(Module.split(type))
  end

  defp port(id, {nil, port_name}, node_name_to_id) do
    "port_#{id}_#{port_name}"
  end
  
  defp port(_, {node_name, port_name}, node_name_to_id) do
    "port_#{node_name_to_id[node_name]}_#{port_name}"
  end

  defp write(f, id, name, %NodeSpec{} = node, gen) do
    IO.puts(f, "subgraph cluster_#{id} {")
    IO.puts(f, "bgcolor=lightskyblue1")
    IO.puts(f, "label=\"\"")
    IO.puts(f, "node_#{id} [#{header_label(name, node.type)}]")
    write_port_group(f, id, node.inputs, gen)
    write_port_group(f, id, node.outputs, gen)
    connect_input_ports(f, id, node)
    connect_output_ports(f, id, node)
    IO.puts(f, "}")    
  end

  defp connect_input_ports(f, id, node) do
    each node.inputs, fn {name, _type} ->
      IO.puts(f, "port_#{id}_#{name} -> node_#{id} [arrowhead=none]")
    end
  end

  defp connect_output_ports(f, id, node) do
    each node.outputs, fn {name, _type} ->
      IO.puts(f, "node_#{id} -> port_#{id}_#{name} [arrowhead=none]")
    end
  end

  defp write_port_group(f, node_id, ports, gen) do
    IO.puts(f, "{")
    IO.puts(f, "rank=same")
    map ports, fn {name, _type} ->
      IO.puts(f, "port_#{node_id}_#{name} [label=\"#{name}\", #{port_style}]")
    end
    IO.puts(f, "}")
  end

  defp port_style do
    "shape=rect, fontsize=8, style=filled, fixedsize=true, height=0.25, width=0.4, fillcolor=lightsteelblue3"
  end
  
  defp header_label(nil, type) do
    "label=\"#{type}\""
  end
  
  defp header_label(name, type) do
    "label=\"#{type}#{header_label_name(name, type)}\""
  end

  defp header_label_name(name, type) do
    if name == type, do: "", else: "\\n\\\"#{name}\\\""
  end
end
