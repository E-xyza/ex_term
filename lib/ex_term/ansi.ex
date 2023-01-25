defmodule ExTerm.ANSI do
  @moduledoc false

  # this module provides the parse/2 function, which performs iterative parsing
  # of a string starting at the point where an ANSI control character starts.
  # It punts to Style and Cursor modules, which can pick out important bits from
  # the control character and respond as to what should happen by the console.
  # state is tracked using the module's struct.

  alias ExTerm.Style
  alias ExTerm.Console
  alias ExTerm.Console.Cursor

  @enforce_keys [:console, :style]
  defstruct @enforce_keys

  @opaque state :: %__MODULE__{
    console: Console.t(),
    style: Style.t
  }

  @spec new(Console.t, Style.t) :: state
  def new(console, style) do
    # note we can't trust the style in the console, it might be in the process of being
    # changed.
    %__MODULE__{
      console: console,
      style: style,
    }
  end

  @spec parse(state, String.t(), Console.location) :: {:style, state, String.t()}
  def parse(state, string = "\e" <> _, cursor, changes) do
    with :not_style <- Style.from_ansi(state.style, string),
         :not_cursor <- Cursor.from_ansi(string, state.console, cursor, changes) do
      raise "unexpected ANSI control code found in string #{inspect(string)}"
    else
      {new_style = %Style{}, rest} ->
        {:style, %{state | style: new_style}, rest}
      update = {:update, _new_cursor, _updates, _rest} ->
        update
    end
  end

  def parse(state, rest, _), do: {state, rest}

  @spec style(state) :: Style.t
  def style(state), do: state.style
end
