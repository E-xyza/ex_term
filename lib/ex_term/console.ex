defmodule ExTerm.Console do
  @moduledoc false

  # ExTerm.Console is a datastructure/component which describes the "console" region of
  # the ExTerm interface.  This is a (currently 80c x 40r) matrix of characters
  # which contain their own individual styling elements.  The console also
  # retains a cursor position, which can move around.

  # In the future, this will likely support arbitrary row/column counts.

  use Phoenix.Component

  alias ExTerm.Console.Cursor
  alias ExTerm.Console.Rows

  # NOTE that the dimensions field is not descriptive of the datastructure in
  # the rows term, in the future if dimensions are changeable, they may be out
  # of sync, and the rows term should be considered authoritative.
  defstruct cursor: Cursor.new(), rows: Rows.new(), dimensions: {40, 80}
  @type t :: %__MODULE__{cursor: Cursor.t(), rows: Rows.t()}

  def new, do: %__MODULE__{}

  def render(%{console: assigns}) do
    ~H"""
    <div id="exterm-console">
      <Rows.render rows={@rows}/>
    </div>
    """
  end
end
