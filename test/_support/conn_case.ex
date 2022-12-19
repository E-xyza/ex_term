defmodule ExTermWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use ExTermWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

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
