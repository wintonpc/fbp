defmodule Fbp do
  use Application
  
  def start(_type, _args) do
    Types.define_all
    {:ok, self}
  end
end
