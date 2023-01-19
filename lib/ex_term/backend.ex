defmodule ExTerm.Backend do
  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket

  @type params :: %{optional(String.t()) => term}
  @type session :: %{optional(String.t()) => term}
  @type json :: String.t() | nil | boolean | number | [json] | %{optional(String.t()) => json}

  @callback on_connect(params, session, LiveView.socket()) :: {:ok, Console.t(), Socket.t()}
  @callback on_event(type :: String.t(), payload :: json, Socket.t()) :: {:noreply, Socket.t()}
  @callback on_focus(Socket.t()) :: {:noreply, Socket.t()}
  @callback on_blur(Socket.t()) :: {:noreply, Socket.t()}
  @callback on_keydown(key :: String.t(), Socket.t()) :: {:noreply, Socket.t()}
  @callback on_keyup(key :: String.t(), Socket.t()) :: {:noreply, Socket.t()}
  @callback on_paste(String.t(), Socket.t()) :: {:noreply, Socket.t()}
end
