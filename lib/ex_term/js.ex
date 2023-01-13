defmodule ExTerm.JS do
  use Phoenix.LiveComponent

  @exterm_js Path.join(__DIR__, "../_js/ex_term.js")
  @external_resource @exterm_js
  @script File.read!(@exterm_js)

  def render(_) do
    assigns = %{script: @script}
    ~H"""
    <script>
    <%= Phoenix.HTML.raw(@script) %>
    </script>
    """
  end
end
