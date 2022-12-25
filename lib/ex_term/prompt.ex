defmodule ExTerm.Prompt do
  @moduledoc false

  # contains stateful information about the prompt.
  defstruct [
    :reply,
    :location,
    cursor_offset: 0,
    precursor: [],
    postcursor: [],
    entry_buffer: :queue.new(),
    trailing_blanks: 0
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
        prompt
      else
        new_entry_buffer =
          prompt
          |> to_binary
          |> :queue.in(prompt.entry_buffer)

        %{prompt | entry_buffer: new_entry_buffer}
      end

    reset(new_prompt)
  end

  def backspace(prompt = %{precursor: []}), do: prompt

  def backspace(prompt) do
    pad_blank(%{
      prompt
      | cursor_offset: prompt.cursor_offset - 1,
        precursor: tl(prompt.precursor),
        postcursor: [prompt.postcursor]
    })
  end

  def delete(prompt = %{postcursor: []}), do: prompt

  def delete(prompt) do
    pad_blank(%{prompt | postcursor: tl(prompt.postcursor)})
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
    content = to_binary(prompt, List.duplicate(" ", prompt.trailing_blanks))
    function.(prompt.location, content, prompt.cursor_offset)
    :ok
  end

  def active?(prompt), do: !!prompt.reply

  defp to_binary(prompt, padding \\ []) do
    prompt.precursor
    |> Enum.reverse([prompt.postcursor | padding])
    |> IO.iodata_to_binary()
  end

  defp pad_blank(prompt) do
    %{prompt | trailing_blanks: prompt.trailing_blanks + 1}
  end

  defp reset(prompt) do
    %{prompt | cursor_offset: 0, precursor: [], postcursor: [], reply: nil, trailing_blanks: 0}
  end
end
