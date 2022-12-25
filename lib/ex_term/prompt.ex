defmodule ExTerm.Prompt do
  @moduledoc false

  # contains stateful information about the prompt.
  defstruct [
    :reply,
    :location,
    cursor_offset: 0,
    precursor: [],
    postcursor: [],
    entry_buffer: :queue.new()
  ]

  @type reply :: {reference, pid}
  @type location :: {row :: pos_integer, column :: pos_integer}

  @type t :: %__MODULE__{
          reply: nil | reply,
          location: nil | location,
          cursor_offset: non_neg_integer,
          precursor: [String.t()],
          postcursor: [String.t()],
          entry_buffer: :queue.queue(String.t())
        }

  def push_key(prompt = %{precursor: precursor, cursor_offset: cursor_offset}, key) do
    %{prompt | precursor: [key | precursor], cursor_offset: cursor_offset + 1}
  end

  @spec activate(t, reply, location) :: {nil | String.t(), t}
  def activate(prompt = %{entry_buffer: entry_buffer}, reply, location) do
    case :queue.out(entry_buffer) do
      {:empty, _buffer} ->
        {nil, %{prompt | cursor_offset: 0, reply: reply, location: location}}

      {{:value, entry}, new_buffer} ->
        offset = String.length(entry)
        {entry, %{prompt | entry_buffer: new_buffer, cursor_offset: offset, location: location}}
    end
  end

  @spec submit(t, replyfn :: (reply, String.t() -> any)) :: t
  def submit(prompt, replyfn) do
    new_prompt =
      if reply = prompt.reply do
        replyfn.(reply, to_binary(prompt))
        %{prompt | reply: nil}
      else
        new_entry_buffer =
          prompt
          |> to_binary
          |> :queue.in(prompt.entry_buffer)

        %{prompt | entry_buffer: new_entry_buffer}
      end

    # clear all bits of the prompt
    %{new_prompt | cursor_offset: 0, precursor: [], postcursor: [], reply: nil}
  end

  def backspace(prompt) do
    %{prompt | cursor_offset: prompt.cursor_offset - 1, precursor: tl(prompt.precursor)}
  end

  def left(prompt) do
    case prompt.precursor do
      [] ->
        prompt

      precursor ->
        %{
          prompt
          | cursor_offset: prompt.cursor_offset - 1,
            precursor: tl(precursor),
            postcursor: [hd(precursor) | prompt.postcursor]
        }
    end
  end

  def right(prompt) do
    case prompt.postcursor do
      [] ->
        prompt

      postcursor ->
        %{
          prompt
          | cursor_offset: prompt.cursor_offset + 1,
            postcursor: tl(postcursor),
            precursor: [hd(postcursor) | prompt.precursor]
        }
    end
  end

  @type painter ::
          (start_location :: location, String.t(), cursor_offset :: non_neg_integer -> any)
  @spec paint(t, painter) :: :ok
  def paint(prompt, function) do
    function.(prompt.location, to_binary(prompt), prompt.cursor_offset)
    :ok
  end

  def active?(prompt), do: !!prompt.reply

  defp to_binary(prompt) do
    prompt.precursor
    |> Enum.reverse(prompt.postcursor)
    |> IO.iodata_to_binary()
  end
end
