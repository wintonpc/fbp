defmodule NodeSpec do
  defstruct type: nil, inputs: nil, outputs: nil, f: nil
  
  def make(type, f, opts \\ []) do
    inputs = opts[:inputs] || []
    outputs = opts[:outputs] || []
    n = %NodeSpec{type: type, inputs: GraphSpec.reify_types(inputs), outputs: GraphSpec.reify_types(outputs), f: f}
    GraphSpec.Validation.validate(n)
    n
  end

  def find_input(node_spec, name) do
    Keyword.fetch!(node_spec.inputs, name)
  end

  def find_output(node_spec, name) do
    Keyword.fetch!(node_spec.outputs, name)
  end
end
