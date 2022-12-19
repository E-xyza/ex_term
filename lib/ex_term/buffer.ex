defmodule ExTerm.Buffer do
  @moduledoc false

  # ExTerm.Buffer is a datastructure/component which describes the "buffer" region of the
  # ExTerm interface.  This is a list of lines which are stored that are
  # accessible by scrolling back in the terminal.  This datastructure is backed
  # by an ets table, and under normal circumstances, it will not really need to
  # be accessed, because the liveview will use temporary assigns to push
  # content into the buffer.

  use Phoenix.Component

  alias ExTerm.Buffer.Line

  # for now, we'll have a more detailed description later.
  @type line :: term

  defstruct [count: 0]

  def new, do: %__MODULE__{}

  def render(assigns) do
    ~H"""
    <% total_lines = length(@lines) %>
    <div id="exterm-buffer" phx-update="append"><%= for {line, index} <- Enum.with_index(@lines) do %>
    <Line.render line={line} index={@count - total_lines + index}/>
    <% end %></div>
    """
  end

  defdelegate line_from_row(row), to: Line, as: :from_row
end
