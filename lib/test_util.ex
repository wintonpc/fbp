defmodule TestUtil do
  defmacro assert_error(exp, msg) do
    quote do
      case catch_error(unquote(exp)) do
        %RuntimeError{message: m} ->
          assert m == unquote(msg)
        x ->
          flunk "Unexpected return value: #{inspect(x)}"
      end
    end
  end
end
