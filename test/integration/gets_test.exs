defmodule ExTermTest.GetsTest do
  use ExUnit.Case, async: true
  use ExTermWeb.ConnCase

  alias ExTerm.Console.Update

  alias ExTermTest.FlokiTools
  alias ExTermTest.Console

  alias Phoenix.PubSub

  import Phoenix.LiveViewTest

  defp push_key(view, key) do
    view
    |> element("#exterm-terminal")
    |> render_keydown(%{"key" => key})
  end

  defp basic_prompt(conn) do
    test_pid = self()

    Mox.expect(ExTermTest.TerminalMock, :run, fn group_leader ->
      Console.sync(test_pid, {:group_leader, group_leader})
      result = IO.gets("p")
      Console.sync(test_pid, {:result, result})
      Console.hibernate()
    end)

    {:ok, view, _html} = live(conn, "/test")

    Console.unblock(fn {:group_leader, pid} ->
      topic = ExTerm.TerminalBackend.IOServer.pubsub_topic(pid)
      PubSub.subscribe(ExTerm.PubSub, topic)
    end)

    # get pushed past the prompt "p"
    assert_receive(%Update{cursor: {1, 2}})

    view
  end

  describe "when io is gotten" do
    test "you get a prompt and it moves the cursor, and gets the result", %{conn: conn} do
      view = basic_prompt(conn)

      push_key(view, "a")

      assert_receive(%Update{cursor: {1, 3}})

      push_key(view, "Enter")

      assert_receive(%Update{cursor: {2, 1}})

      doc = render(view)

      assert {2, 1} = FlokiTools.cursor_location(doc)
      assert "pa" = FlokiTools.to_text(doc)

      Console.unblock(fn {:result, result} ->
        assert "a\n" == result
      end)
    end

    test "it is possible to queue up content", %{conn: conn} do
      test_pid = self()

      Mox.expect(ExTermTest.TerminalMock, :run, fn group_leader ->
        Console.sync(test_pid, {:group_leader, group_leader})
        result = IO.gets("p")
        Console.sync(test_pid, {:result, result})
        result = IO.gets("p")
        Console.sync(test_pid, {:result, result})
        Console.hibernate()
      end)

      {:ok, view, _html} = live(conn, "/test")

      Console.unblock(fn {:group_leader, pid} ->
        topic = ExTerm.TerminalBackend.IOServer.pubsub_topic(pid)
        PubSub.subscribe(ExTerm.PubSub, topic)

        # run this stuff before we run "io.gets"

        push_key(view, "a")
        push_key(view, "Enter")
        push_key(view, "b")
        push_key(view, "Enter")
      end)

      # get pushed past the prompt "p"
      assert_receive(%Update{cursor: {1, 2}})
      assert_receive(%Update{cursor: {1, 3}})
      assert_receive(%Update{cursor: {2, 1}})

      Console.unblock(fn {:result, result} ->
        assert "a\n" == result
      end)

      assert_receive(%Update{cursor: {2, 2}})
      assert_receive(%Update{cursor: {2, 3}})
      assert_receive(%Update{cursor: {3, 1}})

      Console.unblock(fn {:result, result} ->
        assert "b\n" == result
      end)

      doc = render(view)

      assert {3, 1} = FlokiTools.cursor_location(doc)
      assert "pa\npb" = FlokiTools.to_text(doc)
    end

    test "left arrow", %{conn: conn} do
      view = basic_prompt(conn)

      push_key(view, "a")

      assert_receive(%Update{cursor: {1, 3}})

      push_key(view, "ArrowLeft")

      assert_receive(%Update{cursor: {1, 2}})

      push_key(view, "b")
      push_key(view, "Enter")

      Console.unblock(fn {:result, result} ->
        assert "ba\n" == result
      end)

      doc = render(view)

      assert {2, 1} = FlokiTools.cursor_location(doc)
      assert "pba" = FlokiTools.to_text(doc)
    end

    test "right arrow", %{conn: conn} do
      view = basic_prompt(conn)

      push_key(view, "a")

      assert_receive(%Update{cursor: {1, 3}})

      push_key(view, "ArrowLeft")

      assert_receive(%Update{cursor: {1, 2}})

      push_key(view, "ArrowRight")

      assert_receive(%Update{cursor: {1, 3}})

      push_key(view, "b")
      push_key(view, "Enter")

      Console.unblock(fn {:result, result} ->
        assert "ab\n" == result
      end)

      doc = render(view)

      assert {2, 1} = FlokiTools.cursor_location(doc)
      assert "pab" = FlokiTools.to_text(doc)
    end

    test "backspace", %{conn: conn} do
      view = basic_prompt(conn)

      push_key(view, "a")

      assert_receive(%Update{cursor: {1, 3}})

      push_key(view, "Backspace")

      assert_receive(%Update{cursor: {1, 2}})

      push_key(view, "b")
      push_key(view, "Enter")

      Console.unblock(fn {:result, result} ->
        assert "b\n" == result
      end)

      doc = render(view)

      assert {2, 1} = FlokiTools.cursor_location(doc)
      assert "pb" = FlokiTools.to_text(doc)
    end

    test "delete", %{conn: conn} do
      view = basic_prompt(conn)

      push_key(view, "a")

      assert_receive(%Update{cursor: {1, 3}})

      push_key(view, "ArrowLeft")

      assert_receive(%Update{cursor: {1, 2}})

      push_key(view, "Delete")
      push_key(view, "b")

      assert_receive(%Update{cursor: {1, 3}})

      push_key(view, "Enter")

      Console.unblock(fn {:result, result} ->
        assert "b\n" == result
      end)

      doc = render(view)

      assert {2, 1} = FlokiTools.cursor_location(doc)
      assert "pb" = FlokiTools.to_text(doc)
    end
  end
end
