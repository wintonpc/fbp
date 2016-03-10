defmodule Topology do
  import Hacks

  defstruct2 Graph, [digraph]

  def with_graph(nodes, node_id_func, efferent_id_func, efferents_func, callback) do
    g = :digraph.new([:acyclic])
    try do
      populate_graph(g, nodes, node_id_func, efferent_id_func, efferents_func)
      callback.(g)
    catch
      error -> {:error, error}
    after
      :digraph.delete(g)
    end
  end

  defp populate_graph(g, nodes, node_id_func, efferent_id_func, efferents_func) do
    for n <- nodes, do: :digraph.add_vertex(g, node_id_func.(n))
    for n <- nodes, e <- efferents_func.(n) do
      case :digraph.add_edge(g, node_id_func.(n), efferent_id_func.(e)) do
        {:error, {:bad_edge, path}} -> throw({:cycle, path})
        _ -> :ok
      end
    end
  end

end
