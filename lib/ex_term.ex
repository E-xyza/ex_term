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

  2. Connect the ex_term CSS:
    - if you're using a css bundler, add to your "app.css" (or other css file in your assets directory)

      ```css
      @import "../../deps/ex_term/lib/css/default.css";
      ```

    - you may need a different strategy if you aren't using a css bundler.

  3. Create a live view in your routes
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
    """
  end

  defp class_for(state) do
    if state, do: "exterm exterm-focused", else: "exterm exterm-blurred"
  end

  # TODO: modularize this.
  @backend ExTerm.IexBackend

  def mount(params, session, socket) do
    if connected?(socket) do
      case @backend.mount(params, session, socket) do
        {:ok, identifier, console} ->
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

          new_socket =
            socket
            |> init(console)
            |> assign(backend: @backend, identifier: identifier, cells: cells)

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

  # handlers

  def handle_event("focus", payload, socket) do
    dispatch(:handle_focus, [], socket)
  end

  def handle_event("blur", payload, socket) do
    dispatch(:handle_blur, [], socket)
  end

  def handle_event("keydown", %{"key" => key}, socket) do
    dispatch(:handle_keydown, key, socket)
  end

  def handle_event("keyup", %{"key" => key}, socket) do
    dispatch(:handle_keyup, key, socket)
  end

  def handle_event("paste", %{"paste" => string}, socket) do
    dispatch(:handle_paste, string, socket)
  end

  def handle_event(type, payload, socket) do
    dispatch(:handle_event, [type, payload], socket)
  end

  def handle_info({:io_request, pid, ref, request}, socket) do
    dispatch(:handle_io_request, [{pid, ref}, request], socket)
  end

  def handle_info(
        update = %Update{},
        socket
      ) do
    raise "not yet"
  end

  def handle_info({:prompt, activity}, socket) when activity in [:active, :inactive] do
    {:noreply, set_prompt(socket, activity === :active)}
  end

  defp dispatch(what, payload, socket = %{assigns: %{backend: backend, identifier: identifier}}) do
    case apply(backend, what, [identifier | List.wrap(payload)]) do
      :ok ->
        {:noreply, socket}

      {:ok, update = %Update{}} ->
        dispatch(:handle_update, [update], socket)

      {:ok, assigns} ->
        {:noreply, assign(socket, assigns)}
    end
  end

  ### TOOLS
  @doc """
  sends a reply to server that implements erlang's io protocol.

  The form of this reply is `{:io_reply, ref, reply}`.  By default, `reply` will
  be the atom `:ok`.

  See:

  https://www.erlang.org/doc/apps/stdlib/io_protocol.html
  """
  def io_reply({pid, ref}, reply \\ :ok), do: send(pid, {:io_reply, ref, reply})
end
