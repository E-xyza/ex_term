defmodule ExTerm do
  @moduledoc """
  ## Description

  ExTerm is an IEx console LiveView component.  The IEx console is responsible for converting your
  interactions with the browser into erlang IO protocol so that you can execute code from your
  browser.

  ## Installation

  1. Add ExTerm to your mix.exs:

  ```elixir

  def deps do
    [
      # ...
      {:ex_term, "~> 0.1"}
      # ...
    ]
  end
  ```

  2. Create a live view in your routes
    - as a standalone liveview

      ```elixir
      scope "/" do
        pipe_through :browser
        pipe_through :extra_authorization

        live "/", ExTerm
      end
      ```

    - you can also use it as a live component!

      ```elixir
      <.live_component module={ExTerm}/>
      ```

  ### Not implemented yet (soon):
  - up arrow (history)
  - tab completion
  - copy/paste

  ### Planned (Pro?) features:
  - provenance tracking
  - multiplayer mode
  """

  alias ExTerm.Console
  alias ExTerm.Console.Cell
  alias ExTerm.Console.Helpers
  alias ExTerm.Console.Update
  alias Phoenix.LiveView.JS

  require Console
  require Helpers

  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    <div id="exterm-terminal" contenteditable spellcheck="false" class={class_for(@focus)} phx-keydown="keydown" phx-focus="focus" phx-blur="blur" tabindex="0">
      <Console.render :if={@console} cells={@cells} cursor={@cursor} prompt={@prompt}/>
      <div :if={@console} id="exterm-anchor" phx-mounted={JS.dispatch("exterm:mounted", to: "#exterm-terminal")}/>
    </div>
    <div id="exterm-paste-target" phx-click="paste"/>

    <ExTerm.JS.render/>
    <ExTerm.CSS.render css={@css}/>
    """
  end

  defp class_for(state) do
    if state, do: "exterm exterm-focused", else: "exterm exterm-blurred"
  end

  # TODO: modularize this.
  @backend ExTerm.IexBackend

  def mount(params, session = %{"exterm-backend" => {backend, opts}}, socket) do
    if connected?(socket) do
      case backend.on_connect(params, session, socket) do
        {:ok, console, socket} ->
          # obtain the layout and dump the whole layout.
          {rows, columns} =
            Helpers.transaction console, :access do
              Console.layout(console)
            end

          # fill the cells with dummy cells that won't be in the initial layout.
          sentinel_column = columns + 1

          cells =
            for row <- 1..rows, column <- 1..sentinel_column do
              {{row, column}, %Cell{char: if(column === sentinel_column, do: "\n")}}
            end

          css =
            case Keyword.fetch(opts, :css) do
              :error ->
                true

              {:ok, {:file, file}} ->
                File.read!(file)

              {:ok, content} when is_binary(content) ->
                content
            end

          new_socket =
            socket
            |> init(console)
            |> assign(backend: backend, cells: cells, css: css)

          {:ok, new_socket, temporary_assigns: [cells: []]}
      end
    else
      {:ok, init(socket), temporary_assigns: [cells: []]}
    end
  end

  # reducers
  defp init(socket, console \\ nil) do
    socket
    |> set_cursor
    |> set_focus
    |> set_prompt
    |> set_console(console)
    |> set_css(true)
  end

  defp set_cursor(socket, cursor \\ {1, 1}) do
    assign(socket, cursor: cursor)
  end

  defp set_focus(socket, focus \\ false) do
    assign(socket, focus: focus)
  end

  defp set_prompt(socket, prompt \\ false)

  defp set_prompt(socket = %{assigns: %{console: console, cursor: cursor}}, prompt) do
    cell =
      Helpers.transaction console, :access do
        Console.get(console, cursor)
      end

    assign(socket, prompt: prompt, cells: [{cursor, cell}])
  end

  defp set_prompt(socket, false) do
    assign(socket, prompt: false)
  end

  defp set_console(socket, console) do
    assign(socket, console: console)
  end

  defp set_css(socket, css) do
    assign(socket, css: css)
  end

  # handlers

  def handle_event("focus", _payload, socket) do
    socket
    |> set_focus(true)
    |> socket.assigns.backend.on_focus()
  end

  def handle_event("blur", _payload, socket) do
    socket
    |> set_focus(false)
    |> socket.assigns.backend.on_blur()
  end

  def handle_event("keydown", %{"key" => key}, socket) do
    socket.assigns.backend.on_keydown(key, socket)
  end

  def handle_event("keyup", %{"key" => key}, socket) do
    socket.assigns.backend.on_keyup(key, socket)
  end

  def handle_event("paste", %{"paste" => string}, socket) do
    socket.assigns.backend.on_paste(string, socket)
  end

  def handle_event(type, payload, socket) do
    socket.assigns.backend.handle_event(type, payload, socket)
  end

  def handle_info(update = %Update{}, socket = %{assigns: %{console: console}}) do
    cells =
      Helpers.transaction console, :access do
        Update.get(update, console)
      end

    new_socket =
      if cursor = update.cursor do
        assign(socket, cells: cells, cursor: cursor)
      else
        assign(socket, cells: cells)
      end

    {:noreply, new_socket}
  end

  def handle_info({:prompt, activity}, socket) when activity in [:active, :inactive] do
    {:noreply, set_prompt(socket, activity === :active)}
  end
end
