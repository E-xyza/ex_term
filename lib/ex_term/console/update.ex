defmodule ExTerm.Console.Update do
  @moduledoc """
  struct describing console changes.  These updates will be broadcast to liveviews
  (or any other processes) that listen in console updates.

  Typically this update will be automatically issued by Console functions, but the
  struct is documented here so that receiving processes can be aware of what messages
  are coming in.
  """

  defstruct [:cursor, changes: []]

  @type row_end :: {pos_integer, :end}
  @type cell_range :: {Console.location(), Console.location() | row_end}
  @type end_range :: {Console.location(), :end}
  @type cell_change :: Console.location() | cell_range | end_range
  @type cell_changes :: [cell_change]

  alias ExTerm.Console

  @typedoc """
  ### fields

  - `cursor`:  nil if there is no change in the cursor location, new cursor
    `t:Console.location/0` otherwise.
  - `last_cell`: nil if there is no change in the last cell of the console, new
    last cell `t:Console.location/0` otherwise.
  - `cells`: A list of changes to the console data.  This is a list of one of
    the following types
    - single `t:Console.location/0`.  This indicates a single location has
      changed.
    - location range, represented by a `{begin, end}` twople of
      `t:Console.location/0`.  This indicates multiple consecutive locations
      have changed in the range between `begin` and `end` locations.  This is
      allowed to span multiple lines.
    - location range with end-of-line, represented by a twople of
      `t:Console.location/0` and `{row, :end}`.  This should be used in lieu of
      a single location if the location is the last character on the line, OR
      if a location range ends at last character on the line.
    - location range with end-of-console, reppresnted by a twople of
      `t:Console.location/0` and `:end`.
    Note that the `cells` *should* be in reverse-sorted order, and *should* be
    compacted.
  """

  @type t :: %__MODULE__{
          cursor: nil | Console.location(),
          changes: cell_changes
        }

  @doc false
  def init do
    if put_current_update(%__MODULE__{}) do
      raise "error: attempt to initialize console updates with an unflushed update"
    end
  end

  # public guards
  @doc """
  identifies if a term is a `t:Console.location/0`

  Optimized to distinguish between `t:Console.location/0`, `t:cell_range/0`, and `t:end_range/0`.
  May not correctly type other terms.

  ```elixir
  iex> alias ExTerm.Console.Update
  iex> Update.is_location({1, 2})
  true
  iex> Update.is_location({{1, 1}, {1, 2}})
  false
  iex> Update.is_location({{1, 1}, {1, :end}})
  false
  iex> Update.is_location({{1, 1}, :end})
  false
  ```
  """
  defguard is_location(item) when is_tuple(item) and is_integer(elem(item, 1))

  @doc """
  identifies if a term is a `t:cell_range/0`

  Optimized to distinguish between `t:Console.location/0`, `t:cell_range/0`, and `t:end_range/0`.

  May not correctly type other terms.

  ```elixir
  iex> alias ExTerm.Console.Update
  iex> Update.is_range({1, 2})
  false
  iex> Update.is_range({{1, 1}, {1, 2}})
  true
  iex> Update.is_range({{1, 1}, {1, :end}})
  true
  iex> Update.is_range({{1, 1}, :end})
  false
  ```
  """
  defguard is_range(item) when is_tuple(elem(item, 1))

  @doc """
  identifies if a term is a `t:end_range/0`

  Optimized to distinguish between `t:Console.location/0`, `t:cell_range/0`, and `t:end_range/0`.

  May not correctly type other terms.

  ```elixir
  iex> alias ExTerm.Console.Update
  iex> Update.is_end_range({1, 2})
  false
  iex> Update.is_end_range({{1, 1}, {1, 2}})
  false
  iex> Update.is_end_range({{1, 1}, {1, :end}})
  false
  iex> Update.is_end_range({{1, 1}, :end})
  true
  ```
  """
  defguard is_end_range(item) when elem(item, 1) === :end

  # for internal use only.
  defguardp is_any_range(item) when is_tuple(elem(item, 0))
  defguardp row(location) when elem(location, 0)
  defguardp col(location) when elem(location, 1)

  @doc false
  @spec push_cells(Console.t, cell_change) :: :ok
  # note: this needs to be inside of a mutation transaction
  def push_cells(console, location) do
    # check to see if the column is at the end of its row, in which case, amend
    # it to be a "row/end", for the purposes of compaction.
    if is_location(location) and Console.last_column?(console, location) do
      push_cells(console, {location, {row(location), :end}})
    else
      update = get_current_update()
      put_current_update(%{update | changes: _push_change(update.changes, location)})
    end
    :ok
  end

  @spec change_cursor(Console.location) :: :ok
  def change_cursor(location) do
    get_current_update()
    |> Map.put(:cursor, location)
    |> put_current_update()
    :ok
  end

  @doc false
  # note this needs to be inside of an access transaction (but will almost always
  # be inside of a mutation transaction.
  def flush(console) do
    update = put_current_update(nil)

    unless update do
      raise "error: attempt to flush a nonexistent console update"
    end

    # be silent if no changes were made.
    unless update === %__MODULE__{cursor: nil, changes: []} do
      Console.update_with(console, update)
    end
    
    console
  end

  #############################################################################
  ## private helpers

  defguardp start(range) when elem(range, 0)
  defguardp finish(range) when elem(range, 1)

  defguardp is_in_end_range(subject, range)
            when is_end_range(range) and
                   ((is_location(subject) and subject >= start(range)) or
                      (is_any_range(subject) and start(subject) >= start(range)))

  defguardp is_in_range(subject, range)
            when is_range(range) and not is_end_range(subject) and
                   ((is_location(subject) and subject >= start(range) and
                       subject <= finish(range)) or
                      (start(subject) >= start(range) and finish(subject) <= finish(range)))

  @doc false
  defguard _is_in(subject, range)
           when is_in_end_range(subject, range) or is_in_range(subject, range)

  # NOTE THERE IS NO TYPE PROTECTION ON THIS FUNCTION
  defguardp is_next_line_cell(subject, compare)
            when col(compare) === :end and col(subject) === 1 and
                   row(subject) === row(compare) + 1

  # NOTE THERE IS NO TYPE PROTECTION ON THIS FUNCTION
  defguardp is_next_from(subject, compare)
            when row(subject) === row(compare) and col(subject) !== :end and
                   col(subject) === col(compare) + 1

  defguardp is_adjoining_after(subject, compare)
            when is_next_line_cell(subject, compare) or
                   (is_location(compare) and is_next_from(subject, compare))

  defguardp is_disjoint_greater_two_location(subject, compare)
            when not is_adjoining_after(subject, compare) and subject > compare

  defguardp is_disjoint_greater_subject_location(subject, compare)
            when (is_location(compare) and
                    is_disjoint_greater_two_location(subject, compare)) or
                   (is_range(compare) and
                      is_disjoint_greater_two_location(subject, finish(compare)))

  defguardp is_disjoint_greater_subject_range(subject, compare)
            when (is_location(compare) and
                    is_disjoint_greater_two_location(start(subject), compare)) or
                   (is_range(compare) and
                      is_disjoint_greater_two_location(start(subject), finish(compare)))

  @doc false
  defguard _is_disjoint_greater(subject, compare)
           when (is_location(subject) and is_disjoint_greater_subject_location(subject, compare)) or
                  (is_any_range(subject) and is_disjoint_greater_subject_range(subject, compare))

  @doc false
  defguard _location_precedes_location(first, second) when is_adjoining_after(second, first)

  @doc false
  defguard _location_precedes_range(first, second)
           when is_location(first) and is_any_range(second) and
                  is_adjoining_after(start(second), first)

  @doc false
  defguard _range_precedes_location(first, second)
           when is_range(first) and is_location(second) and
                  is_adjoining_after(second, finish(first))

  # specialized checks for range_precedes_range that handles end range cases.
  defguardp double_end_range(first, second)
            when is_end_range(first) and is_end_range(second) and start(first) < start(second)

  defguardp end_range_check(first, second)
            when is_end_range(second) or
                   (not is_end_range(first) and
                      (is_range(second) and finish(first) <= finish(second)))

  @doc false
  defguard _range_precedes_range(first, second)
           when double_end_range(first, second) or
                  (end_range_check(first, second) and
                     (finish(first) >= start(second) or
                        _location_precedes_location(finish(first), start(second))))

  @doc false
  @spec _push_change(cell_changes, cell_change, cell_changes) :: cell_changes

  def _push_change(changes, new_change, ignored \\ [])

  # NB this function is public so that it can be tested.
  def _push_change([], change, ignored), do: Enum.reverse(ignored, [change])

  def _push_change(list = [same | _], same, ignored), do: Enum.reverse(ignored, list)

  def _push_change(list = [head | _], change, ignored) when _is_disjoint_greater(change, head) do
    Enum.reverse(ignored, [change | list])
  end

  def _push_change(list = [head | _], change, ignored) when _is_in(change, head) do
    Enum.reverse(ignored, list)
  end

  def _push_change([head | rest], change, ignored) when _is_in(head, change) do
    _push_change(rest, change, ignored)
  end

  def _push_change([head | rest], change, ignored)
      when _location_precedes_location(change, head) do
    _push_change(rest, {change, head}, ignored)
  end

  def _push_change([head | rest], change, ignored)
      when _location_precedes_location(head, change) do
    Enum.reverse(ignored, [{head, change} | rest])
  end

  def _push_change([head | rest], change, ignored)
      when _location_precedes_range(change, head) do
    _push_change(rest, {change, finish(head)}, ignored)
  end

  def _push_change([head | rest], change, ignored)
      when _location_precedes_range(head, change) do
    Enum.reverse(ignored, [{head, finish(change)} | rest])
  end

  def _push_change([head | rest], change, ignored)
      when _range_precedes_location(change, head) do
    _push_change(rest, {start(change), head}, ignored)
  end

  def _push_change([head | rest], change, ignored)
      when _range_precedes_location(head, change) do
    Enum.reverse(ignored, [{start(head), change} | rest])
  end

  def _push_change([head | rest], change, ignored)
      when _range_precedes_range(change, head) do
    _push_change(rest, {start(change), finish(head)}, ignored)
  end

  def _push_change([head | rest], change, ignored)
      when _range_precedes_range(head, change) do
    Enum.reverse(ignored, [{start(head), finish(change)} | rest])
  end

  def _push_change([head | rest], change, ignored) do
    _push_change(rest, change, [head | ignored])
  end

  #############################################################################
  ## private utilities

  @update_process_key :exterm_console_updates

  @spec get_current_update() :: t
  defp get_current_update do
    update = Process.get(@update_process_key)

    unless update do
      raise "error: attempt to obtain a nonexistent console update"
    end

    update
  end

  @spec put_current_update(t | nil) :: t | nil
  defp put_current_update(update) do
    Process.put(@update_process_key, update)
  end
end
