defmodule SyntaxUtils do
  
  def exprs({:__block__, _, x}), do: x
  def exprs(x), do: [x]

  def expr([x]), do: x
  def expr(xs) when is_list(xs), do: {:__block__, [], xs}
  
  def split_last_expr(body) do
    case body do
      {:__block__, _, exprs} -> split_last_expr(exprs, [])
      _ -> {[], body}
    end
  end

  defp split_last_expr([expr], acc), do: {Enum.reverse(acc), expr}
  defp split_last_expr([expr|rest], acc), do: split_last_expr(rest, [expr|acc])

  def puts_expand_once(expr) do
    IO.puts(Macro.to_string(Macro.expand_once(expr, __ENV__)))
  end
end
