defmodule ExTerm do
  alias ExTerm.Buffer
  alias ExTerm.Console
  alias ExTerm.Tty

  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    <div id="exterm-terminal" class={class_for(@focus)} phx-keydown="keydown" phx-focus="focus" phx-blur="blur" tabindex="0">
      <Buffer.render buffer={@buffer}/>
      <Console.render console={@console}/>
    </div>
    """
  end

  def line(assigns) do
    ~H"""
    <div id={@id}><%= for {css, text} <- @spans do %><span style={css}><%= text %></span><% end %></div>
    """
  end

  def cell(assigns) do
    if assigns.cursor do
      ~H"""
      <div class="exterm-cell exterm-cursor">_</div>
      """
    else
      ~H"""
      <div style={@style} id={@id} class="exterm-cell"><%= render_slot(@inner_block) %></div>
      """
    end
  end

  defp class_for(state) do
    if state, do: "exterm exterm-focused", else: "exterm exterm-faded"
  end

  def mount(_, _, socket) do
    new_socket =
      socket
      |> set_tty
      |> set_buffer
      |> set_console

    {:ok, new_socket, temporary_assigns: [buffer: []]}
  end

  defp set_tty(socket) do
    if connected?(socket) do
      # TODO: make this supervised
      {:ok, tty} = Tty.start_link()
      assign(socket, tty: tty)
    else
      socket
    end
  end

  #############################################################################
  ## Socket Reducers

  defp set_console(socket, console \\ Console.new()) do
    assign(socket, console: console)
  end

  defp set_buffer(socket, buffer \\ Buffer.new()) do
    assign(socket, buffer: buffer)
  end

  #############################################################################
  ## LIVEVIEW EVENT IMPLEMENTATIONS

  defp focus_impl(_payload, socket) do
    {:noreply, socket}
  end

  defp blur_impl(_payload, socket) do
    {:noreply, socket}
  end

  #############################################################################
  ## IO IMPLEMENTATIONS

  defp put_chars_impl(_addr, _chars, socket) do
    {:noreply, socket}
  end

  defp get_line_impl(_addr, _prompt, socket) do
    {:noreply, socket}
  end

  defp get_geometry_impl(addr, type, socket) do
    {:noreply, socket}
  end

  #############################################################################
  ## KEYDOWN IMPLEMENTATIONS

  @ignores ~w(Shift)

  defp enter_impl(socket) do
    IO.puts("got Enter")
    {:noreply, socket}
  end

  defp key_impl(key, socket) do
    IO.puts("got #{key}")
    {:noreply, socket}
  end

  defp ignore_impl(socket), do: {:noreply, socket}

  #############################################################################
  ## Generic Tools

  defp reply({from, ref}, reply) do
    send(from, {:io_reply, ref, reply})
  end

  #############################################################################
  ## EVENT ROUTERS

  defp handle_io_request(addr, {:put_chars, :unicode, str}, socket) do
    put_chars_impl(addr, str, socket)
  end

  defp handle_io_request(addr, {:get_line, :unicode, prompt}, socket) do
    get_line_impl(addr, prompt, socket)
  end

  defp handle_io_request(addr, {:get_geometry, type}, socket) do
    get_geometry_impl(addr, type, socket)
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

  def handle_info({:io_request, from, ref, request}, socket) do
    handle_io_request({from, ref}, request, socket)
  end
end
