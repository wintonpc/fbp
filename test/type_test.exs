defmodule Type.Test do
  use ExUnit.Case
  import Type
  
  setup do
    Type.define_basic_type String
    Type.define_basic_type CompoundName, extends: String
    Type.define_generic_type Array.of(T)
    Type.define_generic_type Foo.of(T)
    :ok
  end
  
  test "deftype" do
    assert Type.get(String) ==
      %BasicType{name: String, parent: Type.get(Any)}
    assert Type.get(CompoundName) ==
      %BasicType{name: CompoundName, parent: Type.get(String)}
    assert Array.of(String) ==
      %GenericType{name: Array, parameter: T, argument: Type.get(String), parent: Type.get(Any)}
  end

  test "is_alias" do
    assert is_alias(:foo) == false
    assert is_alias(Foo) == true
  end

  test "to_type" do
    assert Type.get(String) == %BasicType{name: String, parent: Type.get(Any)}
    assert Type.get(Array.of(String)) == %GenericType{name: Array,
                                                      parameter: T,
                                                      argument: Type.get(String),
                                                      parent: Type.get(Any)}
  end

  test "is_assignable_from" do
    assert Type.is_assignable_from(Any, String) == true
    assert Type.is_assignable_from(String, Any) == false
    assert Type.is_assignable_from(Any, Any) == true
    assert Type.is_assignable_from(String, String) == true
    assert Type.is_assignable_from(Any, CompoundName) == true
    assert Type.is_assignable_from(String, CompoundName) == true
    assert Type.is_assignable_from(CompoundName, Any) == false
    assert Type.is_assignable_from(CompoundName, String) == false
    assert Type.is_assignable_from(Any, Array.of(String)) == true
    assert Type.is_assignable_from(Array.of(String), Any) == false
  end

  test "generics are covariant" do
    assert Type.is_assignable_from(Array.of(String), Array.of(CompoundName)) == true
    assert Type.is_assignable_from(Array.of(CompoundName), Array.of(String)) == false
    assert Type.is_assignable_from(Array.of(String), Foo.of(String)) == false
  end
end
