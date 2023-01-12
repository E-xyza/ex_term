defmodule ExTerm.IexBackend.Prompt do
  @moduledoc false

  alias ExTerm.Console
  alias ExTerm.Console.Helpers

  require Helpers

  @enforce_keys [:location, :reply, :console]

  defstruct @enforce_keys ++ [precursor: [], postcursor: []]

  @type t :: %__MODULE__{
          location: ExTerm.location(),
          reply: GenServer.location(),
          console: Console.t(),
          precursor: [String.t()],
          postcursor: [String.t()]
        }

  def new(reply, location, console) do
    %__MODULE__{reply: reply, location: location, console: console}
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
      |> Console.put_string(full_content)
    end

    ExTerm.io_reply(prompt.reply, full_content)
    nil
  end

  defp paint(prompt = %{console: console}, extras \\ nil) do
    Helpers.transaction console, :mutate do
      precursor =
        prompt.precursor
        |> Enum.reverse()
        |> IO.iodata_to_binary()

      console
      |> Console.move_cursor(prompt.location)
      |> Console.put_string(precursor)

      cursor = Console.get_metadata(console, :cursor)

      postcursor = IO.iodata_to_binary(prompt.postcursor ++ List.wrap(extras))

      console
      |> Console.put_string(postcursor)
      |> Console.move_cursor(cursor)
    end

    prompt
  end
end
