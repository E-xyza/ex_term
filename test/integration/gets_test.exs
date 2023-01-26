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

  describe "when io is gotten" do
    test "you get a prompt and it moves the cursor, and gets the result", %{conn: conn} do
      test_pid = self()

      Mox.expect(ExTermTest.TerminalMock, :run, fn group_leader ->
        Console.sync(test_pid, {:group_leader, group_leader})
        result = IO.gets("p")
        Console.sync(test_pid, {:result, result})
        Console.hibernate()
      end)

      {:ok, view, _html} = live(conn, "/test")

      Console.unblock(fn {:group_leader, pid} ->
        topic = ExTerm.IexBackend.IOServer.pubsub_topic(pid)
        PubSub.subscribe(ExTerm.PubSub, topic)
      end)

      # get pushed past the prompt "p"
      assert_receive(%Update{cursor: {1, 2}})

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

#    test "it is possible to queue up content", %{conn: conn} do
#      {:ok, view, _html} = live(conn, "/")
#      relay_pid = Relay.pid()
#
#      push_key(view, "a")
#      push_key(view, "Enter")
#      push_key(view, "b")
#      push_key(view, "Enter")
#
#      assert "a" = IO.gets(relay_pid, "prompt")
#      assert "b" = IO.gets(relay_pid, "prompt")
#    end
#
#    test "backspace key can delete content out of the active buffer", %{conn: conn} do
#      {:ok, view, _html} = live(conn, "/")
#      relay_pid = Relay.pid()
#
#      future =
#        Task.async(fn ->
#          IO.gets(relay_pid, "prompt")
#        end)
#
#      push_key(view, "a")
#      doc = push_key(view, "Backspace")
#      refute "a" == FlokiTools.char_at(doc, 1, 7)
#      assert {1, 7} = FlokiTools.cursor_location(doc)
#
#      doc = push_key(view, "Enter")
#      assert "" = Task.await(future)
#      assert {2, 1} = FlokiTools.cursor_location(doc)
#    end
  end
end
