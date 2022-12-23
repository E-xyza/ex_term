defmodule ExTerm.Console do
  @moduledoc false

  # ExTerm.Console is a datastructure/component which describes the "console" region of
  # the ExTerm interface.  This is a (currently 40r x 80c) matrix of characters
  # which contain their own individual styling elements.  The console also
  # retains a cursor position, which can move around.

  # In the future, this will likely support arbitrary row/column counts.

  use Phoenix.Component

  alias ExTerm.Buffer
  alias ExTerm.Console.Row
  alias ExTerm.Console.Data

  @default_row_count 40
  @default_column_count 80

  @type rows :: %{optional(pos_integer) => Row.t()}
  @type t :: term

  def render(assigns) do
    ~H"""
    <div id="exterm-console">
      <%= for row <- @rows do %>
      <Row.render row={row} cursor={@cursor}/>
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

  def get_dimension(data, request \\ [:columns, :rows]) do
    case Data.metadata(data, request) do
      [column, row] -> {row, column}
      result -> result
    end
  end

  def put_chars(console, chars) do
    result = Data.transactionalize(console, fn ->
      put_char_internal(console, chars)
    end)
    result
  end

  def start_prompt(from, console, prompt) do
    raise "a"
    # {console, buffer_lines} = put_char_internal({console, []}, prompt)
    # {%{console | prompt: from}, buffer_lines}
  end

  def push_key(console, key) do
    raise "aaaa"
    # put_char_internal({%{console | prompt_buf: [console.prompt_buf | key]}, []}, key)
  end

  def hit_enter(console) do
    raise "aaa"
    # ExTerm.reply(console.prompt, IO.iodata_to_binary(console.prompt_buf))
    # cursor_crlf(console)
  end

  #############################################################################
  ## COMMON FUNCTIONS

  defp put_char_internal(result, ""), do: result

  @control 27

  defp put_char_internal(_console, _chars = <<@control, _::binary>>) do
    raise "aaa"
    # {style, rest} = Style.from_ansi(console.style, chars)
    # new_console = %{console | style: style}
    # put_char_internal({new_console, buffer_so_far}, rest)
  end

  defp put_char_internal(console, chars) do
    {head, rest} = String.next_grapheme(chars)

    console
    |> put_char_in_place(head)
    |> put_char_internal(rest)
  end

  defp put_char_in_place(console, "\n"), do: cursor_crlf(console)

  defp put_char_in_place(console, char) do
    Data.put_char(console, char)
  end

  defdelegate cursor_advance(console), to: Data
  defdelegate cursor_crlf(console), to: Data
end
