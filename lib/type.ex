import Hacks

defstruct2 AnyType, []
defstruct2 BasicType, [name, parent]
defstruct2 StructType, [name, fields, parent]
defstruct2 GenericType, [name, parameter, argument, parent]

defmodule Type do
  # inject code into modules that "use" us
  defmacro __using__(opts \\ []) do
    parent = opts[:parent] || Type
    quote do
      import unquote(__MODULE__), only: :macros
      Module.register_attribute(__MODULE__, :fbp_structs, accumulate: true)
      Module.register_attribute(__MODULE__, :fbp_type_parent, accumulate: false)
      @fbp_type_parent unquote(parent)
      @before_compile unquote(__MODULE__)
    end
  end

  # here's the code to inject
  defmacro __before_compile__(_env) do
    quote do
      # when the "using" module is itself "used", alias the struct types it declares
      # to avoid having to fully qualify them or alias manually
      defmacro __using__(_opts) do
        Enum.map @fbp_structs, fn long ->
          short = Module.concat([List.last(Module.split(long))])
          quote do
            alias unquote(long), as: unquote(short)
          end
        end
      end

      def get_type(x) do
        @fbp_type_parent.get_type(x)
      end
    end
  end

  defmacro deftype_basic(name, opts \\ []) do
    parent = opts[:extends] || Any
    quote do
      def get_type(unquote(name)) do
        %BasicType{name: unquote(name), parent: get_type(unquote(parent))}
      end
    end
  end

  defmacro deftype_generic({{:., _, [name, :of]}, _, [parameter]}) do
    quote do
      defmodule unquote(name) do
        def of(argument) do
          %GenericType{name: Module.concat([List.last(Module.split(unquote(name)))]),
                       parameter: unquote(parameter),
                       argument: unquote(__CALLER__.module).get_type(argument),
                       parent: Type.get_type(Any)}
        end
      end
      @fbp_structs unquote(name)
    end
  end


  defmacro deftype_struct(name, opts \\ []) do
    parent = opts[:extends] || {:__aliases__, [], [:Any]}
    fields = opts[:fields] || []
    parent_alias = reify_alias(parent)
    name_alias = reify_alias(name)
    Module.register_attribute(__CALLER__.module, :fbp_struct_fields, accumulate: true)
    m_parent_fields = Map.get(Map.new(Module.get_attribute(__CALLER__.module, :fbp_struct_fields)), parent_alias, [])
    long_name = Module.concat(__CALLER__.module, name_alias)
    Module.put_attribute(__CALLER__.module, :fbp_struct_fields, {name_alias, fields})
    Module.put_attribute(__CALLER__.module, :fbp_struct_fields, {long_name, fields})
    combined_fields = Enum.uniq(m_parent_fields ++ fields)
    quote do
      unquote_splicing(
        # creating the struct can change the way type names are passed to get_type
        Enum.map([name, long_name], fn type_name ->
          quote do
            def get_type(unquote(type_name)) do
              parent = get_type(unquote(parent))
              parent_fields =
                case parent do
                  %AnyType{} ->
                    []
                  %StructType{fields: fields} ->
                    fields
                end
              
              %StructType{name: unquote(name),
                          parent: parent,
                          fields: unquote(combined_fields)}
            end
          end
        end))
      
      defmodule unquote(name) do
        defstruct unquote(Enum.map(combined_fields, &{&1, nil}))
      end
      @fbp_structs unquote(name)
    end
  end

  defp reify_alias(nil), do: nil
  defp reify_alias({:__aliases__, _, [raw_name]}) do
    Module.concat([to_string(raw_name)])
  end

  def get_type(Any), do: %AnyType{}
  def get_type(%AnyType{} = x), do: x
  def get_type(%BasicType{} = x), do: x
  def get_type(%StructType{} = x), do: x
  def get_type(%GenericType{} = x), do: x

  def get_type(x) do
    raise "Couldn't find type: #{inspect(x)}"
  end
  
  def is_alias(x) do
    is_atom(x) && String.starts_with?(to_string(x), "Elixir.")
  end

  def is_assignable_from(binding_type, value_type) do
    do_is_assignable_from(binding_type, value_type)
  end
  
  defp do_is_assignable_from(%GenericType{name: x, argument: a},
                             %GenericType{name: x, argument: b}) do
    do_is_assignable_from(a, b)
  end
  
  defp do_is_assignable_from(binding_type, value_type) do
    cond do
      binding_type == value_type ->
        true
      value_type == get_type(Any) ->
        false
      :else ->
        do_is_assignable_from(binding_type, value_type.parent)
    end
  end
end
