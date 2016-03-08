defmodule NodeSpec do
  defstruct name: nil, inputs: nil, outputs: nil, f: nil
  
  def from_cps1(name, f, opts \\ []) do
    inputs = opts[:inputs] || []
    outputs = opts[:outputs] || []
    %NodeSpec{name: name, inputs: inputs, outputs: outputs, f: f}
  end

  def find_input(node_spec, name) do
    Keyword.fetch!(node_spec.inputs, name)
  end

  def find_output(node_spec, name) do
    Keyword.fetch!(node_spec.outputs, name)
  end
end
