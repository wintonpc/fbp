defmodule NodeSpec do
  defstruct type: nil, inputs: nil, outputs: nil, f: nil
  
  def from_cps1(type, f, opts \\ []) do
    inputs = opts[:inputs] || []
    outputs = opts[:outputs] || []
    %NodeSpec{type: type, inputs: inputs, outputs: outputs, f: f}
  end

  def find_input(node_spec, name) do
    Keyword.fetch!(node_spec.inputs, name)
  end

  def find_output(node_spec, name) do
    Keyword.fetch!(node_spec.outputs, name)
  end
end
