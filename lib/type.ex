import Hacks

defstruct2 AnyType, [name, predicate]
defstruct2 BasicType, [name, predicate, parent]
#defstruct2 StructType, [name, predicate, fields, parent]
defstruct2 GenericTemplate, [name, predicate, parameter, parent]
defstruct2 GenericType, [template, argument]

defmodule Type do

  defmodule Store do
    def new(opts \\ []) do
      name = opts[:name]
      {:ok, agent} = Agent.start(fn -> empty end, name: name)
      agent
    end

    def singleton do
      unless Process.whereis(singleton_name) do
        new(name: singleton_name)
      end
      singleton_name
    end

    defp empty do
      %{Any => %AnyType{name: Any, predicate: fn _ -> true end}}
    end

    def clear(ts) do
      Agent.update(ts, fn _ -> empty end)
    end

    defp singleton_name, do: :singleton_type_store

  end
  
  def define_basic(name, opts \\ []) do
    ts = opts[:store] || Type.Store.singleton
    parent_type = get_type(opts[:extends] || Any)
    predicate = opts[:predicate] || fn _ -> false end
    Agent.update(ts, &Map.put(&1, name, %BasicType{name: name, parent: parent_type, predicate: predicate}))
  end

  defmacro define_struct({:%, _, [name, {:%{}, _, []}]} = pattern) do
    quote do
      Type.define_basic unquote(name), predicate: fn
        (unquote(pattern)) -> true
        (_) -> false
      end
    end
  end

  def define_generic(name, parameter, opts \\ []) do
    ts = opts[:store] || Type.Store.singleton
    predicate = opts[:predicate] || fn _ -> false end
    any_type = get_type(Any, store: ts)
    Agent.update(ts, &Map.put(&1, name, %GenericTemplate{name: name, predicate: predicate, parameter: parameter, parent: any_type}))
  end

  def instantiate_generic(template_name, argument, opts \\ []) do
    ts = opts[:store] || Type.Store.singleton
    template = get_type(template_name, store: ts)
    %GenericType{template: template, argument: argument}
  end
  
  def get_type(type_name, opts \\ []) do
    if is_map(type_name) do
      type_name
    else
      ts = opts[:store] || Type.Store.singleton
      t = Agent.get(ts, &(&1[type_name]))
      t || raise "Couldn't find type: #{inspect(type_name)}"
    end
  end

  def is_type(%AnyType{}, _, _), do: true
  def is_type(type, value, opts \\ []) do
    if is_atom(type) do
      is_type(get_type(type), value, opts)
    else
      ts = opts[:store] || Type.Store.singleton
      ts = ts || Type.Store.singleton
      parent(type).predicate.(value) && type.predicate.(value)
    end
  end

  def is_assignable_from(binding_type, value_type, opts \\ []) do
    ts = opts[:store] || Type.Store.singleton
    do_is_assignable_from(binding_type, value_type, store: ts)
  end
  
  defp do_is_assignable_from(%GenericType{template: x, argument: a},
                             %GenericType{template: x, argument: b}, opts) do
    do_is_assignable_from(a, b, opts)
  end
  
  defp do_is_assignable_from(binding_type, value_type, opts) do
    ts = opts[:store]
    binding_type = get_type(binding_type, store: ts)
    value_type = get_type(value_type, store: ts)
    ts = opts[:store]
    cond do
      binding_type == value_type ->
        true
      value_type == get_type(Any, store: ts) ->
        false
      :else ->
        do_is_assignable_from(binding_type, parent(value_type), opts)
    end
  end

  defp parent(%GenericType{template: t}), do: t.parent
  defp parent(t), do: t.parent

end
