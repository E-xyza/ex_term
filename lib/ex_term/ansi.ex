defmodule ExTerm.ANSI do
  @moduledoc false

  # this module provides the parse/2 function, which performs iterative parsing
  # of a string starting at the point where an ANSI control character starts.
  # It punts to Style and Cursor modules, which can pick out important bits from
  # the control character and respond as to what should happen by the console.

  alias ExTerm.Style
  alias ExTerm.Console
  alias ExTerm.Console.Cursor

  @type ansi_state :: {Style.t(), cursor :: Console.location()}

  @spec parse(String.t(), ansi_state) :: {String.t(), ansi_state}
  def parse(string = "\e" <> _, {style, cursor}) do
    with :not_style <- Style.from_ansi(style, string),
         :not_cursor <- Cursor.from_ansi(cursor, string) do
      raise "unexpected ANSI control code found in string #{inspect(string)}"
    else
      {new_style = %Style{}, rest} ->
        parse(rest, {new_style, cursor})

      {new_cursor = {_, _}, rest} ->
        parse(rest, {style, new_cursor})
    end
  end

  def parse(rest, ansi_state), do: {rest, ansi_state}
end
