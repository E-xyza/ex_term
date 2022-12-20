defmodule ExTerm.Console do
  @moduledoc false

  # ExTerm.Console is a datastructure/component which describes the "console" region of
  # the ExTerm interface.  This is a (currently 80c x 40r) matrix of characters
  # which contain their own individual styling elements.  The console also
  # retains a cursor position, which can move around.

  # In the future, this will likely support arbitrary row/column counts.

  use Phoenix.Component

  alias ExTerm.Buffer
  alias ExTerm.Style
  alias ExTerm.Console.Cell
  alias ExTerm.Console.Cursor
  alias ExTerm.Console.Row

  @default_row_count 40
  @default_column_count 80

  @default_rows for row_index <- 1..@default_row_count,
                    into: %{},
                    do: {row_index, Row.new(@default_column_count)}

  # NOTE that the dimensions field is not descriptive of the datastructure in
  # the rows term, in the future if dimensions are changeable, they may be out
  # of sync, and the rows term should be considered authoritative.
  defstruct cursor: Cursor.new(),
            rows: @default_rows,
            dimensions: {@default_row_count, @default_column_count},
            style: Style.new(),
            prompt: nil,
            prompt_buf: []

  @type rows :: %{optional(pos_integer) => Row.t()}
  @type t :: %__MODULE__{cursor: Cursor.t(), rows: rows}

  def new, do: %__MODULE__{}

  def render(%{console: assigns}) do
    assigns =
      Map.merge(assigns, %{
        total_rows: map_size(assigns.rows)
      })

    ~H"""
    <div id="exterm-console">
      <%= for row_index <- 1..@total_rows do %>
        <Row.render row_index={row_index} row={@rows[row_index]} cursor={@cursor} prompt={!is_nil(@prompt)}/>
      <% end %>
    </div>
    """
  end

  #############################################################################
  ## API

  @type dimension_request :: :rows | :column
  @spec get_dimension(t, dimension_request) :: non_neg_integer

  @type console_response :: {t, [Buffer.line()]}
  @spec put_chars(t, String.t()) :: console_response
  @spec start_prompt(GenServer.from(), t, String.t()) :: console_response
  @spec push_key(t, String.t()) :: console_response
  @spec hit_enter(t) :: console_response

  #############################################################################
  ## API IMPLEMENTATIONS

  def get_dimension(%{dimensions: {rows, columns}}, request) do
    case request do
      :rows -> rows
      :columns -> columns
    end
  end

  def put_chars(console, chars), do: put_char_internal({console, []}, chars)

  def start_prompt(from, console, prompt) do
    {console, buffer_lines} = put_char_internal({console, []}, prompt)
    {%{console | prompt: from}, buffer_lines}
  end

  def push_key(console, key) do
    put_char_internal({%{console | prompt_buf: [console.prompt_buf | key]}, []}, key)
  end

  def hit_enter(console) do
    ExTerm.reply(console.prompt, IO.iodata_to_binary(console.prompt_buf))

    %{console | prompt_buf: [], prompt: nil}
    |> cursor_crlf
    |> realign_cursor([])
  end

  #############################################################################
  ## GUARDS

  defguard is_overflowing(console) when console.cursor.row > elem(console.dimensions, 0)

  #############################################################################
  ## COMMON FUNCTIONS

  defp put_char_internal(result, ""), do: result

  @control 27

  defp put_char_internal({console, buffer_so_far}, chars = <<@control, _ :: binary>>) do
    {style, rest} = Style.from_ansi(chars)
    new_console = %{console | style: style}
    put_char_internal({new_console, buffer_so_far}, rest)
  end

  defp put_char_internal({console, buffer_so_far}, chars) do
    {head, rest} = String.next_grapheme(chars)

    console
    |> put_char_in_place(head)
    |> realign_cursor(buffer_so_far)
    |> put_char_internal(rest)
  end

  defp put_char_in_place(console, "\n"), do: cursor_crlf(console)

  defp put_char_in_place(console = %{cursor: cursor}, char) do
    new_cell = %Cell{style: console.style, char: char}
    new_rows = put_in(console.rows, [cursor.row, cursor.column], new_cell)

    console
    |> Map.put(:rows, new_rows)
    |> cursor_advance
  end

  defp cursor_advance(console = %{cursor: cursor}) do
    %{console | cursor: %{cursor | column: cursor.column + 1}}
  end

  defp cursor_crlf(console = %{cursor: cursor}) do
    %{console | cursor: %{cursor | column: 1, row: cursor.row + 1}}
  end

  defp realign_cursor(
         console = %{cursor: %{column: column}, dimensions: {_, column_limit}},
         buffer_so_far
       )
       when column > column_limit do
    realign_cursor(cursor_crlf(console), buffer_so_far)
  end

  defp realign_cursor(console, buffer_so_far) when is_overflowing(console) do
    # thake the first row and convert it to a buffer line.
    new_buffer_row = Buffer.line_from_row(console.rows[1])
    realign_cursor(shift_rows(console), [new_buffer_row | buffer_so_far])
  end

  defp realign_cursor(console, buffer_so_far) do
    {console, buffer_so_far}
  end

  defp shift_rows(console = %{rows: rows, dimensions: {row_count, column_count}, cursor: cursor}) do
    new_rows = rows
    |> Map.delete(1)
    |> Map.new(fn {row_index, row} -> {row_index - 1, row} end)
    |> Map.put(row_count, Row.new(column_count))

    %{console | rows: new_rows, cursor: %{cursor | row: cursor.row - 1}}
  end

  def show_rows(rows) do
    rows
    |> Enum.sort()
    |> Enum.map(fn {row_index, row} ->
      content = row
      |> Enum.sort
      |> Enum.map(fn
        {_, %{char: nil}} -> "."
        {_, cell} -> cell.char
      end)
      row_index_str = String.pad_leading("#{row_index}", 2)
      IO.puts(["#{row_index_str}: " | content])
    end)

    rows
  end

  defimpl Inspect do
    def inspect(_console, _opts) do
      "#ExTerm.Console<>"
    end
  end
end
