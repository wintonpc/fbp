defmodule Enum2 do
  import Enum
  
  def reorder(xs, order, get_key) do
    map(order, fn o -> detect(xs, get_key, o) end)
  end

  def detect(xs, x_to_needle, needle) do
    find(xs, fn x -> x_to_needle.(x) == needle end)
  end
end
