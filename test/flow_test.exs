defmodule FlowTest do
  use ExUnit.Case
  import GraphSpec
  
  defnode adder(a: Number, b: Number, outputs: [sum: Number]) do
    IO.puts "in adder, a = #{a}, b = #{b}"
    sum.emit.(a + b)
  end
  
  test "flow" do
    [values: [sum: s]] = Flow.run(adder, args: [a: 1, b: 2])
    assert s == 3
  end
  
end
