defmodule GraphSpec.Validation do
  import Enum
  import Hacks
  
  def validate(node) do
    unique_port_names(node)
    unique_node_names(node)
    at_least_one_port(node)
    all_ports_connected(node)
    connected_ports_are_compatible(node)
  end

  def unique_port_names(node) do
    unique("port names", map(node.inputs ++ node.outputs, fn {k, _} -> k end))
  end

  def unique_node_names(%NodeSpec{}), do: :ok
  def unique_node_names(%GraphSpec{nodes: nodes}) do
    unique("child node names", map(nodes, fn %GraphSpec.NodeInst{name: name} -> name end))
  end

  def at_least_one_port(node) do
    if length(node.inputs ++ node.outputs) == 0 do
      raise "Error: node has no ports!"
    end
  end

  defstruct2 Port, [node, name, type]
  
  def connected_ports_are_compatible(%NodeSpec{}), do: :ok
  def connected_ports_are_compatible(%GraphSpec{} = g) do
    {sources, sinks} = all_ports(g)
    each g.edges, fn {{sn, sp} = src, {dn, dp} = dst} ->
      src_type = find_matching_port(sources, sn, sp)
      dst_type = find_matching_port(sinks, dn, dp)
      unless Type.is_assignable_from(Types.get_type(dst_type), Types.get_type(src_type)) do # TODO: fix hard dependency on Types
        raise "Error: #{format_port(src)} (#{GraphSpec.Dot.format_type(src_type)}) " <> # TODO: fix dependency on GraphSpec.Dot
          "cannot flow to #{format_port(dst)} (#{GraphSpec.Dot.format_type(dst_type)})"
      end
    end
  end

  defp find_matching_port(ports, node_name, port_name) do
    ports
    |> filter(port_matches(node_name, port_name))
    |> map(&(&1.type))
    |> single
  end

  defp port_matches(n_name, p_name) do
    fn %Port{node: node, name: name} ->
      n_name == node_name(node) && p_name == name
    end
  end
  
  def all_ports_connected(%NodeSpec{}), do: :ok
  def all_ports_connected(%GraphSpec{} = g) do
    {sources, sinks} = all_ports(g)
    {tails, heads} = all_ends(g)
    
    srcs = dedup(sort(map(sources, fn p -> {node_name(p.node), p.name} end)))
    dsts = dedup(sort(map(sinks,   fn p -> {node_name(p.node), p.name} end)))
    tails = dedup(sort(tails))
    heads = dedup(sort(heads))

    unconnected_sources = srcs -- tails
    unconnected_sinks = dsts -- heads
    unconnected_tails = tails -- srcs
    unconnected_heads = heads -- dsts

    check_for_connection_error("sink ports", unconnected_sinks)
    check_for_connection_error("source ports", unconnected_sources)
    check_for_connection_error("edge tails", unconnected_tails)
    check_for_connection_error("edge heads", unconnected_heads)
  end

  defp check_for_connection_error(what, xs) do
    if any?(xs) do
      raise "Error: the following #{what} are not connected: #{map_join(xs, ", ", &format_port/1)}"
    end
  end

  defp format_port({node_name, port_name}) do
    node_name = node_name || "this"
    "#{node_name}.#{port_name}"
  end

  def node_name(nil), do: nil
  def node_name(%GraphSpec.NodeInst{name: name}), do: name
  
  def all_ends(%GraphSpec{edges: edges}) do
    unzip(edges)
  end
  
  def all_ports(%GraphSpec{inputs: inputs, outputs: outputs, nodes: nodes}) do
    sources = map(inputs,  &ext_port/1) ++ flat_map(nodes, &map(&1.spec.outputs, int_port(&1)))
    sinks   = map(outputs, &ext_port/1) ++ flat_map(nodes, &map(&1.spec.inputs,  int_port(&1)))
    {sources, sinks}
  end

  def ext_port({name, type}) do
    %Port{name: name, type: type}
  end

  def int_port(node) do
    fn {name, type} ->
      %Port{node: node, name: name, type: type}
    end
  end

  def unique(what, xs) do
    duplicates = xs
    |> group_by(&(&1))
    |> filter(fn {_, dups} -> length(dups) > 1 end)
    |> map(fn {key, _} -> key end)
    if any?(duplicates) do
      raise "Error: duplicate #{what}: #{inspect(duplicates)}"
    end
  end

  def single(enum), do: do_single(to_list(enum))
  defp do_single([]), do: raise "attempted single([])"
  defp do_single([x]), do: x
  defp do_single(stream) when is_function(stream), do: do_single(Enum.to_list(Stream.take(stream, 1)))
  defp do_single(x), do: raise "attempted single(#{inspect(x)})"
end
