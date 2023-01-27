import Config

config :phoenix, :json_library, Jason

# Configures the endpoint
config :ex_term, ExTermWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: ExTermWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub: ExTerm.PubSub,
  live_view: [signing_salt: "cEy4s8JU"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.29",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# note that this won't be set to be true when it's used as a library
config :ex_term, :check_transaction, true

import_config "#{config_env()}.exs"
