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
      <Console.render rows={@rows} cursor={@cursor} prompt={@prompt}/>
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
      |> set_buffer
      |> set_console(if connected?(socket), do: Data.new())
      |> set_focus
      |> set_prompt
      |> set_key_buffer
      |> repaint

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

  defp set_buffer(socket, buffer \\ %Buffer{}), do: assign(socket, buffer: buffer)
  defp set_console(socket, console), do: assign(socket, console: console, rows: [], cursor: nil)
  defp set_focus(socket, focus \\ false), do: assign(socket, focus: focus)
  defp set_prompt(socket, prompting \\ false), do: assign(socket, prompt: prompting)
  defp set_key_buffer(socket, buffer \\ []), do: assign(socket, key_buffer: buffer)

  defp push_buffer_lines(socket, lines), do: assign(socket, buffer_lines: lines)

  # console size is known, but the last line of the console might have moved.
  # in this case, ship those lines to `buffer` so that the liveview process
  # can forget they exist.
  defp adjust_buffer(socket = %{assigns: %{console: console, buffer: buffer}}) do
    if console do
      case Data.buffer_shift(console, buffer.top_row) do
        {[], _} ->
          socket

        {lines, new_top} ->
          socket
          |> set_buffer(%{buffer | top_row: new_top})
          |> push_buffer_lines(lines)
      end
    else
      socket
    end
  end

  defp repaint(socket) do
    new_socket = %{assigns: %{console: console}} = adjust_buffer(socket)

    {cursor, rows, prompt} =
      if console do
        Data.console(console)
      else
        {nil, [], false}
      end

    assign(new_socket, rows: rows, cursor: cursor, prompt: prompt)
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
    Console.put_chars(socket.assigns.console, chars)

    new_socket = repaint(socket)

    reply(from, :ok)

    {:noreply, new_socket}
  end

  defp get_line_impl(
         from,
         prompt,
         socket = %{assigns: %{console: console, key_buffer: key_buffer}}
       ) do
    socket =
      key_buffer
      |> IO.iodata_to_binary()
      |> String.split("\n", parts: 2, trim: true)
      |> case do
        [] ->
          Console.start_prompt(from, console, prompt)
          socket

        [first | rest] ->
          Console.put_chars(console, prompt <> first)

          Data.transactionalize(console, fn ->
            Console.cursor_crlf(console)
          end)

          reply(from, first)
          set_key_buffer(socket, rest)
      end

    {:noreply, repaint(socket)}
  end

  defp get_geometry_impl(from, type, socket) do
    reply(from, Console.get_dimension(socket.assigns.console, type))
    {:noreply, socket}
  end

  #############################################################################
  ## KEYDOWN IMPLEMENTATIONS

  @ignores ~w(Shift Alt Control)

  defp enter_impl(socket = %{assigns: %{console: console, key_buffer: key_buffer}}) do
    new_socket =
      if Console.register_input(console, key_buffer) do
        socket
        |> repaint()
        |> set_key_buffer()
      else
        # nb using ++ syntax to avoid cons dialyzer warning
        set_key_buffer(socket, [key_buffer] ++ "\n")
      end

    {:noreply, new_socket}
  end

  defp key_impl(key, socket) do
    Console.push_key(socket.assigns.console, key)

    new_socket =
      socket
      |> repaint()
      # nb using ++ syntax to avoid cons dialyzer warning
      |> set_key_buffer([socket.assigns.key_buffer] ++ key)

    {:noreply, new_socket}
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
