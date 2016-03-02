defmodule Cps do
  def to_cps1(f) do
    fn a, k -> k.(f.(a)) end
  end

  def from_cps1(f) do
    fn a ->
      u = make_ref
      caller = self
      f.(a, &send(caller, {u, &1}))
      receive do
        {^u, r} -> r
      end
    end
  end
end

  
