defmodule Incrementor do
  def new(init \\ 0, mapper \\ &(&1)) do
    {:ok, a} = Agent.start_link(fn -> init end)
    {a, mapper}
  end

  def next({a, mapper}) do
    mapper.(Agent.get_and_update(a, fn i -> {i, i+1} end))
  end
end
