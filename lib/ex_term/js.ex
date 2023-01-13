defmodule ExTerm.JS do
  use Phoenix.LiveComponent

  @script __DIR__ |> Path.join("../_js/ex_term.js") |> File.read!()

  def render(_) do
    assigns = %{script: @script}
    ~H"""
    <script>
    <%= @script %>
    </script>
    """
  end
end
