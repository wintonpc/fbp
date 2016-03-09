defmodule GraphSpec.ValidationTest do
  use ExUnit.Case
  use Types
  import GraphSpec, only: :macros
  
  defmacro assert_error(exp, msg) do
    quote do
      case catch_error(unquote(exp)) do
        %RuntimeError{message: m} ->
          assert m == unquote(msg)
        x ->
          flunk "Unexpected return value: #{inspect(x)}"
      end
    end
  end
  
  test "unique port names" do
    assert_error(make_node(:foo, inputs: [a: String, a: Number], outputs: []),
                 "Error: duplicate port names: [:a]")
    assert_error(make_node(:foo, inputs: [], outputs: [a: String, a: Number]),
                 "Error: duplicate port names: [:a]")
    assert_error(make_node(:foo, inputs: [a: String], outputs: [a: Number]),
                 "Error: duplicate port names: [:a]")
  end

  test "unique child names" do
    assert_error(make_graph(:g, nodes: [a: node_a, a: node_b]),
                 "Error: duplicate child node names: [:a]")
  end

  test "at least one port" do
    assert_error(make_node(:foo), "Error: node has no ports!")
    assert_error(make_graph(:g), "Error: node has no ports!")
  end

  test "unconnected sink port" do
    assert_error(make_graph(:g,
                            inputs: [i: String],
                            outputs: [o: Number, z: Number],
                            nodes: [a: node_a],
                            connections: edges do
                              this.i -> a.i
                              a.o -> this.o
                            end),
                 "Error: the following sink ports are not connected: this.z")
  end

  test "unconnected source port" do
    assert_error(make_graph(:g,
                            inputs: [i: String, z: Number],
                            outputs: [o: Number],
                            nodes: [a: node_a],
                            connections: edges do
                              this.i -> a.i
                              a.o -> this.o
                            end),
                 "Error: the following source ports are not connected: this.z")
  end

  test "unconnected edge tail" do
    assert_error(make_graph(:g,
                            inputs: [i: String],
                            outputs: [o: Number],
                            nodes: [a: node_a],
                            connections: edges do
                              this.i -> a.i
                              a.o -> this.o
                              z.q -> a.i
                            end),
                 "Error: the following edge tails are not connected: z.q")
  end

  test "unconnected edge head" do
    assert_error(make_graph(:g,
                            inputs: [i: String],
                            outputs: [o: Number],
                            nodes: [a: node_a],
                            connections: edges do
                              this.i -> a.i
                              a.o -> this.o
                              a.o -> z.q
                            end),
                 "Error: the following edge heads are not connected: z.q")
  end

  test "port compatibility" do
    assert_error(make_graph(:g,
                            inputs: [i: String],
                            outputs: [o: String],
                            nodes: [a: node_a],
                            connections: edges do
                              this.i -> a.i
                              a.o -> this.o
                            end),
                 "Error: a.o (Number) cannot flow to this.o (String)")
  end

  test "all_ports" do
    result =
      GraphSpec.Validation.all_ports(
        make_graph(:g,
                   inputs: [i: String],
                   outputs: [o: Number],
                   nodes: [a: node_a],
                   connections: edges do
                     this.i -> a.i
                     a.o -> this.o
                   end))
    {[%GraphSpec.Validation.Port{name: :i, node: nil, type: String},
      %GraphSpec.Validation.Port{name: :o, node: the_node1, type: Number}],
     [%GraphSpec.Validation.Port{name: :o, node: nil, type: Number},
      %GraphSpec.Validation.Port{name: :i, node: the_node2, type: String}]} = result
    assert the_node1 == the_node2
    assert %GraphSpec.NodeInst{name: a} = the_node1
  end

  def node_a do
    make_node(:a, inputs: [i: String], outputs: [o: Number])
  end

  def node_b do
    make_node(:b, inputs: [i: String], outputs: [o: Number])
  end
  
  def make_node(name, opts \\ []) do
    NodeSpec.from_cps1(name, &(&1), opts)
  end

  def make_graph(name, opts \\ []) do
    GraphSpec.new(name, opts)
  end
  
end
