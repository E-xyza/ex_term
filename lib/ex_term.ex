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

  alias ExTerm.Buffer
  alias ExTerm.Console
  # TODO: move all Data access to defdelegate from Console.
  alias ExTerm.Console.Data
  alias ExTerm.Prompt
  alias ExTerm.Tty

  use Phoenix.LiveView
  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <div id="exterm-terminal" class={class_for(@focus)} phx-keydown="keydown" phx-focus="focus" phx-blur="blur" tabindex="0">
      <div id="exterm-container">
        <Buffer.render buffer={@buffer_lines}/>
        <%= if @console do %>
        <Console.render rows={@rows} cursor={@cursor} prompt={@prompt}/>
        <div id="exterm-anchor" phx-mounted={JS.dispatch("exterm:mounted", to: "#exterm-terminal")}/>
        <% end %>
      </div>
    </div>
    <div id="exterm-paste-target" phx-click="paste"/>
    <!-- this script causes the anchor div to be pushed to the bottom-->
    <script>
      (() => {
        const terminal = document.getElementById("exterm-terminal");
        const paste_target = document.getElementById("exterm-paste-target")
        terminal.addEventListener("exterm:mounted", event => event.target.scroll(0, 5));

        const rowCol = (node) => {
          var id;
          if (node.nodeType === 3) { id = node.parentNode.id } else { id = node.id }
          [_, _, row, col] = id.split("-");
          return [Number(row), Number(col)];
        }

        const fetchCols = (row, [row1, col1], [row2, col2]) => {
          var col_start = 0;
          var line = "";
          var index = 1;
          var buffered_spaces = 0;
          if (row == row1) { index = col1; }

          while (true) {
            element = document.getElementById("exterm-cell-" + row + "-" + index);
            // pull out if we're at the end of the line.
            if (!element) break;

            // if it's empty then don't add it in, just increment buffered spaces
            var content = element.textContent.trim();

            if (content === "") {
              buffered_spaces += 1;
            } else {
              line += " ".repeat(buffered_spaces) + content;
              buffered_spaces = 0;
            }

            // pull out if we're at the end.
            if (row == row2 && index == col2) break;
            index += 1;
          }
          return line + "\n"
        }

        const fetchRows = (coord1, coord2) => {
          // first put rows in order.
          var start, end;
          if (coord1[0] < coord2[0]) {
            start = coord1;
            end = coord2;
          } else if (coord1[0] == coord2[0]) {
            if (coord1[1] < coord2[1]) {
              start = coord1;
              end = coord2;
            } else {
              start = coord2;
              end = coord1;
            }
          } else {
            start = coord2;
            end = coord1;
          }
          var result = "";
          for (let index = start[0]; index <= end[0]; index++) {
            result += fetchCols(index, start, end);
          }
          return result;
        }

        const modifyClipboard = (event) => {
          const selection = window.getSelection();
          copied = fetchRows(rowCol(selection.anchorNode), rowCol(selection.focusNode));
          event.clipboardData.setData("text/plain", copied);
          event.preventDefault();
        }

        const sendPaste = (event) => {
          const paste_data = event.clipboardData.getData("text/plain");
          paste_target.setAttribute("phx-value-paste", paste_data);
          paste_target.click();
          event.preventDefault();
        }

        terminal.addEventListener("copy", modifyClipboard);
        terminal.addEventListener("paste", sendPaste)
      })()
    </script>
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

  defp paste_impl(string, socket) do
    new_socket = socket
    |> do_paste(string)
    |> repaint

    {:noreply, new_socket}
  end

  defp do_paste(socket = %{assigns: %{prompt: prompt}}, string) do
    case String.next_grapheme(string) do
      {grapheme, rest} ->
        socket
        |> set_prompt(Prompt.push_key(prompt, grapheme), repaint: Prompt.active?(prompt))
        |> do_paste(rest)
      nil ->
        socket
    end
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
  def handle_event("paste", %{"paste" => string}, socket), do: paste_impl(string, socket)

  def handle_event(type, payload, socket) do
    IO.warn("unhandled event of type #{type} (#{Jason.encode!(payload)})")
    {:noreply, socket}
  end

  def handle_info({:io_request, pid, ref, request}, socket) do
    handle_io_request({pid, ref}, request, socket)
  end
end
