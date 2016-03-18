defmodule TestArray do
  def of(item_type) do
    Type.instantiate_generic(TestArray, item_type)
  end
end

defmodule Foo do
  def of(item_type) do
    Type.instantiate_generic(Foo, item_type)
  end
end

import Hacks
defstruct2 MyRange, [a, b]

defmodule Type.Test do
  use ExUnit.Case
  import Hacks
  import Type, only: :macros

  setup do
    Type.Store.clear(Type.Store.singleton)
    :ok
  end
  
  test "normal store" do
    ts = Type.Store.new
    r = Type.get_type(Any, store: ts)
    assert %AnyType{name: Any} = r
  end
  
  test "singleton store" do
    r = Type.get_type(Any)
    assert %AnyType{name: Any} = r
  end

  test "any type" do
    assert Type.is_type(Any, "foo") == true
    assert Type.is_type(Any, 42) == true
    assert Type.is_type(Any, false) == true
  end

  test "default predicate is always false" do
    Type.define_basic String
    assert Type.is_type(String, "foo") == false
    assert Type.is_type(String, 42) == false
  end

  test "basic type" do
    Type.define_basic String, predicate: &Kernel.is_bitstring/1
    assert Type.is_type(String, "foo") == true
    assert Type.is_type(String, :foo) == false
    assert Type.is_type(String, 42) == false
  end

  test "basic inheritance" do
    Type.define_basic String, predicate: &Kernel.is_bitstring/1
    Type.define_basic ShortString, extends: String, predicate: &(String.length(&1) <= 3)
    assert Type.is_type(String, "foo") == true
    assert Type.is_type(ShortString, "foo") == true
    assert Type.is_type(ShortString, "food") == false
    assert Type.is_type(ShortString, :non_string) == false
  end

  test "structs" do
    Type.define_struct %MyRange{}
    assert Type.is_type(MyRange, %MyRange{}) == true
    assert Type.is_type(MyRange, %MyRange{a: 1, b: 2}) == true
    assert Type.is_type(MyRange, %{a: 1, b: 2}) == false
    assert Type.is_type(MyRange, "range!") == false
  end

  test "get_type is idempotent" do
    any = Type.get_type(Any)
    assert %AnyType{} = any
    assert Type.get_type(any) == any
  end

  test "is_type works with both types and type names" do
    Type.define_basic String, predicate: &Kernel.is_bitstring/1
    assert Type.is_type(String, "foo")
    assert Type.is_type(Type.get_type(String), "foo")
  end

  test "is_assignable_from" do
    Type.define_basic String, predicate: &Kernel.is_bitstring/1
    Type.define_basic CompoundName, extends: String
    Type.define_generic TestArray, T, predicate: &Kernel.is_list/1
    
    assert Type.is_assignable_from(Any, String) == true
    assert Type.is_assignable_from(String, Any) == false
    assert Type.is_assignable_from(Any, Any) == true
    assert Type.is_assignable_from(String, String) == true
    assert Type.is_assignable_from(Any, CompoundName) == true
    assert Type.is_assignable_from(String, CompoundName) == true
    assert Type.is_assignable_from(CompoundName, Any) == false
    assert Type.is_assignable_from(CompoundName, String) == false
    assert Type.is_assignable_from(Any, TestArray.of(String)) == true
    assert Type.is_assignable_from(TestArray.of(String), Any) == false
  end

  test "generics are covariant" do
    Type.define_basic String
    Type.define_basic CompoundName, extends: String
    Type.define_generic TestArray, T
    Type.define_generic Foo, T

    assert Type.is_assignable_from(TestArray.of(String), TestArray.of(CompoundName)) == true
    assert Type.is_assignable_from(TestArray.of(CompoundName), TestArray.of(String)) == false
    assert Type.is_assignable_from(TestArray.of(String), Foo.of(String)) == false
  end
  
  def assert_match(actual_struct, expected_struct) do
    actual_map = Map.from_struct(actual_struct)
    expected_map = Map.from_struct(expected_struct)
    Enum.all?(expected_map, {ek, ev} ~> (actual_map[ek] == ev)) || raise "did not match:\n  #{inspect(actual_struct)}\n  #{inspect(expected_struct)}"
  end

end
