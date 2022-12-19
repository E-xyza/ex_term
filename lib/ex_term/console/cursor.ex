defmodule ExTerm.Console.Cursor do
  @moduledoc false
  defstruct row: 0, column: 0

  @type t :: %__MODULE__{row: non_neg_integer, column: non_neg_integer}

  def new, do: %__MODULE__{}
  def at?(%{row: row, column: column}, row, column), do: true
  def at?(_, _, _), do: false
end
