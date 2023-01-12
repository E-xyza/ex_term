defmodule ExTerm.Console.Cursor do
  def from_ansi(_, _) do
    :not_cursor
  end
end
