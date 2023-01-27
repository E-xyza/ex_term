defmodule ExTerm.Router do
  @moduledoc """
  Plug that marshals ExTerm options to be put in the session store.

  by placing options in the session, it's possible for the initial html render
  and the socket-connected liveview to share common parameters.

  This module also provides the helper function `live_term/3` which wraps
  calling the plug (with options) and calling the `Phoenix.LiveView.Router.live/4`
  macro into one directive.
  """

  @behaviour Plug

  alias ExTerm.CSS
  require CSS

  @css_builtins CSS.builtins()

  @doc false
  def init([module | opts]) do
    new_opts =
      Keyword.update(opts, :css, :default, fn
        key when key in @css_builtins ->
          key

        result = {:css, {:priv, app, file_path}} ->
          css_content =
            app
            |> :code.priv_dir()
            |> Path.join(file_path)
            |> File.read!()

          old_content_map = Application.get_env(:ex_term, app, [])

          Application.put_env(:ex_term, app, [{file_path, css_content} | old_content_map],
            persistent: true
          )

          result

        other ->
          raise "unsupported CSS option #{inspect(other)}, must be a default atom (one of #{inspect(@css_builtins)}) or `{:priv, app, path}`"
      end)

    [module | new_opts]
  end

  @doc false
  def call(conn, [module | opts]) do
    Plug.Conn.put_session(conn, "exterm-backend", {module, opts})
  end

  @doc """
  creates an ExTerm live terminal route, inside of a Phoenix Router

  You must supply a path, and optionally a backend module.

  ### Basic Usage

  The following code creates a router with the default `ExTerm.TerminalBackend`
  backend:

  ```elixir
  defmodule MyAppWeb.Router do
    use MyAppWeb, :router
    import ExTerm.Router

    pipeline :browser do
      plug :accepts, ["html"]
      plug :fetch_session
      plug :fetch_live_flash
      plug :put_root_layout, {MyAppWeb.LayoutView, :root}
      plug :protect_from_forgery
      plug :put_secure_browser_headers
    end

    import ExTerm.Router

    scope "/live_term" do
      pipe_through :browser

      live_term "/terminal", pubsub_server: MyAppWeb.PubSub
    end
  end
  ```

  ### Alternative backends

  If you would like to specify an alternative backend, you may provide this as a
  second parameter, which must be a module.

  > #### Other backends {: .info}
  >
  > There are currently no other backends shipped with `:ex_term` but backends
  > to interface with other CLIs may be forthcoming.

  ```elixir
  scope "/live_term", MyBackend, pubsub_server: MyAppWeb.PubSub
  ```

  ### Options

  #### Required options

  - `:pubsub_server` A `Phoenix.Pubsub` server that will be used for Terminal backends to
    communicate back to the LiveView.

  #### Optional options

  - `:layout` A twople of postive integers which specify the dimensions of the
    viewable console space.
  - `:css` may be an atom or `{:priv, app, file_path}`.
    - if an atom, may be `:default` or `:bw`, which are the builtin css files.
    - if a `:priv` tuple, at compile-time it will search the priv directory of
      the supplied application at the specified `file_path` to obtain the css
      file.

  For documentation for backend-specific options, see `ExTerm.TerminalBackend`
  """
  defmacro live_term(route, module_or_opts, opts \\ [])

  defmacro live_term(route, module, opts) when is_atom(module) do
    id = :erlang.phash2(Map.take(__CALLER__, [:file, :line]))
    pipeline_name = :"exterm-pipeline-#{id}"

    quote do
      pipeline unquote(pipeline_name) do
        plug ExTerm.Router, [unquote(module) | unquote(opts)]
      end

      pipe_through unquote(pipeline_name)

      live unquote(route), ExTerm
    end
  end

  defmacro live_term(route, opts, []) when is_list(opts) do
    id = :erlang.phash2(Map.take(__CALLER__, [:file, :line]))
    pipeline_name = :"exterm-pipeline-#{id}"

    quote do
      pipeline unquote(pipeline_name) do
        plug ExTerm.Router, [ExTerm.TerminalBackend | unquote(opts)]
      end

      pipe_through unquote(pipeline_name)

      live unquote(route), ExTerm
    end
  end
end
