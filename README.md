# ExTerm

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
    {:ex_term, "~> 0.2"}
    # ...
  ]
end
```

1. Create a live view in your routes
  - as a standalone liveview

    ```elixir
    import ExTerm.Router

    scope "/" do
      pipe_through :browser
  
      live_term "/", pubsub_server: MyAppWeb.PubSub
    end
    ```

## Documentation

Documentation is available on hexdocs.pm: https://hexdocs.pm/ex_term

### Planned (Pro?) features:
- provenance tracking
- multiplayer mode
