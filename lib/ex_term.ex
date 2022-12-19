defmodule ExTerm do
  alias ExTerm.Buffer
  alias ExTerm.Console
  alias ExTerm.Tty

  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    <div id="exterm-terminal" class={class_for(@focus)} phx-keydown="keydown" phx-focus="focus" phx-blur="blur" tabindex="0">
      <Buffer.render lines={@buffer_lines} count={@buffer.count}/>
      <Console.render console={@console}/>
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
      |> set_buffer
      |> set_console
      |> set_focus

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

  defp set_console(socket, console \\ Console.new()) do
    assign(socket, console: console)
  end

  defp set_buffer(socket, buffer \\ Buffer.new()) do
    assign(socket, buffer: buffer)
  end

  defp set_focus(socket, focus \\ false) do
    assign(socket, focus: focus)
  end

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
    {new_console, buffer_lines} = Console.put_chars(socket.assigns.console, chars)
    new_socket = repl(socket, new_console, buffer_lines)

    reply(from, :ok)
    {:noreply, new_socket}
  end

  defp get_line_impl(from, prompt, socket) do
    {new_console, buffer_lines} = Console.start_prompt(from, socket.assigns.console, prompt)
    {:noreply, repl(socket, new_console, buffer_lines)}
  end

  defp get_geometry_impl(from, type, socket) do
    socket.assigns.console.dimensions

    reply(from, Console.get_dimension(socket.assigns.console, type))

    {:noreply, socket}
  end

  #############################################################################
  ## KEYDOWN IMPLEMENTATIONS

  @ignores ~w(Shift Alt Control)

  defp enter_impl(socket) do
    {new_console, buffer_lines} = Console.hit_enter(socket.assigns.console)
    {:noreply, repl(socket, new_console, buffer_lines)}
  end

  defp key_impl(key, socket) do
    {new_console, buffer_lines} = Console.push_key(socket.assigns.console, key)
    {:noreply, repl(socket, new_console, buffer_lines)}
  end

  defp ignore_impl(socket), do: {:noreply, socket}

  #############################################################################
  ## Common functions

  defp repl(socket, new_console, buffer_lines) do
    socket
    |> set_console(new_console)
    |> push_buffer(buffer_lines)
  end

  defp push_buffer(socket, buffer_lines) do
    assign(socket, :buffer_lines, Enum.reverse(buffer_lines))
  end

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
