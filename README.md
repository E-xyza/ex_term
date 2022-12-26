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
    {:ex_term, "~> 0.1"}
    # ...
  ]
end
```

2. Connect the ex_term CSS:
  - if you're using a css bundler, add to your "app.css" (or other css file in your assets directory)
    ```
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
    ```
    <.live_component module={ExTerm}/>
    ```

## Documentation

Documentation is available on hexdocs.pm: https://hexdocs.pm/ex_term

### Not implemented yet (soon):
- up arrow (history)
- tab completion
- copy/paste

### Planned (Pro?) features:
- provenance tracking
- multiplayer mode
