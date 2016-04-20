defmodule BuiltIn do
  import GraphSpec
  import Flow, only: [emit: 2, pop: 1]
  import Hacks
  
  def to_async(item_type) do
    node_spec(:to_async, i: Array.of(item_type), outputs: [o: AsyncArray.of(item_type)]) do
      Enum.each(i, &emit(o, &1))
    end
  end

  def from_async(item_type) do
    node_spec(:from_async, i: AsyncArray.of(item_type), outputs: [o: Array.of(item_type)]) do
      emit(o, Enum.reverse(Enum.reduce(i, [], fn (_, acc) ->
                case pop(i) do
                  :done ->
                    acc
                  {:item, x} ->
                    [x|acc]
                end
              end)))
    end
  end
end
