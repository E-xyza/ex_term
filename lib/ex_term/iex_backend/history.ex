defmodule ExTerm.IexBackend.History do
  @moduledoc false
  @type t :: {past :: [String.t()], future :: [String.t()]}

  alias ExTerm.IexBackend.Prompt

  def new, do: {[], []}

  @spec up(t, String.t | nil) :: nil | {t, String.t}

  def up({[], _}, _prompt), do: nil

  def up({[this | past], []}, this), do: up({past, [this]}, nil)

  def up({[this | past], future}, _prompt), do: {{past, [this | future]}, this}

  @spec down(t, String.t | nil) :: nil | {t, String.t}
  def down({_, []}, _prompt), do: nil

  def down({[], [this | future]}, this), do: down({[this], future}, nil)

  def down({past, [this | future]}, _prompt), do: {{[this | past], future}, this}

  @spec commit(t, String.t) :: t
  def commit({past, future}, content) do
    new_past =
      future
      |> Enum.reverse(past)
      |> List.insert_at(0, content)

    {new_past, []}
  end
end
