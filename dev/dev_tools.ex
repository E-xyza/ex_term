defmodule DevTools do
  def insert do
    spawn fn ->
      Process.sleep(1000)
      IO.puts(String.duplicate("x", 81))
    end
  end

  def clear do
    IO.puts(IO.ANSI.clear())
  end

  def line_clear do
    IO.puts("not here" <> IO.ANSI.clear_line() <> "is here")
  end
end
