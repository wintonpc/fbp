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

  
  # # inject code into modules that "use" us
  # defmacro __using__(opts \\ []) do
  #   parent = opts[:parent] || Type
  #   quote do
  #     import unquote(__MODULE__), only: :macros
  #     Module.register_attribute(__MODULE__, :fbp_structs, accumulate: true)
  #     Module.register_attribute(__MODULE__, :fbp_type_parent, accumulate: false)
  #     @fbp_type_parent unquote(parent)
  #     @before_compile unquote(__MODULE__)
  #   end
  # end

  # # here's the code to inject
  # defmacro __before_compile__(_env) do
  #   quote do
  #     # when the "using" module is itself "used", alias the struct types it declares
  #     # to avoid having to fully qualify them or alias manually
  #     defmacro __using__(_opts) do
  #       Enum.map @fbp_structs, fn long ->
  #         short = Module.concat([List.last(Module.split(long))])
  #         quote do
  #           alias unquote(long), as: unquote(short)
  #         end
  #       end
  #     end

  #     def get_type(x) do
  #       @fbp_type_parent.get_type(x)
  #     end
  #   end
  # end

  # defmacro deftype_basic(name, opts \\ []) do
  #   parent = opts[:extends] || Any
  #   predicate = opts[:predicate]
  #   quote do
  #     def get_type(unquote(name)) do
  #       %BasicType{name: unquote(name), predicate: unquote(predicate), parent: get_type(unquote(parent))}
  #     end
  #   end
  # end

  # defmacro deftype_generic({{:., _, [name, :of]}, _, [parameter]}) do
  #   quote do
  #     defmodule unquote(name) do
  #       def of(argument) do
  #         %GenericType{name: Module.concat([List.last(Module.split(unquote(name)))]),
  #                      parameter: unquote(parameter),
  #                      argument: unquote(__CALLER__.module).get_type(argument),
  #                      parent: Type.get_type(Any)}
  #       end
  #     end
  #     @fbp_structs unquote(name)
  #   end
  # end


  # defmacro deftype_struct(name, opts \\ []) do
  #   parent = opts[:extends] || {:__aliases__, [], [:Any]}
  #   fields = opts[:fields] || []
  #   parent_alias = reify_alias(parent)
  #   name_alias = reify_alias(name)
  #   Module.register_attribute(__CALLER__.module, :fbp_struct_fields, accumulate: true)
  #   m_parent_fields = Map.get(Map.new(Module.get_attribute(__CALLER__.module, :fbp_struct_fields)), parent_alias, [])
  #   long_name = Module.concat(__CALLER__.module, name_alias)
  #   Module.put_attribute(__CALLER__.module, :fbp_struct_fields, {name_alias, fields})
  #   Module.put_attribute(__CALLER__.module, :fbp_struct_fields, {long_name, fields})
  #   combined_fields = Enum.uniq(m_parent_fields ++ fields)
  #   quote do
  #     defmodule unquote(name) do
  #       defstruct unquote(Enum.map(combined_fields, &{&1, nil}))
  #     end

  #     unquote_splicing(
  #       # creating the struct can change the way type names are passed to get_type
  #       Enum.map([name, long_name], fn type_name ->
  #         quote do
  #           def get_type(unquote(type_name)) do
  #             parent = get_type(unquote(parent))
  #             parent_fields =
  #               case parent do
  #                 %AnyType{} ->
  #                   []
  #                 %StructType{fields: fields} ->
  #                   fields
  #               end

  #             predicate = fn
  #               (x) when is_map(x) -> x.__struct__ == unquote(name)
  #               (x) -> Type.is_type(Types.get_type(unquote(parent)), x)
  #             end
  
  #             %StructType{name: unquote(name),
  #                         predicate: predicate,
  #                         parent: parent,
  #                         fields: unquote(combined_fields)}
  #           end
  #         end
  #       end))
  
  #     @fbp_structs unquote(name)
  #   end
  # end

  # defp reify_alias(nil), do: nil
  # defp reify_alias({:__aliases__, _, [raw_name]}) do
  #   Module.concat([to_string(raw_name)])
  # end

  # def is_alias(x) do
  #   is_atom(x) && String.starts_with?(to_string(x), "Elixir.")
  # end


end
