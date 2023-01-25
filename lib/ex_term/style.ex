defmodule ExTerm.Style do
  @moduledoc false
  defstruct [
    :color,
    :"background-color",
    :blink,
    :frame,
    :intensity,
    :"white-space",
    :"overflow-anchor",
    conceal: false,
    italic: false,
    underline: false,
    crossed_out: false,
    overlined: false
  ]

  colors = ~w(black red green yellow blue magenta cyan white)a
  light_colors = Enum.map(colors, &:"light-#{&1}")

  quoted_color_type =
    Enum.reduce(
      colors ++ light_colors,
      &quote do
        unquote(&1) | unquote(&2)
      end
    )

  @type color :: unquote(quoted_color_type)
  @type t :: %__MODULE__{
          color: nil | color | String.t(),
          "background-color": nil | color | String.t(),
          blink: nil | :rapid | :slow,
          intensity: nil | :bright | :faint,
          frame: nil | :framed | :encircled,
          conceal: boolean,
          italic: boolean,
          underline: boolean,
          crossed_out: boolean,
          overlined: boolean,
          "white-space": nil | :pre,
          "overflow-anchor": nil | :auto
        }

  def new, do: %__MODULE__{}

  @spec from_ansi(t, String.t()) :: {t, String.t()} | :not_style
  def from_ansi(style \\ %__MODULE__{}, string)

  @named_colors ~w(black red green yellow blue magenta cyan white)a
  for color <- @named_colors do
    foreground_control = apply(IO.ANSI, color, [])

    def from_ansi(style, unquote(foreground_control) <> rest) do
      {%{style | color: unquote(color)}, rest}
    end

    background_control = apply(IO.ANSI, :"#{color}_background", [])

    def from_ansi(style, unquote(background_control) <> rest) do
      {%{style | "background-color": unquote(color)}, rest}
    end

    light_color = :"light-#{color}"

    light_foreground_control = apply(IO.ANSI, :"light_#{color}", [])

    def from_ansi(style, unquote(light_foreground_control) <> rest) do
      {%{style | color: unquote(light_color)}, rest}
    end

    light_background_control = apply(IO.ANSI, :"light_#{color}_background", [])

    def from_ansi(style, unquote(light_background_control) <> rest) do
      {%{style | "background-color": unquote(light_color)}, rest}
    end
  end

  for attribute <- ~w(italic underline conceal crossed_out overlined)a do
    attribute_control = apply(IO.ANSI, attribute, [])

    def from_ansi(style, unquote(attribute_control) <> rest) do
      {%{style | unquote(attribute) => true}, rest}
    end
  end

  for {attribute, clear} <- %{
        italic: :not_italic,
        underline: :no_underline,
        overlined: :not_overlined
      } do
    clear_control = apply(IO.ANSI, clear, [])

    def from_ansi(style, unquote(clear_control) <> rest) do
      {%{style | unquote(attribute) => false}, rest}
    end
  end

  for intensity <- [:bright, :faint] do
    intensity_control = apply(IO.ANSI, intensity, [])

    def from_ansi(style, unquote(intensity_control) <> rest) do
      {%{style | intensity: unquote(intensity)}, rest}
    end
  end

  for blink_speed <- [:slow, :rapid] do
    blink_control = apply(IO.ANSI, :"blink_#{blink_speed}", [])

    def from_ansi(style, unquote(blink_control) <> rest) do
      {%{style | blink: unquote(blink_speed)}, rest}
    end
  end

  blink_clear = IO.ANSI.blink_off()

  def from_ansi(style, unquote(blink_clear) <> rest) do
    {%{style | blink: nil}, rest}
  end

  for frame_type <- [:framed, :encircled] do
    frame_control = apply(IO.ANSI, frame_type, [])

    def from_ansi(style, unquote(frame_control) <> rest) do
      {%{style | frame: unquote(frame_type)}, rest}
    end
  end

  for {field, function} <- %{
        frame: :not_framed_encircled,
        color: :default_color,
        "background-color": :default_background
      } do
    clear = apply(IO.ANSI, function, [])

    def from_ansi(style, unquote(clear) <> rest) do
      {%{style | unquote(field) => nil}, rest}
    end
  end

  @reset IO.ANSI.reset()

  def from_ansi(_style, @reset <> rest) do
    {%__MODULE__{}, rest}
  end

  def from_ansi(style, "\e[38;5;" <> rest) do
    case Integer.parse(rest) do
      {color, "m" <> new_rest} when color in 16..255 ->
        {%{style | color: get_color(color)}, new_rest}

      _ ->
        :not_style
    end
  end

  def from_ansi(style, "\e[48;5;" <> rest) do
    case Integer.parse(rest) do
      {color, "m" <> new_rest} when color in 16..255 ->
        {%{style | "background-color": get_color(color)}, new_rest}

      _ ->
        :not_style
    end
  end

  def from_ansi(_style, _rest), do: :not_style

  @keys ~w(color bgcolor blink intensity frame conceal italic underline crossed_out overlined white-space overflow-anchor)a

  defp get_color(integer) do
    base = integer - 16
    r = base |> div(36) |> Kernel.*(3) |> Integer.to_string(16)
    gb = rem(base, 36)
    g = gb |> div(6) |> Kernel.*(3) |> Integer.to_string(16)
    b = gb |> rem(6) |> Kernel.*(3) |> Integer.to_string(16)
    "##{r}#{g}#{b}"
  end

  def to_iodata(style) do
    Enum.flat_map(@keys, &kv_to_css(&1, Map.get(style, &1)))
  end

  # colors are remappable so we have to use root variables
  @colors ~w(color background-color)a
  defp kv_to_css(key, value) when key in @colors do
    case value do
      _ when is_atom(value) ->
        [to_string(key), ":var(--exterm-", to_string(value), ");"]

      _ when is_binary(value) ->
        [to_string(key), "#{value};"]
    end
  end

  # other types might be directly encodable in the Style struct.
  @other ~w(white-space overflow-anchor)a
  defp kv_to_css(key, value) when key in @other do
    List.wrap(if value, do: [[to_string(key), ":", to_string(value), ";"]])
  end

  defp kv_to_css(_key, _value), do: []

  def from_css(css) do
    css
    |> String.split(";", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reduce(%__MODULE__{}, &style_prop_from_string/2)
  end

  @color_map %{?0 => 0x0, ?3 => 0x3, ?6 => 0x6, ?9 => 0x9, ?b => 0xB, ?f => 0xF}
  @color_chars Map.keys(@color_map)
  defguardp is_color(x) when x in @color_chars

  def style_prop_from_string(prop, style) do
    case String.split(prop, ":") do
      ["color", "var(" <> color_str] ->
        color =
          color_str
          |> String.replace_suffix(")", "")
          |> color_from_prop

        %{style | color: color}

      ["color", str = <<"#", a, b, c>>] when is_color(a) and is_color(b) and is_color(c) ->
        str
    end
  end

  @color_mapping Map.new(@named_colors, fn color -> {"#{color}", color} end)
  @named_color_strings Map.keys(@color_mapping)
  defp color_from_prop(color) when color in @named_color_strings do
    @color_mapping[color]
  end
end

defimpl Phoenix.HTML.Safe, for: ExTerm.Style do
  defdelegate to_iodata(css), to: ExTerm.Style
end

defimpl Inspect, for: ExTerm.Style do
  import Inspect.Algebra

  def inspect(style, _opts) do
    style_iodata = ExTerm.Style.to_iodata(style)
    concat(["ExTerm.Style.from_css(", "\"#{style_iodata}\"", ")"])
  end
end
