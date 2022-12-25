defmodule ExTermTest.PromptTest do
  use ExUnit.Case, async: true

  alias ExTerm.Prompt

  describe "when a reply is not active" do
    test "adding a keystrokes put them in the key buffer, in reverse order" do
      assert %{precursor: ["a"], cursor_offset: 1} = Prompt.push_key(%Prompt{}, "a")

      assert %{precursor: ~w(b a), cursor_offset: 2} =
               %Prompt{}
               |> Prompt.push_key("a")
               |> Prompt.push_key("b")
    end

    test "hitting enter puts whatever is in the key buffer into the entry_buffer" do
      assert %{precursor: ~w(f e), entry_buffer: buffer, cursor_offset: 2} =
               %Prompt{}
               |> Prompt.push_key("a")
               |> Prompt.push_key("b")
               |> Prompt.submit()
               |> Prompt.push_key("c")
               |> Prompt.push_key("d")
               |> Prompt.submit()
               |> Prompt.push_key("e")
               |> Prompt.push_key("f")

      assert ["ab", "cd"] = :queue.to_list(buffer)
    end

    test "hitting backspace reverses deletes from the end" do
      assert %{precursor: ["a"], cursor_offset: 1} =
               Prompt.backspace(%Prompt{precursor: ["b", "a"], postcursor: [], cursor_offset: 2})
    end

    test "hitting left moves the stuff to the left, unless at end" do
      middle =
        assert %{precursor: ["a"], postcursor: ["b"], cursor_offset: 1} =
                 Prompt.left(%Prompt{precursor: ["b", "a"], postcursor: [], cursor_offset: 2})

      left =
        assert %{precursor: [], postcursor: ["a", "b"], cursor_offset: 0} = Prompt.left(middle)

      assert left == Prompt.left(left)
    end

    test "hitting right moves the stuff to the right, unless at end" do
      middle =
        assert %{precursor: ["a"], postcursor: ["b"], cursor_offset: 1} =
                 Prompt.right(%Prompt{precursor: [], postcursor: ["a", "b"], cursor_offset: 0})

      right =
        assert %{precursor: ["b", "a"], postcursor: [], cursor_offset: 2} = Prompt.right(middle)

      assert right == Prompt.right(right)
    end
  end

  describe "when a reply is active" do
    defp do_send({ref, pid}, binary) do
      send(pid, {:ok, ref, binary})
    end

    test "hitting enter triggers a send via the send function" do
      ref = make_ref()

      assert %{precursor: [], postcursor: [], reply: nil} =
               Prompt.submit(%Prompt{
                 reply: {ref, self()},
                 precursor: ["a"],
                 postcursor: ["b"]
               }, &do_send/2)

      assert_receive {:ok, ^ref, "ab"}
    end
  end
end
