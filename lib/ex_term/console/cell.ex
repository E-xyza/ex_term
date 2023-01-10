defmodule ExTerm.Console.Cell do
  @moduledoc false

  use Phoenix.Component

  alias ExTerm.Style
  alias ExTerm.Prompt

  defstruct style: Style.new(), char: nil
  @type t :: %__MODULE__{style: Style.t(), char: nil | String.t()}
  def new, do: %__MODULE__{}
end
