defmodule ExTerm.TerminalBackend do
  @moduledoc """
  Default backend that creates a `ExTerm.IoServer` process and forwards all
  callbacks to its wrapping module.  By default, this is set to
  `ExTerm.TerminalBackend.IoServer`.

  ### TerminalBackend specific options:

  This option can be set in the router declaration (see `ExTerm.Router`)

  - `:io_server` a module, should be a supervisable `GenServer` which
    satisfies a minimal set of `ExTerm.IoServer` callbacks.  The required
    implementations are as follows:

    - *list coming in v 0.3.0*

    #### Example

    ```
    live_term "/", pubsub: MyWebApp.PubSub, io_server: MyIoServer
    ```

  ### TerminalBackend.IoServer specific

  This option can be set in the router declaration (see `ExTerm.Router`)

  - `:terminal` a (module, function, args) for the function that should be
    run inside of the terminal task.  This should be a REPL that takes over
    the task, and typically will be an infinite loop (return type `no_return`).
    If the function terminates, the io server will suffer a fatal error and
    the terminal liveview will be rendered unusable.

    #### Example

    ```
    live_term "/", pubsub: MyWebApp.PubSub, terminal: {MyModule, :run, []}
    ```
  """
  alias ExTerm.Backend
  alias Phoenix.PubSub
  import Phoenix.Component

  @behaviour Backend

  @impl Backend
  def on_connect(_params, %{"exterm-backend" => {__MODULE__, opts}}, socket) do
    io_server = Keyword.get(opts, :io_server, ExTerm.TerminalBackend.IOServer)
    opts = Keyword.put(opts, :callers, [self() | Process.get(:"$callers", [])])

    {:ok, pid} = DynamicSupervisor.start_child(ExTerm.BackendSupervisor, {io_server, opts})

    pubsub = Keyword.fetch!(opts, :pubsub)
    pubsub_topic = io_server.pubsub_topic(pid)

    PubSub.subscribe(pubsub, pubsub_topic)

    # monitor the process, LiveView should know when its child has died.
    Process.monitor(pid)

    {:ok, io_server.console(pid), assign(socket, io_server: {io_server, pid})}
  end

  @impl Backend
  def on_focus(socket), do: call(socket, :on_focus, [])

  @impl Backend
  def on_blur(socket), do: call(socket, :on_blur, [])

  @impl Backend
  def on_keydown(key, socket), do: call(socket, :on_keydown, [key])

  @impl Backend
  def on_keyup(key, socket), do: call(socket, :on_keyup, [key])

  @impl Backend
  def on_paste(string, socket), do: call(socket, :on_paste, [string])

  @impl Backend
  def on_event(type, payload, socket), do: call(socket, :on_event, [type, payload])

  defp call(socket = %{assigns: %{io_server: {io_server, pid}}}, what, args) do
    apply(io_server, what, [pid | args])
    {:noreply, socket}
  end
end
