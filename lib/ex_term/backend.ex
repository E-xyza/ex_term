defmodule ExTerm.Backend do
  @moduledoc """
  This behaviour defines the contract that an ExTerm backend must implement to
  respond to inbound user events.
  """

  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket

  @type json :: String.t() | nil | boolean | number | [json] | %{optional(String.t()) => json}
  @type params :: %{optional(String.t()) => term}
  @type session :: %{optional(String.t()) => term}

  @doc """
  forwarded from the `c:Phoenix.LiveView.mount/3` callback, but only on the
  second pass when the socket connects.

  An ExTerm terminal does not display any data until the websocket connection
  has been established.
  """
  @callback on_connect(params, session, LiveView.socket()) :: {:ok, Console.t(), Socket.t()}

  @doc """
  forwarded from the `c:Phoenix.LiveView.handle_event/3` callback.

  This callback is only invoked for events that aren't handled by the other
  callbacks.

  > ### Note {: .info}
  >
  > This callback should not be implemented unless customizing the terminal in
  > ways that are not currently supported; this is a future placeholder.
  """
  @callback on_event(type :: String.t(), payload :: json, Socket.t()) :: {:noreply, Socket.t()}

  @doc """
  triggered when the terminal gets focus.
  """
  @callback on_focus(Socket.t()) :: {:noreply, Socket.t()}

  @doc """
  triggered when the terminal loses focus.
  """
  @callback on_blur(Socket.t()) :: {:noreply, Socket.t()}

  @doc """
  triggered when the user presses on a key when the terminal has focus.

  see also https://developer.mozilla.org/en-US/docs/Web/API/Element/keydown_event
  the key string is corresponds to the `KeyboardEvent.key` field.

  for documentation on non-character `key` strings that can be passed to the
  callback, see:
  https://developer.mozilla.org/en-US/docs/Web/API/UI_Events/Keyboard_event_key_values

  Aside from capitalization of standard characters, it's the backend's
  responsibility to track modifier keys, for example "Control"
  """
  @callback on_keydown(key :: String.t(), Socket.t()) :: {:noreply, Socket.t()}

  @doc """
  triggered when the user lets go of a key when the terminal has focus.

  see also https://developer.mozilla.org/en-US/docs/Web/API/Element/keyup_event
  the key string is corresponds to the `KeyboardEvent.key` field.

  for documentation on non-character `key` strings that can be passed to the
  callback, see:
  https://developer.mozilla.org/en-US/docs/Web/API/UI_Events/Keyboard_event_key_values

  Aside from capitalization of standard characters, it's the backend's
  responsibility to track modifier keys, for example "Control"
  """
  @callback on_keyup(key :: String.t(), Socket.t()) :: {:noreply, Socket.t()}

  @doc """
  triggered when the user pastes content into the terminal.
  """
  @callback on_paste(String.t(), Socket.t()) :: {:noreply, Socket.t()}

  @optional_callbacks [on_event: 3]
end
