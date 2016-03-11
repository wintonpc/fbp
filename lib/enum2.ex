defmodule Enum2 do
  import Enum
  
  def reorder(xs, order, get_key) do
    map(order, fn o -> detect(xs, get_key, o) end)
  end

  def detect(xs, x_to_needle, needle) do
    find(xs, fn x -> x_to_needle.(x) == needle end)
  end

  def single(enum), do: do_single(to_list(enum))
  defp do_single([]), do: raise "attempted single([])"
  defp do_single([x]), do: x
  defp do_single(stream) when is_function(stream), do: do_single(Enum.to_list(Stream.take(stream, 1)))
  defp do_single(x), do: raise "attempted single(#{inspect(x)})"
end
