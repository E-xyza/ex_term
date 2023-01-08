defmodule ExTerm.Console.StringTracker do
  alias ExTerm.Console
  @moduledoc false
  @enforce_keys [:style, :cursor, :console, :last_updated]
  defstruct @enforce_keys ++ [updates: []]

  @type t :: %__MODULE__{
    style: Style.t,
    cursor: Console.location,
    console: Console.t,
    last_updated: Console.location
  }
  def new(console) do
    [cursor: cursor, style: style] = Console.get_metadata(console, [:cursor, :style])
    %__MODULE__{cursor: cursor, style: style, console: console, last_updated: cursor}
  end
end
