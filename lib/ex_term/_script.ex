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

  # compile-time access to the default css content
  @builtin_path Path.join(__DIR__, "../_css")
  @builtins @builtin_path
            |> File.ls!()
            |> Enum.map(&String.to_atom(Path.rootname(&1)))
  @default_css_map Map.new(@builtins, &{&1, File.read!(Path.join(@builtin_path, "#{&1}.css"))})

  # private accessor functions available to the Router plug.
  def builtins, do: @builtins

  def default_css_map, do: @default_css_map

  def render(assigns) do
    ~H"""
    <style>
    <%= Phoenix.HTML.raw(@css) %>
    </style>
    """
  end
end
