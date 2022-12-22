defmodule ExTermTest.StyleTest do
  use ExUnit.Case, async: true

  alias ExTerm.Style

  describe "colors:" do
    colors = [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white]

    for color <- colors do
      foreground_text = apply(IO.ANSI, color, []) <> "text"

      test "assigns foreground #{color} correctly" do
        assert {%{color: unquote(color)}, "text"} = Style.from_ansi(unquote(foreground_text))
      end

      background_text = apply(IO.ANSI, :"#{color}_background", []) <> "text"

      test "assigns background #{color} correctly" do
        assert {%{bgcolor: unquote(color)}, "text"} = Style.from_ansi(unquote(background_text))
      end

      lt_color = :"light-#{color}"

      foreground_light_text = apply(IO.ANSI, :"light_#{color}", []) <> "text"

      test "assigns foreground light #{color} correctly" do
        assert {%{color: unquote(lt_color)}, "text"} =
                 Style.from_ansi(unquote(foreground_light_text))
      end

      background_light_text = apply(IO.ANSI, :"light_#{color}_background", []) <> "text"

      test "assigns background light #{color} correctly" do
        assert {%{bgcolor: unquote(lt_color)}, "text"} =
                 Style.from_ansi(unquote(background_light_text))
      end
    end
  end

  describe "text attributes:" do
    for attribute <- ~w(italic underline conceal crossed_out overlined)a do
      attribute_text = apply(IO.ANSI, attribute, []) <> "text"

      test "assigns #{attribute} correctly" do
        assert {%{unquote(attribute) => true}, "text"} = Style.from_ansi(unquote(attribute_text))
      end
    end

    for {attribute, clear} <- %{
          italic: :not_italic,
          underline: :no_underline,
          overlined: :not_overlined
        } do
      clear_text = apply(IO.ANSI, clear, []) <> "text"

      test "clears #{attribute} correctly" do
        empty_style = %Style{}

        assert {^empty_style, "text"} =
                 Style.from_ansi(%Style{unquote(attribute) => true}, unquote(clear_text))
      end
    end
  end

  describe "intensity:" do
    for intensity <- [:bright, :faint] do
      set_text = apply(IO.ANSI, intensity, []) <> "text"

      test "sets intensity #{intensity} correctly" do
        assert {%{intensity: unquote(intensity)}, "text"} = Style.from_ansi(unquote(set_text))
      end
    end
  end

  describe "blink:" do
    @clear_blink IO.ANSI.blink_off() <> "text"
    for blink_type <- [:slow, :rapid] do
      set_text = apply(IO.ANSI, :"blink_#{blink_type}", []) <> "text"

      test "sets blink #{blink_type} correctly" do
        assert {%{blink: unquote(blink_type)}, "text"} = Style.from_ansi(unquote(set_text))
      end

      test "clears blink #{blink_type} correctly" do
        empty_style = %Style{}

        assert {^empty_style, "text"} =
                 Style.from_ansi(%Style{blink: unquote(blink_type)}, @clear_blink)
      end
    end
  end

  describe "frames:" do
    @clear_frame IO.ANSI.not_framed_encircled() <> "text"
    for frame_type <- [:framed, :encircled] do
      set_text = apply(IO.ANSI, frame_type, []) <> "text"

      test "sets frame #{frame_type} correctly" do
        assert {%{frame: unquote(frame_type)}, "text"} = Style.from_ansi(unquote(set_text))
      end

      test "clears frame #{frame_type} correctly" do
        empty_css = %Style{}

        assert {^empty_css, "text"} =
                 Style.from_ansi(%Style{frame: unquote(frame_type)}, @clear_frame)
      end
    end
  end

  describe "defauts:" do
    @default_color IO.ANSI.default_color() <> "text"
    test "default color works" do
      empty_css = %Style{}
      assert {^empty_css, "text"} = Style.from_ansi(%Style{color: :blue}, @default_color)
    end

    @default_background IO.ANSI.default_background() <> "text"
    test "default background works" do
      empty_css = %Style{}
      assert {^empty_css, "text"} = Style.from_ansi(%Style{bgcolor: :blue}, @default_background)
    end

    @reset IO.ANSI.reset() <> "text"
    test "reset works" do
      empty_css = %Style{}
      assert {^empty_css, "text"} = Style.from_ansi(%Style{bgcolor: :blue}, @reset)
    end
  end
end
