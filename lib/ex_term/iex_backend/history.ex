defmodule ExTerm.IexBackend.History do
  @type t :: {past :: [String.t()], future :: [String.t()]}

  alias ExTerm.IexBackend.Prompt

  def new, do: {[], []}

  def up(state = %{history: {[], _}}), do: state

  def up(state = %{history: {[this | past], future}, prompt: prompt}) do
    %{state | history: {past, [this | future]}, prompt: Prompt.substitute(prompt, this)}
  end

  def down(state = %{history: {past, []}}), do: state

  def down(state = %{history: {past, [this | future]}, prompt: prompt}) do
    %{state | history: {[this | past], future}, prompt: Prompt.substitute(prompt, this)}
  end

  def commit(state = %{history: {past, future}, prompt: prompt}) do
    content =
      prompt.precursor
      |> Enum.reverse(prompt.postcursor)
      |> IO.iodata_to_binary()

    new_past =
      future
      |> Enum.reverse(past)
      |> List.insert_at(0, content)

    %{state | history: {new_past, []}}
  end
end
