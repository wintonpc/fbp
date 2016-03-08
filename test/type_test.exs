defmodule Type.Test do
  use ExUnit.Case
  import Type, except: [get_type: 1]

  defmodule Types do
    use Type
    deftype_basic String
    deftype_basic CompoundName, extends: String
    deftype_generic Array.of(T)
    deftype_generic Foo.of(T)
    deftype_struct MyRange, fields: [:a, :b]
    deftype_struct RangeWithInc, extends: MyRange, fields: [:inc]
  end

  test "deftype" do
    import Types, only: [get_type: 1]
    assert get_type(String) ==
      %BasicType{name: String, parent: get_type(Any)}
    assert get_type(CompoundName) ==
      %BasicType{name: CompoundName, parent: get_type(String)}
    assert Types.Array.of(String) ==
      %GenericType{name: Array, parameter: T, argument: get_type(String), parent: get_type(Any)}
    assert get_type(MyRange) ==
      %StructType{name: MyRange, fields: [:a, :b], parent: get_type(Any)}
    assert get_type(RangeWithInc) ==
      %StructType{name: RangeWithInc, fields: [:a, :b, :inc], parent: get_type(MyRange)}    
  end

  defmodule TestStructCreation do
    use Types
    
    def go do
      %RangeWithInc{a: 1, b: 2, inc: 0.1} # compilation will fail here unless the struct type Types.RangeWithInc
      # exists and is aliased into this module
    end
  end

  defmodule TestGenericCreation do
    use Types

    def go do
      Array.of(String)
    end
  end

  test "generic creation" do
    TestGenericCreation.go
  end

  test "is_alias" do
    assert is_alias(:foo) == false
    assert is_alias(Foo) == true
  end

  test "get_type" do
    import Types, only: [get_type: 1]
    assert get_type(String) == %BasicType{name: String, parent: get_type(Any)}
  end
  
  test "get_type is idempotent" do
    import Types, only: [get_type: 1]
    type = get_type(String)
    assert type  == %BasicType{name: String, parent: get_type(Any)}
    assert get_type(type) == type
  end
  
  test "is_assignable_from" do
    assert assignable?(Any, String) == true
    assert assignable?(String, Any) == false
    assert assignable?(Any, Any) == true
    assert assignable?(String, String) == true
    assert assignable?(Any, CompoundName) == true
    assert assignable?(String, CompoundName) == true
    assert assignable?(CompoundName, Any) == false
    assert assignable?(CompoundName, String) == false
    assert assignable?(Any, Types.Array.of(String)) == true
    assert assignable?(Types.Array.of(String), Any) == false
  end

  def assignable?(binding_type_name, value_type_name) do
    Type.is_assignable_from(Types.get_type(binding_type_name),
                            Types.get_type(value_type_name))
  end

  test "generics are covariant" do
    alias Types.Array, as: Array
    assert assignable?(Array.of(String), Array.of(CompoundName)) == true
    assert assignable?(Array.of(CompoundName), Array.of(String)) == false
    assert assignable?(Array.of(String), Types.Foo.of(String)) == false
  end
end
