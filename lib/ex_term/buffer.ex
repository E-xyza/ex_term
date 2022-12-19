defmodule ExTerm.Buffer do
  @moduledoc false

  # ExTerm.Buffer is a datastructure/component which describes the "buffer" region of the
  # ExTerm interface.  This is a list of lines which are stored that are
  # accessible by scrolling back in the terminal.  This datastructure is backed
  # by an ets table, and under normal circumstances, it will not really need to
  # be accessed, because the liveview will use temporary assigns to push
  # content into the buffer.

  use Phoenix.Component

  # for now, we'll have a more detailed description later.
  @type line :: term

  def new, do: nil

  def render(assigns) do
    ~H"""
    <div id="exterm-buffer"></div>
    """
  end
end
