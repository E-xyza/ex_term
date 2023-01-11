defmodule ExTerm.Backend do
  alias Phoenix.LiveView

  @type id :: term
  @type json :: boolean | nil | String.t() | number | [json] | %{optional(String.t()) => json}

  @type response :: :ok | Console.update()

  @callback mount(json, json, LiveView.socket()) :: {:ok, id, Console.t()}

  @callback handle_event(id, type :: String.t(), payload :: json) :: response
  @callback handle_focus(id) :: response
  @callback handle_blur(id) :: response
  @callback handle_keydown(id, key :: String.t()) :: response
  @callback handle_keyup(id, key :: String.t()) :: response
  @callback handle_paste(id, String.t()) :: response
  @callback handle_io_request(id, GenServer.from(), term) :: response
end
