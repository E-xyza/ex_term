defmodule ExTerm.Console.StringTracker do
  @moduledoc false

  alias ExTerm.Console
  @enforce_keys [:style, :cursor, :console, :last_updated, :last_row]
  defstruct @enforce_keys ++ [updates: []]

  @type t :: %__MODULE__{
          style: Style.t(),
          cursor: Console.location(),
          console: Console.t(),
          last_updated: Console.location()
        }
  def new(console) do
    [cursor: cursor, style: style] = Console.get_metadata(console, [:cursor, :style])
    {last_row, _} = Console.last_cell(console)
    %__MODULE__{cursor: cursor, style: style, console: console, last_updated: cursor, last_row: last_row}
  end
end
