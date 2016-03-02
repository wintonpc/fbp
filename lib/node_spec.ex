defmodule NodeSpec do
  defstruct inputs: nil, outputs: nil, f: nil
  
  def from_cps1(f, opts \\ []) do
    inputs = opts[:inputs] || []
    outputs = opts[:outputs] || []
    %NodeSpec{inputs: inputs, outputs: outputs, f: f}
  end
end
