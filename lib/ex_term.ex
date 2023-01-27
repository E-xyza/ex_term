defmodule ExTerm do
  @moduledoc """
  ## Description

  ExTerm is an terminal `Phoenix.LiveView` component.  ExTerm is responsible
  for converting erlang IO protocol messages into web output and translating
  web input into responses in the IO protocol.

  ## Installation

  Add ExTerm to your mix.exs:

  ```elixir

  def deps do
  [
    # ...
    {:ex_term, "~> 0.2"}
    # ...
  ]
  end
  ```

  ### How to create a live terminal in your Phoenix router

  ExTerm provides the convenience helper `ExTerm.Router.live_term/3` that you
  can use to create a live view route.

  You must supply a `Phoenix.PubSub` server that is the communication channel
  to send important updates to the liveview.  It's recommended to use the
  PubSub server associated with your web server.

  The default backend is `ExTerm.TerminalBackend` and the default terminal is
  `IEx.Server`.  Both of these are customizable.

  - with the default backend and default terminal

    ```elixir
    import ExTerm.Router

    scope "/live_term" do
      pipe_through :browser

      live_term "/", pubsub_server: MyAppWeb.PubSub
    end
    ```

  - with the default backend and a custom interaction layer

    ```elixir
    import ExTerm.Router

    scope "/live_term" do
      pipe_through :browser

      live_term "/", pubsub_server: MyAppWeb.PubSub, terminal: {__MODULE__, :function, []}
    end
    ```

  - with a custom backend


    ```elixir
    import ExTerm.Router

    scope "/live_term" do
      pipe_through :browser

      live_term "/", MyBackend, pubsub_server: MyAppWeb.PubSub
    end
    ```

  ### Customizing layout (CSS)

  You can customize the css for the layout, by providing either a builtin
  layout option or providing your own.  To use a builtin layout, pass the
  layout name `:default` or `:bw` (for black and white console text) as
  the css option, as follows:

  ```elixir
    live_term "/", pubsub_server: MyAppWeb.PubSub, css: :bw
  ```

  To use a custom layout, put the layout file in the `priv` directory of your
  applicatyon and pass the relative path as follows:

  ```elixir
    live_term "/", MyBackend, pubsub_server: MyAppWeb.PubSub, css: {:priv, my_app, "path/to/my_layout.css"}
  ```

  Note that this content must be available at compile time.
  """

  alias ExTerm.Console
  alias ExTerm.Console.Cell
  alias ExTerm.Console.Helpers
  alias ExTerm.Console.Update
  alias ExTerm.Style
  alias Phoenix.LiveView.JS

  require Console
  require Helpers

  use Phoenix.LiveView

  @doc false
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

  defp class_for(focus) do
    case focus do
      true -> ~w"exterm exterm-focused"
      false -> ~w"exterm exterm-blurred"
      :error -> ~w"exterm exterm-errored"
    end
  end

  @doc false
  def mount(params, session = %{"exterm-backend" => {backend, opts}}, socket) do
    css = Keyword.fetch!(opts, :css)

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

          new_socket =
            socket
            |> init(css, console)
            |> assign(backend: backend, cells: cells)

          {:ok, new_socket, temporary_assigns: [cells: []]}
      end
    else
      {:ok, init(socket, css), temporary_assigns: [cells: []]}
    end
  end

  # reducers
  defp init(socket, css, console \\ nil) do
    socket
    |> assign(:css, css)
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

  @doc false
  def handle_event("focus", _payload, socket) do
    case socket.assigns.focus do
      false ->
        socket
        |> set_focus(true)
        |> socket.assigns.backend.on_focus()

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("blur", _payload, socket) do
    case socket.assigns.focus do
      true ->
        socket
        |> set_focus(false)
        |> socket.assigns.backend.on_blur()

      _ ->
        {:noreply, socket}
    end
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

  def handle_event(type, payload, socket = %{assigns: %{backend: backend}}) do
    if function_exported?(backend, :on_event, 3) do
      socket.assigns.backend.on_event(type, payload, socket)
    else
      {:noreply, socket}
    end
  end

  @doc false

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

  def handle_info({:DOWN, _, :process, _, {err, stacktrace}}, socket) do
    message = "fatal error crashed the console\n" <> Exception.format(:error, err, stacktrace)
    {row, _} = socket.assigns.cursor
    style = %Style{color: :red, "white-space": :pre, "overflow-anchor": :auto}

    {:noreply,
     assign(socket, focus: :error, cells: [{{row + 1, 1}, %Cell{style: style, char: message}}])}
  end
end
