defmodule DevTools do
  def insert do
    spawn fn ->
      Process.sleep(1000)
      IO.puts(String.duplicate("x", 81))
    end
  end
end
