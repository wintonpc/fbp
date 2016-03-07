import Hacks

defstruct2 AnyType, []
defstruct2 BasicType, [name, parent]
defstruct2 GenericType, [name, parameter, argument, parent]

defmodule Type do
  def define_basic_type(name, opts \\ []) do
    parent = opts[:extends] || Any
    insert_type(name, %BasicType{name: name, parent: get(parent)})
  end

  defmacro define_generic_type({{:., _, [name, :of]}, _, [parameter]}) do
    {:__aliases__, _, [raw_name]} = name
    quote do
      defmodule unquote({:__aliases__, [], [Elixir, raw_name]}) do
        def of(argument) do
          %GenericType{name: unquote(name),
                       parameter: unquote(parameter),
                       argument: Type.get(argument),
                       parent: Type.get(Any)}
        end
      end
    end
  end

  def ensure_table do
    if :ets.info(:types) == :undefined do
      :ets.new(:types, [:set, :named_table])
    end
  end

  def insert_type(name, type) do
    ensure_table
    :ets.insert(:types, {name, type})
  end

  defp look_up_type(name) do
    ensure_table
    case :ets.lookup(:types, name) do
      [{_, type}] ->
        type
      _ ->
        raise "couldn't find type: #{name}"
    end
  end
  
  def is_alias(x) do
    is_atom(x) && String.starts_with?(to_string(x), "Elixir.")
  end

  def get(%GenericType{} = t), do: t
  def get(%BasicType{} = t), do: t
  def get(%AnyType{} = t), do: t
  def get(Any), do: %AnyType{}
  def get(x) do
    unless is_alias(x) do
      raise "Expected alias but got: #{inspect(x)}"
    end
    look_up_type(x)
  end

  def is_assignable_from(binding_type, value_type) do
    do_is_assignable_from(get(binding_type), get(value_type))
  end
  
  defp do_is_assignable_from(%GenericType{name: x, argument: a},
                             %GenericType{name: x, argument: b}) do
    do_is_assignable_from(a, b)
  end
  
  defp do_is_assignable_from(binding_type, value_type) do
    cond do
      binding_type == value_type ->
        true
      value_type == get(Any) ->
        false
      :else ->
        do_is_assignable_from(binding_type, value_type.parent)
    end
  end
end
