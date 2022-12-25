defmodule ExTerm do
  alias ExTerm.Buffer
  alias ExTerm.Console
  # TODO: move all Data access to defdelegate from Console.
  alias ExTerm.Console.Data
  alias ExTerm.Prompt
  alias ExTerm.Tty

  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    <div id="exterm-terminal" class={class_for(@focus)} phx-keydown="keydown" phx-focus="focus" phx-blur="blur" tabindex="0">
      <%= if @console do %>
      <div id="exterm-container">
        <Buffer.render buffer={@buffer_lines}/>
        <Console.render rows={@rows} cursor={@cursor} prompt={@prompt}/>
      </div>
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
      |> set_modifiers
      |> set_buffer
      |> set_console(if connected?(socket), do: Data.new())
      |> set_focus
      |> set_prompt
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

  defp set_modifiers(socket, modifier \\ nil) do
    if modifier do
      {key, bool} = modifier
      assign(socket, modifiers: Map.put(socket.assigns.modifiers, key, bool))
    else
      assign(socket, modifiers: %{})
    end
  end

  defp set_prompt(socket, prompt \\ %Prompt{}, opts \\ []) do
    if opts[:repaint] do
      Prompt.paint(prompt, &Console.paint_chars(socket.assigns.console, &1, &2, &3))
    end

    assign(socket, prompt: prompt)
  end

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

    {cursor, rows} =
      if console do
        Data.console(console)
      else
        {nil, []}
      end

    assign(new_socket, rows: rows, cursor: cursor)
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

  defp get_line_impl(from, prompt_text, socket = %{assigns: %{prompt: prompt, console: console}}) do
    # prompt contains "from" which is {ref, pid} if the prompt got activated
    # and we are waiting for I/O.
    # nil if there was content in the queue and it needs to be
    # sent to I/O.

    # always send the prompt_text to the console first.
    Console.put_chars(console, prompt_text)
    location = Data.metadata(console, :cursor)

    prompt =
      case Prompt.activate(prompt, from, location) do
        {content, prompt = %Prompt{reply: nil}} ->
          reply(from, content)
          prompt

        {_, prompt} ->
          prompt
      end

    new_socket =
      socket
      |> set_prompt(prompt, repaint: true)
      |> repaint

    {:noreply, new_socket}
  end

  defp get_geometry_impl(from, type, socket) do
    reply(from, Console.get_dimension(socket.assigns.console, type))
    {:noreply, socket}
  end

  #############################################################################
  ## KEYDOWN IMPLEMENTATIONS

  defp enter_impl(socket = %{assigns: %{prompt: prompt, console: console}}) do
    new_prompt = Prompt.submit(prompt, &reply/2)
    new_socket = set_prompt(socket, new_prompt, repaint: true)

    # if it's not active, then only trap the enter, but don't change
    # the console contents.
    if Prompt.active?(prompt) do
      Console.cursor_crlf(console)
    end

    {:noreply, repaint(new_socket)}
  end

  defp backspace_impl(socket), do: change_prompt(socket, &Prompt.backspace/1)

  defp delete_impl(socket), do: change_prompt(socket, &Prompt.delete/1)

  defp key_impl(key, socket) do
    if Enum.any?(socket.assigns.modifiers, &elem(&1, 1)) do
      {:noreply, socket}
    else
      change_prompt(socket, &Prompt.push_key(&1, key))
    end
  end

  defp arrow_impl(:left, socket), do: change_prompt(socket, &Prompt.left/1)

  defp arrow_impl(:right, socket), do: change_prompt(socket, &Prompt.right/1)

  defp arrow_impl(_direction, socket) do
    {:noreply, socket}
  end

  # Shift is not a modifier because it actually changes the ascii character
  # that Javascript sends down onkeydown.
  @modifiers ~w(Alt Control)

  defp modifier_dn_impl(key, socket) do
    {:noreply, set_modifiers(socket, {key, true})}
  end

  defp modifier_up_impl(key, socket) do
    {:noreply, set_modifiers(socket, {key, false})}
  end

  @silent ~w(PageDown PageUp Shift)

  defp ignore_impl(ignored, socket) do
    unless ignored in @silent do
      IO.warn("got #{ignored}")
    end
    {:noreply, socket}
  end

  #############################################################################
  ## Common functions

  defp change_prompt(socket = %{assigns: %{prompt: prompt}}, lambda) do
    new_socket =
      socket
      |> set_prompt(lambda.(prompt), repaint: Prompt.active?(prompt))
      |> repaint

    {:noreply, new_socket}
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
  defp handle_keydown("Backspace", socket), do: backspace_impl(socket)
  defp handle_keydown("Delete", socket), do: delete_impl(socket)
  defp handle_keydown("ArrowLeft", socket), do: arrow_impl(:left, socket)
  defp handle_keydown("ArrowRight", socket), do: arrow_impl(:right, socket)
  defp handle_keydown("ArrowUp", socket), do: arrow_impl(:up, socket)
  defp handle_keydown("ArrowDown", socket), do: arrow_impl(:down, socket)
  defp handle_keydown(key = <<_>>, socket), do: key_impl(key, socket)
  defp handle_keydown(key, socket) when key in @modifiers, do: modifier_dn_impl(key, socket)
  defp handle_keydown(ignored, socket), do: ignore_impl(ignored, socket)

  defp handle_keyup(key, socket) when key in @modifiers, do: modifier_up_impl(key, socket)

  def handle_event("focus", payload, socket), do: focus_impl(payload, socket)
  def handle_event("blur", payload, socket), do: blur_impl(payload, socket)
  def handle_event("keydown", %{"key" => key}, socket), do: handle_keydown(key, socket)
  def handle_event("keyup", %{"key" => key}, socket), do: handle_keyup(key, socket)

  def handle_event(type, payload, socket) do
    IO.warn("unhandled event of type #{type} (#{Jason.encode!(payload)})")
    {:noreply, socket}
  end

  def handle_info({:io_request, pid, ref, request}, socket) do
    handle_io_request({pid, ref}, request, socket)
  end
end
