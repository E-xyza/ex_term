defmodule ExTermWeb.ConnCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  defmacro __using__(_) do
    quote do
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest

      alias Plug.Conn
      alias ExTermWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint ExTermWeb.Endpoint

      setup do
        {:ok, conn: build_conn()}
      end
    end
  end
end
