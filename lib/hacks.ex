defmodule Hacks do
  defmacro args ~> body do
    case args do
      {:__block__, _, args} ->
        quote do
          fn unquote_splicing(args) -> unquote(body) end
        end
      _ ->
        quote do
          fn unquote(args) -> unquote(body) end
        end
    end
  end

  defmacro defstruct2(name, fields) do
    kws = Enum.map(fields, fn {name, _, _} -> {name, nil} end)
    quote do
      defmodule unquote(name) do
        defstruct unquote(kws)
      end
    end
  end

  # letrec fib, fn 0 -> 0
  #                1 -> 1
  #                n -> fib.(n-1) + fib.(n-2)
  # end
  
  # fib_gen = fn g, 0 -> 0
  #              g, 1 -> 1
  #              g, n -> g.(g, n-1) + g.(g, n-2)
  # end

  # fib = fn n -> fib_gen.(fib_gen, n) end

  defmacro letrec(id, {:fn, context, [{:->, _, [args, body]}|_] = clauses} = fun) do
    params = generate_temporaries(args, context)
    quote do
      gen = unquote({:fn, context, fix_clauses(id, clauses)})
      unquote(id) = fn unquote_splicing(params) -> gen.(gen, unquote_splicing(params)) end
    end
  end

  def fix_clauses(id, clauses) do
    [{:->, context, _}|_] = clauses
    g = hd(generate_temporaries([:g], context))
    Enum.map clauses, fn {:->, ctx, [args, body]} ->
      {:->, ctx, [[g|args], fix_body(body, id, g)]}
    end
  end

  def fix_body({{:., c1, [{id_name, _, _}]}, c2, args}, {id_name, _, _}, g) do
    {{:., c1, [g]}, c2, [g|args]}
  end

  def fix_body(ls, id, g) when is_list(ls) do
    Enum.map(ls, &fix_body(&1, id, g))
  end

  def fix_body(t, id, g) when is_tuple(t) do
    List.to_tuple(fix_body(Tuple.to_list(t), id, g))
  end

  def fix_body(x, _, _) do
    x
  end
  
  def generate_temporaries(xs, context) do
    Enum.map 1..length(xs), fn n ->
      {String.to_atom("t" <> to_string(n)), context, Elixir}
    end
  end

  def multi_call(fns, value) do
    Enum.each(fns, &(&1.(value)))
  end
  
  defmacro thunk(expr) do
    quote do
      fn -> unquote(expr) end
    end
  end
  

  defmacro defi({name, _, params}, [do: body]) do
    quote do
      unquote({name, [], nil}) = fn unquote_splicing(params) -> unquote(body) end
    end
  end
end
