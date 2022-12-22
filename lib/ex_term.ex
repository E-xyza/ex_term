defmodule ExTerm do
  alias ExTerm.Buffer
  alias ExTerm.Console
  # TODO: move all Data access to defdelegate from Console.
  alias ExTerm.Console.Data
  alias ExTerm.Tty

  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    <div id="exterm-terminal" class={class_for(@focus)} phx-keydown="keydown" phx-focus="focus" phx-blur="blur" tabindex="0">
      <%= if @console do %>
      <Buffer.render buffer={@buffer_lines}/>
      <Console.render storage={@console} taint={@taint}/>
      <% end %>
    </div>
    """
  end

  defp class_for(state) do
    if state, do: "exterm exterm-focused", else: "exterm exterm-blurred"
  end

  def mount(_, _, socket) do
    new_socket =
      socket
      |> set_tty
      |> set_buffer()
      |> set_console(if connected?(socket), do: Data.new())
      |> set_focus
      |> taint

    {:ok, new_socket, temporary_assigns: [buffer_lines: []]}
  end

  #############################################################################
  ## Socket Reducers

  defp set_tty(socket) do
    if connected?(socket) do
      # TODO: make this supervised
      {:ok, tty} = Tty.start_link([])

      assign(socket, tty: tty)
    else
      socket
    end
  end

  defp set_buffer(socket, buffer \\ %Buffer{}) do
    assign(socket, buffer: buffer)
  end

  defp set_console(socket, console) do
    assign(socket, console: console)
  end

  defp set_focus(socket, focus \\ false) do
    assign(socket, focus: focus)
  end

  defp push_buffer_lines(socket, lines) do
    assign(socket, buffer_lines: lines)
  end

  # console size is known, but the last line of the console might have moved.
  # in this case, ship those lines to `buffer` so that the liveview process
  # can forget they exist.
  defp adjust_buffer(socket = %{assigns: %{console: console, buffer: buffer}}) do
    case Data.buffer_shift(console, buffer.top_row) do
      {[], _} ->
        socket

      {lines, new_top} ->
        socket
        |> set_buffer(%{buffer | top_row: new_top})
        |> push_buffer_lines(lines)
    end
  end

  # since the re-rendering depends on assigns being altered, if all of the
  # changes occur in the mutable terminal, the re-rendering might miss a diff
  # and fail to repaint the buffer and console. `taint` function forces a
  # repaint and reevaluation by altering the socket assigns.
  defp taint(socket), do: assign(socket, taint: make_ref())

  #############################################################################
  ## LIVEVIEW EVENT IMPLEMENTATIONS

  defp focus_impl(_payload, socket) do
    {:noreply, set_focus(socket, true)}
  end

  defp blur_impl(_payload, socket) do
    {:noreply, set_focus(socket, false)}
  end

  #############################################################################
  ## IO IMPLEMENTATIONS

  defp put_chars_impl(from, chars, socket) do
    Console.put_chars(socket.assigns.console, chars)
    reply(from, :ok)

    new_socket =
      socket
      |> adjust_buffer
      |> taint

    {:noreply, new_socket}
  end

  defp get_line_impl(from, prompt, socket) do
    Console.start_prompt(from, socket.assigns.console, prompt)
    {:noreply, socket}
  end

  defp get_geometry_impl(from, type, socket) do
    reply(from, Console.get_dimension(socket.assigns.console, type))
    {:noreply, socket}
  end

  #############################################################################
  ## KEYDOWN IMPLEMENTATIONS

  @ignores ~w(Shift Alt Control)

  defp enter_impl(socket) do
    {new_console, buffer_lines} = Console.hit_enter(socket.assigns.console)
    {:noreply, socket}
  end

  defp key_impl(key, socket) do
    {new_console, buffer_lines} = Console.push_key(socket.assigns.console, key)
    {:noreply, socket}
  end

  defp ignore_impl(socket), do: {:noreply, socket}

  #############################################################################
  ## Common functions

  def reply({pid, ref}, reply) do
    send(pid, {:io_reply, ref, reply})
  end

  #############################################################################
  ## EVENT ROUTERS

  defp handle_io_request(from, {:put_chars, :unicode, str}, socket) do
    put_chars_impl(from, str, socket)
  end

  defp handle_io_request(from, {:get_line, :unicode, prompt}, socket) do
    get_line_impl(from, prompt, socket)
  end

  defp handle_io_request(from, {:get_geometry, type}, socket) do
    get_geometry_impl(from, type, socket)
  end

  defp handle_keydown("Enter", socket), do: enter_impl(socket)
  defp handle_keydown(key = <<_>>, socket), do: key_impl(key, socket)
  defp handle_keydown(ignored, socket) when ignored in @ignores, do: ignore_impl(socket)

  def handle_event("focus", payload, socket), do: focus_impl(payload, socket)
  def handle_event("blur", payload, socket), do: blur_impl(payload, socket)
  def handle_event("keydown", %{"key" => key}, socket), do: handle_keydown(key, socket)

  def handle_event(type, payload, socket) do
    IO.warn("unhandled event of type #{type} (#{Jason.encode!(payload)})")
    {:noreply, socket}
  end

  def handle_info({:io_request, pid, ref, request}, socket) do
    handle_io_request({pid, ref}, request, socket)
  end
end
