defmodule ExTerm.JS do
  @moduledoc false
  use Phoenix.LiveComponent

  @exterm_js Path.join(__DIR__, "../_js/ex_term.js")
  @external_resource @exterm_js
  @js File.read!(@exterm_js)

  def render(_) do
    assigns = %{js: @js}

    ~H"""
    <script>
    <%= Phoenix.HTML.raw(@js) %>
    </script>
    """
  end
end

defmodule ExTerm.CSS do
  @moduledoc false
  use Phoenix.LiveComponent

  @exterm_css Path.join(__DIR__, "../_css/default.css")
  @external_resource @exterm_css
  @css File.read!(@exterm_css)

  def render(assigns) do
    assigns = %{css: Map.get(assigns, :css, @css)}

    ~H"""
    <style>
    <%= Phoenix.HTML.raw(@css) %>
    </style>
    """
  end
end
