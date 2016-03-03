defmodule Incrementor do
  def new(init \\ 0) do
    {:ok, a} = Agent.start_link(fn -> init end)
    a
  end

  def next(incrementor) do
    Agent.get_and_update(incrementor, fn i -> {i, i+1} end)
  end
end
