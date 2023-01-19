defmodule ExTerm.IexBackend.Prompt do
  @moduledoc false

  alias ExTerm.Console
  alias ExTerm.Console.Helpers

  require Helpers

  @enforce_keys [:location, :reply, :console, :precursor]

  defstruct @enforce_keys ++ [postcursor: []]

  @type t :: %__MODULE__{
          location: ExTerm.location(),
          reply: GenServer.location(),
          console: Console.t(),
          precursor: [String.t()],
          postcursor: [String.t()]
        }

  def new(reply, location, precursor, console) do
    paint(%__MODULE__{reply: reply, location: location, precursor: precursor, console: console})
  end

  def push(prompt, key) do
    paint(%{prompt | precursor: [key | prompt.precursor]})
  end

  def backspace(prompt = %{precursor: []}), do: prompt

  def backspace(prompt) do
    paint(%{prompt | precursor: tl(prompt.precursor), postcursor: prompt.postcursor}, " ")
  end

  def delete(prompt = %{postcursor: []}), do: prompt

  def delete(prompt) do
    paint(%{prompt | postcursor: tl(prompt.precursor)}, " ")
  end

  def left(prompt = %{precursor: []}), do: prompt

  def left(prompt = %{precursor: precursor}) do
    paint(%{prompt | precursor: tl(precursor), postcursor: [hd(precursor) | prompt.postcursor]})
  end

  def right(prompt = %{postcursor: []}), do: prompt

  def right(prompt = %{postcursor: postcursor}) do
    paint(%{prompt | postcursor: tl(postcursor), precursor: [hd(postcursor) | prompt.precursor]})
  end

  def submit(prompt = %{console: console}) do
    full_content =
      prompt.precursor
      |> Enum.reverse([prompt.postcursor, "\n"])
      |> IO.iodata_to_binary()

    Helpers.transaction console, :mutate do
      console
      |> Console.move_cursor(prompt.location)
      |> Console.put_iodata(full_content)
    end

    ExTerm.io_reply(prompt.reply, full_content)
    nil
  end

  def paste(prompt = %{console: console}, content) do
    precursor =
      content
      |> breakdown
      |> Kernel.++(prompt.precursor)

    paint(%{prompt | precursor: precursor})
  end

  def append(prompt, charlist) do
    precursor =
      charlist
      |> breakdown
      |> Kernel.++(prompt.precursor)

    paint(%{prompt | precursor: precursor})
  end

  def substitute(prompt, substitution) do
    precursor = breakdown(substitution)
    paint(%{prompt | precursor: precursor})
  end

  defp breakdown(charlist_or_string, so_far \\ [])

  defp breakdown(string, so_far) when is_list(string) do
    case string do
      [] -> so_far
      [this | rest] -> breakdown(rest, [List.to_string([this]) | so_far])
    end
  end

  defp breakdown(string, so_far) when is_binary(string) do
    case String.next_grapheme(string) do
      nil -> so_far
      {grapheme, rest} -> breakdown(rest, [grapheme | so_far])
    end
  end

  defp paint(prompt = %{console: console}, extras \\ nil) do
    Helpers.transaction console, :mutate do
      precursor =
        prompt.precursor
        |> Enum.reverse()
        |> IO.iodata_to_binary()

      console
      |> Console.move_cursor(prompt.location)
      |> Console.put_iodata(precursor)

      cursor = Console.cursor(console)

      postcursor = IO.iodata_to_binary(prompt.postcursor ++ List.wrap(extras))

      Console.put_iodata(console, postcursor)
      Console.move_cursor(console, cursor)
    end

    prompt
  end
end
