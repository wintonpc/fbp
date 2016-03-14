defmodule GraphSpec.Validation do
  import Enum
  import Enum2
  import Hacks
  
  def validate(node) do
    unique_port_names(node)
    unique_node_names(node)
    at_least_one_port(node)
    all_ports_connected(node)
    connected_ports_are_compatible(node)
    no_cycles(node)
    no_implicit_merges(node)
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

  def no_cycles(%NodeSpec{}), do: :ok
  def no_cycles(%GraphSpec{nodes: nodes, edges: edges}) do
    import List, only: [first: 1, last: 1]
    case Topology.with_graph(nodes, &(&1.name), &(&1), &internal_efferents(&1, edges), fn _ -> :ok end) do
      {:error, {:cycle, names}} ->
        names = if first(names) != last(names), do: names ++ [first(names)], else: names
        raise "Error: the graph has a cycle: #{map_join(names, " -> ", &to_string(&1))}"
      x ->
        x
    end
  end

  defp internal_efferents(node, edges) do
    edges
    |> filter(fn {{sn, sp}, {dn, dp}} -> sn != nil && dn != nil && sn == node_name(node) end)
    |> map(fn {_, {dn, _}} -> dn end)
  end
  
  def connected_ports_are_compatible(%NodeSpec{}), do: :ok
  def connected_ports_are_compatible(%GraphSpec{} = g) do
    {sources, sinks} = all_ports(g)
    each g.edges, fn {{sn, sp} = src, {dn, dp} = dst} ->
      src_type = find_matching_port(sources, sn, sp)
      dst_type = find_matching_port(sinks, dn, dp)
      unless Type.is_assignable_from(Type.get_type(dst_type), Type.get_type(src_type)) do # TODO: fix hard dependency on Types
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

  defp port_matches({n_name, p_name}), do: port_matches(n_name, p_name)
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

    check_for_direction_error(sinks, tails, g.edges, "sink", "source", &edge_tail/1)
    check_for_direction_error(sources, heads, g.edges, "source", "sink", &edge_head/1)
    check_for_connection_error("sink ports", unconnected_sinks)
    check_for_connection_error("source ports", unconnected_sources)
    check_for_connection_error("edge tails", unconnected_tails)
    check_for_connection_error("edge heads", unconnected_heads)
  end

  defp simple_port(%Port{node: node, name: name}) do
    {node_name(node), name}
  end
  
  defp no_implicit_merges(%NodeSpec{}), do: :ok
  defp no_implicit_merges(%GraphSpec{} = g) do
    {_, sinks} = all_ports(g)
    {_, heads} = all_ends(g)
    
    implicit_merge = sinks
    |> map(fn s -> {s, filter(heads, &port_matches(&1).(s))} end)
    |> filter(fn {_, heads} -> length(heads) > 1 end)
    |> List.first

    if implicit_merge do
      {s, heads} = implicit_merge
      simple_s = simple_port(s)
      afferent_sources = g.edges
      |> filter(fn {_, dst} -> dst == simple_s end)
      |> map(fn {src, _} -> src end)
      
      raise "Error: invalid merge: #{map_join(afferent_sources, " + ", &format_port/1)} -> #{format_port(simple_s)}"
    end
  end

  defp check_for_direction_error(ports, ends, edges, actual, used_as, end_selector) do
    errors = for p <- ports, {n_name, p_name} <- ends, port_matches(n_name, p_name).(p), do: {p, {n_name, p_name}}
    case errors do
      [{p, e}|_] ->
        formatted_port = format_port({node_name(p.node), p.name})
        bad_edge = edges
        |> filter(&(end_selector.(&1) == e))
        |> List.first
        raise "Error: #{formatted_port} is a #{actual} and cannot be used as a #{used_as} " <>
          "(in #{format_edge(bad_edge)})"
      _ ->
        :ok
    end
  end

  defp edge_tail({x, _}), do: x
  defp edge_head({_, x}), do: x

  defp format_edge({src, dst}) do
    "#{format_port(src)} -> #{format_port(dst)}"
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
end
