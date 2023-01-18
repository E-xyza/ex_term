defmodule ExTermTest.Console.UpdateTest do
  use ExUnit.Case, async: true

  doctest ExTerm.Console.Update

  import ExTerm.Console.Update,
    only: [
      _is_in: 2,
      _is_disjoint_greater: 2,
      _location_precedes_location: 2,
      _location_precedes_range: 2,
      _range_precedes_location: 2,
      _range_precedes_range: 2,
      register_cell_change: 2
    ]

  describe "the _is_in function" do
    test "correctly identifies when a location is in a range" do
      assert _is_in({1, 1}, {{1, 1}, {1, 3}})
      assert _is_in({1, 1}, {{1, 1}, {1, 3}})
      assert _is_in({1, 2}, {{1, 1}, {1, 3}})
      assert _is_in({1, 2}, {{1, 1}, {1, :end}})
      assert _is_in({1, 3}, {{1, 1}, {1, 3}})
      assert _is_in({1, 3}, {{1, 1}, {1, 3}})
      refute _is_in({1, 1}, {{1, 2}, {1, 3}})
      refute _is_in({1, 1}, {{1, 2}, {1, :end}})
      refute _is_in({1, 4}, {{1, 2}, {1, 3}})
      refute _is_in({2, 1}, {{1, 2}, {1, 3}})
      refute _is_in({2, 1}, {{1, 2}, {1, :end}})
    end

    test "correctly identifies when a location is in an end range" do
      assert _is_in({1, 3}, {{1, 1}, :end})
      assert _is_in({2, 3}, {{1, 1}, :end})
      refute _is_in({1, 1}, {{1, 2}, :end})
    end

    test "correctly identifies when a range is in a range" do
      assert _is_in({{1, 1}, {1, 3}}, {{1, 1}, {1, 3}})
      assert _is_in({{1, 1}, {1, 2}}, {{1, 1}, {1, 3}})
      assert _is_in({{1, 2}, {1, 3}}, {{1, 1}, {1, 3}})
      assert _is_in({{1, 1}, {1, 3}}, {{1, 1}, {1, :end}})
      assert _is_in({{1, 2}, {1, 3}}, {{1, 1}, {1, :end}})
      # disjoint, before
      refute _is_in({{1, 1}, {1, 2}}, {{1, 3}, {1, 4}})
      # overlapping, before
      refute _is_in({{1, 1}, {1, 3}}, {{1, 3}, {1, 4}})
      refute _is_in({{1, 1}, {1, :end}}, {{1, 3}, {2, 4}})
      # superset
      refute _is_in({{1, 1}, {1, 5}}, {{1, 3}, {1, 4}})
      refute _is_in({{1, 1}, {1, :end}}, {{1, 3}, {1, 4}})
      # overlapping, after
      refute _is_in({{1, 4}, {2, 1}}, {{1, 3}, {1, 4}})
      refute _is_in({{1, 4}, {2, 1}}, {{1, 3}, {1, :end}})
      # disjoint, after
      refute _is_in({{1, 5}, {1, 6}}, {{1, 3}, {1, 4}})
      refute _is_in({{2, 1}, {2, 2}}, {{1, 3}, {1, :end}})
    end

    test "correctly identifies when a range is in an end range" do
      # disjoint, before
      refute _is_in({{1, 1}, {1, 2}}, {{1, 3}, :end})
      # overlapping, before
      refute _is_in({{1, 1}, {1, 3}}, {{1, 3}, :end})
      refute _is_in({{1, 1}, {1, 4}}, {{1, 3}, :end})
      refute _is_in({{1, 1}, {1, :end}}, {{1, 3}, :end})
      # properly inside
      assert _is_in({{1, 3}, {1, 4}}, {{1, 3}, :end})
      assert _is_in({{1, 3}, {1, 4}}, {{1, 3}, :end})
      assert _is_in({{1, 3}, {1, 4}}, {{1, 3}, :end})
    end

    test "correctly identifies that an end range is not in a range" do
      refute _is_in({{1, 1}, :end}, {{1, 1}, {1, 2}})
      refute _is_in({{1, 1}, :end}, {{1, 1}, {1, :end}})
    end

    test "correctly identifies when an end range is in an end range" do
      refute _is_in({{1, 1}, :end}, {{2, 2}, :end})
      assert _is_in({{2, 2}, :end}, {{1, 1}, :end})
    end
  end

  describe "the _is_disjoint_greater/2 guard for locations" do
    test "correctly identifies disjoint locations" do
      refute _is_disjoint_greater({1, 1}, {1, 3})
      refute _is_disjoint_greater({1, 2}, {1, 3})
      refute _is_disjoint_greater({1, 3}, {1, 3})
      refute _is_disjoint_greater({1, 4}, {1, 3})
      assert _is_disjoint_greater({1, 5}, {1, 3})
    end

    test "correctly identifies disjoint locations compared to normal range" do
      refute _is_disjoint_greater({1, 1}, {{1, 3}, {1, 4}})
      refute _is_disjoint_greater({1, 2}, {{1, 3}, {1, 4}})
      refute _is_disjoint_greater({1, 3}, {{1, 3}, {1, 4}})
      refute _is_disjoint_greater({1, 4}, {{1, 3}, {1, 4}})
      refute _is_disjoint_greater({1, 5}, {{1, 3}, {1, 4}})
      assert _is_disjoint_greater({1, 6}, {{1, 3}, {1, 4}})
    end

    test "correctly identifies disjoint location compared to endline range" do
      refute _is_disjoint_greater({1, 1}, {{1, 3}, {1, :end}})
      refute _is_disjoint_greater({1, 2}, {{1, 3}, {1, :end}})
      refute _is_disjoint_greater({1, 3}, {{1, 3}, {1, :end}})
      refute _is_disjoint_greater({2, 1}, {{1, 3}, {1, :end}})
      assert _is_disjoint_greater({2, 2}, {{1, 3}, {1, :end}})
    end

    test "correctly identifies disjoint locations cannot be disjoint greater than an end range" do
      refute _is_disjoint_greater({1, 1}, {{1, 2}, :end})
      refute _is_disjoint_greater({1, 2}, {{1, 2}, :end})
      refute _is_disjoint_greater({1, 3}, {{1, 2}, :end})
      refute _is_disjoint_greater({2, 2}, {{1, 2}, :end})
    end
  end

  describe "the _is_disjoint_greater/2 guard for basic ranges" do
    test "correctly identifies disjoint locations" do
      refute _is_disjoint_greater({{1, 1}, {1, 2}}, {1, 4})
      refute _is_disjoint_greater({{1, 2}, {1, 3}}, {1, 4})
      refute _is_disjoint_greater({{1, 3}, {1, 4}}, {1, 4})
      refute _is_disjoint_greater({{1, 4}, {1, 5}}, {1, 4})
      refute _is_disjoint_greater({{1, 5}, {1, 6}}, {1, 4})
      assert _is_disjoint_greater({{1, 6}, {1, 7}}, {1, 4})
    end

    test "correctly identifies disjoint locations compared to normal range" do
      refute _is_disjoint_greater({{1, 1}, {1, 2}}, {{1, 4}, {1, 5}})
      refute _is_disjoint_greater({{1, 2}, {1, 3}}, {{1, 4}, {1, 5}})
      refute _is_disjoint_greater({{1, 3}, {1, 4}}, {{1, 4}, {1, 5}})
      refute _is_disjoint_greater({{1, 4}, {1, 5}}, {{1, 4}, {1, 5}})
      refute _is_disjoint_greater({{1, 5}, {1, 6}}, {{1, 4}, {1, 5}})
      refute _is_disjoint_greater({{1, 6}, {1, 7}}, {{1, 4}, {1, 5}})
      assert _is_disjoint_greater({{1, 7}, {1, 8}}, {{1, 4}, {1, 5}})
    end

    test "correctly identifies disjoint location compared to endline range" do
      refute _is_disjoint_greater({{1, 1}, {1, 2}}, {{1, 3}, {2, :end}})
      refute _is_disjoint_greater({{1, 2}, {1, 3}}, {{1, 3}, {2, :end}})
      refute _is_disjoint_greater({{1, 3}, {1, 4}}, {{1, 3}, {2, :end}})
      refute _is_disjoint_greater({{3, 1}, {3, 2}}, {{1, 3}, {2, :end}})
      assert _is_disjoint_greater({{3, 2}, {3, 3}}, {{1, 3}, {2, :end}})
    end

    test "correctly identifies disjoint locations cannot be disjoint greater than an end range" do
      refute _is_disjoint_greater({{1, 1}, {1, 2}}, {{1, 3}, :end})
      refute _is_disjoint_greater({{1, 2}, {1, 3}}, {{1, 3}, :end})
      refute _is_disjoint_greater({{1, 3}, {1, 4}}, {{1, 3}, :end})
      refute _is_disjoint_greater({{2, 2}, {2, 3}}, {{1, 3}, :end})
    end
  end

  describe "the _is_disjoint_greater/2 guard for endline ranges" do
    test "correctly identifies disjoint locations" do
      refute _is_disjoint_greater({{1, 1}, {1, :end}}, {1, 4})
      refute _is_disjoint_greater({{1, 2}, {1, :end}}, {1, 4})
      refute _is_disjoint_greater({{1, 3}, {1, :end}}, {1, 4})
      refute _is_disjoint_greater({{1, 4}, {1, :end}}, {1, 4})
      refute _is_disjoint_greater({{1, 5}, {1, :end}}, {1, 4})
      assert _is_disjoint_greater({{1, 6}, {1, :end}}, {1, 4})
    end

    test "correctly identifies disjoint locations compared to normal range" do
      refute _is_disjoint_greater({{1, 1}, {1, :end}}, {{1, 4}, {1, 5}})
      refute _is_disjoint_greater({{1, 2}, {1, :end}}, {{1, 4}, {1, 5}})
      refute _is_disjoint_greater({{1, 3}, {1, :end}}, {{1, 4}, {1, 5}})
      refute _is_disjoint_greater({{1, 4}, {1, :end}}, {{1, 4}, {1, 5}})
      refute _is_disjoint_greater({{1, 5}, {1, :end}}, {{1, 4}, {1, 5}})
      refute _is_disjoint_greater({{1, 6}, {1, :end}}, {{1, 4}, {1, 5}})
      assert _is_disjoint_greater({{1, 7}, {1, :end}}, {{1, 4}, {1, 5}})
    end

    test "correctly identifies disjoint location compared to endline range" do
      refute _is_disjoint_greater({{1, 1}, {1, :end}}, {{1, 3}, {2, :end}})
      refute _is_disjoint_greater({{1, 2}, {1, :end}}, {{1, 3}, {2, :end}})
      refute _is_disjoint_greater({{1, 3}, {1, :end}}, {{1, 3}, {2, :end}})
      refute _is_disjoint_greater({{3, 1}, {3, :end}}, {{1, 3}, {2, :end}})
      assert _is_disjoint_greater({{3, 2}, {3, :end}}, {{1, 3}, {2, :end}})
    end

    test "correctly identifies disjoint locations cannot be disjoint greater than an end range" do
      refute _is_disjoint_greater({{1, 1}, {1, :end}}, {{1, 3}, :end})
      refute _is_disjoint_greater({{1, 2}, {1, :end}}, {{1, 3}, :end})
      refute _is_disjoint_greater({{1, 3}, {1, :end}}, {{1, 3}, :end})
      refute _is_disjoint_greater({{2, 2}, {2, :end}}, {{1, 3}, :end})
    end
  end

  describe "the _is_disjoint_greater/2 guard for end ranges" do
    test "correctly identifies disjoint locations" do
      refute _is_disjoint_greater({{1, 1}, :end}, {1, 4})
      refute _is_disjoint_greater({{1, 2}, :end}, {1, 4})
      refute _is_disjoint_greater({{1, 3}, :end}, {1, 4})
      refute _is_disjoint_greater({{1, 4}, :end}, {1, 4})
      refute _is_disjoint_greater({{1, 5}, :end}, {1, 4})
      assert _is_disjoint_greater({{1, 6}, :end}, {1, 4})
    end

    test "correctly identifies disjoint locations compared to normal range" do
      refute _is_disjoint_greater({{1, 1}, :end}, {{1, 4}, {1, 5}})
      refute _is_disjoint_greater({{1, 2}, :end}, {{1, 4}, {1, 5}})
      refute _is_disjoint_greater({{1, 3}, :end}, {{1, 4}, {1, 5}})
      refute _is_disjoint_greater({{1, 4}, :end}, {{1, 4}, {1, 5}})
      refute _is_disjoint_greater({{1, 5}, :end}, {{1, 4}, {1, 5}})
      refute _is_disjoint_greater({{1, 6}, :end}, {{1, 4}, {1, 5}})
      assert _is_disjoint_greater({{1, 7}, :end}, {{1, 4}, {1, 5}})
    end

    test "correctly identifies disjoint location compared to endline range" do
      refute _is_disjoint_greater({{1, 1}, :end}, {{1, 3}, {2, :end}})
      refute _is_disjoint_greater({{1, 2}, :end}, {{1, 3}, {2, :end}})
      refute _is_disjoint_greater({{1, 3}, :end}, {{1, 3}, {2, :end}})
      refute _is_disjoint_greater({{3, 1}, :end}, {{1, 3}, {2, :end}})
      assert _is_disjoint_greater({{3, 2}, :end}, {{1, 3}, {2, :end}})
    end

    test "correctly identifies disjoint locations cannot be disjoint greater than an end range" do
      refute _is_disjoint_greater({{1, 1}, :end}, {{1, 3}, :end})
      refute _is_disjoint_greater({{1, 2}, :end}, {{1, 3}, :end})
      refute _is_disjoint_greater({{1, 3}, :end}, {{1, 3}, :end})
      refute _is_disjoint_greater({{2, 2}, :end}, {{1, 3}, :end})
    end
  end

  describe "the precede functions" do
    test "_location_precedes_location/2 identifies next-door locations" do
      assert _location_precedes_location({1, 1}, {1, 2})
      refute _location_precedes_location({1, 1}, {1, 3})
      refute _location_precedes_location({1, 1}, {2, 2})
      refute _location_precedes_location({1, 2}, {1, 1})
    end

    test "_location_precedes_range/2 identifies next-door locations" do
      assert _location_precedes_range({1, 1}, {{1, 2}, {2, 2}})
      assert _location_precedes_range({1, 1}, {{1, 2}, {2, :end}})
      refute _location_precedes_range({1, 1}, {{1, 3}, {2, 2}})
      refute _location_precedes_range({1, 1}, {{1, 3}, {2, :end}})
      refute _location_precedes_range({1, 1}, {{2, 2}, {2, 3}})
      refute _location_precedes_range({1, 1}, {{2, 2}, {2, :end}})
      refute _location_precedes_range({2, 2}, {{1, 1}, {2, 2}})
      refute _location_precedes_range({2, 2}, {{1, 1}, {2, :end}})
    end

    test "_location_precedes_range/2 identifies next-door end ranges" do
      assert _location_precedes_range({1, 1}, {{1, 2}, :end})
      refute _location_precedes_range({1, 1}, {{1, 3}, :end})
      refute _location_precedes_range({1, 1}, {{2, 2}, :end})
      refute _location_precedes_range({2, 2}, {{1, 1}, :end})
    end

    test "_range_precedes_location/2 identifies next-door ranges" do
      assert _range_precedes_location({{1, 2}, {1, :end}}, {2, 1})
      assert _range_precedes_location({{1, 2}, {2, 2}}, {2, 3})
      assert _range_precedes_location({{1, 2}, {2, :end}}, {3, 1})
      refute _range_precedes_location({{1, 3}, {2, 2}}, {2, 4})
      refute _range_precedes_location({{1, 3}, {2, 2}}, {3, 3})
      refute _range_precedes_location({{1, 3}, {2, :end}}, {3, 2})
      refute _range_precedes_location({{1, 3}, {2, :end}}, {4, 1})
      refute _range_precedes_location({{1, 2}, {1, 3}}, {1, 1})
    end

    test "_range_precedes_location/2 is always false for end ranges" do
      refute _range_precedes_location({{1, 2}, :end}, {1, 1})
      refute _range_precedes_location({{1, 2}, :end}, {1, 2})
      refute _range_precedes_location({{1, 2}, :end}, {1, 3})
      refute _range_precedes_location({{1, 3}, :end}, {2, 1})
    end

    test "_range_precedes_range/2 identifies next-door ranges" do
      # normal ranges
      refute _range_precedes_range({{1, 2}, {2, 1}}, {{2, 3}, {2, 4}})
      assert _range_precedes_range({{1, 2}, {2, 2}}, {{2, 3}, {2, 4}})
      assert _range_precedes_range({{1, 2}, {2, :end}}, {{3, 1}, {3, 3}})
      refute _range_precedes_range({{1, 2}, {2, :end}}, {{3, 2}, {3, 3}})
      refute _range_precedes_range({{1, 2}, {2, 1}}, {{2, 3}, {2, :end}})
      assert _range_precedes_range({{1, 2}, {2, 2}}, {{2, 3}, {2, :end}})
      assert _range_precedes_range({{1, 2}, {2, :end}}, {{3, 1}, {3, :end}})
      refute _range_precedes_range({{1, 2}, {2, :end}}, {{3, 2}, {3, :end}})
      refute _range_precedes_range({{1, 2}, {2, 1}}, {{2, 3}, :end})
      assert _range_precedes_range({{1, 2}, {2, 2}}, {{2, 3}, :end})
      assert _range_precedes_range({{1, 2}, {2, :end}}, {{3, 1}, :end})
      refute _range_precedes_range({{1, 2}, {2, :end}}, {{3, 2}, :end})
    end

    test "_range_precedes_range/2 identifies overlapping ranges" do
      assert _range_precedes_range({{1, 2}, {2, 3}}, {{2, 3}, {2, 5}})
      assert _range_precedes_range({{1, 2}, {2, 3}}, {{2, 3}, {2, :end}})
      assert _range_precedes_range({{1, 2}, {2, 3}}, {{2, 3}, :end})
      assert _range_precedes_range({{1, 2}, {2, 4}}, {{2, 3}, {2, 5}})
      assert _range_precedes_range({{1, 2}, {2, 4}}, {{2, 3}, {2, :end}})
      assert _range_precedes_range({{1, 2}, {2, 4}}, {{2, 3}, :end})
      assert _range_precedes_range({{1, 2}, {2, 5}}, {{2, 3}, {2, 5}})
      assert _range_precedes_range({{1, 2}, {1, :end}}, {{1, 3}, {2, 5}})
      refute _range_precedes_range({{1, 2}, {2, 6}}, {{2, 3}, {2, 5}})
      refute _range_precedes_range({{1, 2}, {2, :end}}, {{2, 3}, {2, 5}})
      refute _range_precedes_range({{1, 2}, :end}, {{2, 3}, {2, 5}})
      refute _range_precedes_range({{1, 2}, :end}, {{2, 3}, {2, :end}})
      assert _range_precedes_range({{1, 2}, :end}, {{2, 3}, :end})
    end
  end

  describe "the register_cell_change/2 function puts into an empty list" do
    test "a single tuple" do
      assert [{1, 1}] === register_cell_change([], {1, 1})
    end

    test "a basic range" do
      assert [{{1, 1}, {2, 2}}] === register_cell_change([], {{1, 1}, {2, 2}})
    end

    test "a range with a line end" do
      assert [{{1, 1}, {2, :end}}] === register_cell_change([], {{1, 1}, {2, :end}})
    end

    test "an end range" do
      assert [{{1, 1}, :end}] === register_cell_change([], {{1, 1}, :end})
    end
  end

  describe "the register_cell_change/2 function puts with two locations" do
    test "a disjoint lesser location is passed through" do
      assert [{1, 3}, {1, 1}] === register_cell_change([{1, 3}], {1, 1})
    end

    test "a preceding location is merged through" do
      assert [{{1, 1}, {1, 2}}] === register_cell_change([{1, 2}], {1, 1})
    end

    test "an identical location is merged through" do
      assert [{1, 2}] === register_cell_change([{1, 2}], {1, 2})
    end

    test "a succeeding location is merged through" do
      assert [{{1, 1}, {1, 2}}] === register_cell_change([{1, 1}], {1, 2})
    end

    test "a disjoint greater location is passed through" do
      assert [{1, 3}, {1, 1}] === register_cell_change([{1, 1}], {1, 3})
    end
  end

  describe "the register_cell_change/2 function puts with a location and a range" do
    test "a disjoint lesser location is passed through" do
      assert [{{1, 3}, {1, 4}}, {1, 1}] === register_cell_change([{{1, 3}, {1, 4}}], {1, 1})
    end

    test "a preceding location is merged through" do
      assert [{{1, 1}, {1, 4}}] === register_cell_change([{{1, 2}, {1, 4}}], {1, 1})
      assert [{{1, 1}, {1, :end}}] === register_cell_change([{{1, 2}, {1, :end}}], {1, 1})
      assert [{{1, 1}, :end}] === register_cell_change([{{1, 2}, :end}], {1, 1})
    end

    test "an internal location is merged through" do
      assert [{{1, 2}, {1, 4}}] === register_cell_change([{{1, 2}, {1, 4}}], {1, 2})
      assert [{{1, 2}, {1, 4}}] === register_cell_change([{{1, 2}, {1, 4}}], {1, 3})
      assert [{{1, 2}, {1, 4}}] === register_cell_change([{{1, 2}, {1, 4}}], {1, 4})

      assert [{{1, 2}, {1, :end}}] === register_cell_change([{{1, 2}, {1, :end}}], {1, 2})
      assert [{{1, 2}, {1, :end}}] === register_cell_change([{{1, 2}, {1, :end}}], {1, 3})
      assert [{{1, 2}, {1, :end}}] === register_cell_change([{{1, 2}, {1, :end}}], {1, 4})

      assert [{{1, 2}, :end}] === register_cell_change([{{1, 2}, :end}], {1, 2})
      assert [{{1, 2}, :end}] === register_cell_change([{{1, 2}, :end}], {1, 3})
      assert [{{1, 2}, :end}] === register_cell_change([{{1, 2}, :end}], {1, 4})
    end

    test "a succeeding location is merged through" do
      assert [{{1, 1}, {1, 4}}] === register_cell_change([{{1, 1}, {1, 3}}], {1, 4})
      assert [{{1, 1}, {2, 1}}] === register_cell_change([{{1, 1}, {1, :end}}], {2, 1})
    end

    test "a disjoint greater location is passed through" do
      assert [{1, 4}, {{1, 1}, {1, 2}}] === register_cell_change([{{1, 1}, {1, 2}}], {1, 4})
      assert [{2, 2}, {{1, 1}, {1, :end}}] === register_cell_change([{{1, 1}, {1, :end}}], {2, 2})
    end
  end

  describe "the register_cell_change/2 function puts with a range and a location" do
    test "a disjoint lesser location is passed through" do
      assert [{{1, 3}, {1, 4}}, {1, 1}] === register_cell_change([{1, 1}], {{1, 3}, {1, 4}})
      assert [{{1, 3}, {1, :end}}, {1, 1}] === register_cell_change([{1, 1}], {{1, 3}, {1, :end}})
      assert [{{1, 3}, :end}, {1, 1}] === register_cell_change([{1, 1}], {{1, 3}, :end})
    end

    test "a preceding location is merged through" do
      assert [{{1, 1}, {1, 4}}] === register_cell_change([{1, 1}], {{1, 2}, {1, 4}})
      assert [{{1, 1}, {1, :end}}] === register_cell_change([{1, 1}], {{1, 2}, {1, :end}})
      assert [{{1, 1}, :end}] === register_cell_change([{1, 1}], {{1, 2}, :end})
    end

    test "an internal location is merged through" do
      assert [{{1, 2}, {1, 4}}] === register_cell_change([{1, 2}], {{1, 2}, {1, 4}})
      assert [{{1, 2}, {1, 4}}] === register_cell_change([{1, 3}], {{1, 2}, {1, 4}})
      assert [{{1, 2}, {1, 4}}] === register_cell_change([{1, 4}], {{1, 2}, {1, 4}})

      assert [{{1, 2}, {1, :end}}] === register_cell_change([{1, 2}], {{1, 2}, {1, :end}})
      assert [{{1, 2}, {1, :end}}] === register_cell_change([{1, 3}], {{1, 2}, {1, :end}})

      assert [{{1, 2}, :end}] === register_cell_change([{1, 2}], {{1, 2}, :end})
      assert [{{1, 2}, :end}] === register_cell_change([{1, 3}], {{1, 2}, :end})
    end

    test "a succeeding location is merged through" do
      assert [{{1, 1}, {1, 4}}] === register_cell_change([{1, 4}], {{1, 1}, {1, 3}})
      assert [{{1, 1}, {2, 1}}] === register_cell_change([{2, 1}], {{1, 1}, {1, :end}})
    end

    test "a disjoint greater location is passed through" do
      assert [{1, 4}, {{1, 1}, {1, 2}}] === register_cell_change([{1, 4}], {{1, 1}, {1, 2}})
      assert [{2, 2}, {{1, 1}, {1, :end}}] === register_cell_change([{2, 2}], {{1, 1}, {1, :end}})
    end
  end

  describe "the register_cell_change/2 function puts with a range and a range" do
    test "a disjoint lesser range is passed through" do
      assert [{{1, 4}, {1, 5}}, {{1, 1}, {1, 2}}] ===
               register_cell_change([{{1, 4}, {1, 5}}], {{1, 1}, {1, 2}})

      assert [{{1, 4}, {1, :end}}, {{1, 1}, {1, 2}}] ===
               register_cell_change([{{1, 4}, {1, :end}}], {{1, 1}, {1, 2}})

      assert [{{1, 4}, :end}, {{1, 1}, {1, 2}}] ===
               register_cell_change([{{1, 4}, :end}], {{1, 1}, {1, 2}})
    end

    test "a preceding range is merged through" do
      assert [{{1, 1}, {1, 5}}] === register_cell_change([{{1, 4}, {1, 5}}], {{1, 1}, {1, 3}})
      assert [{{1, 1}, {1, :end}}] === register_cell_change([{{1, 4}, {1, :end}}], {{1, 1}, {1, 3}})
      assert [{{1, 1}, :end}] === register_cell_change([{{1, 4}, :end}], {{1, 1}, {1, 3}})
    end

    test "an overlapping range is merged through" do
      assert [{{1, 1}, {1, 6}}] === register_cell_change([{{1, 4}, {1, 6}}], {{1, 1}, {1, 4}})
      assert [{{1, 1}, {1, 6}}] === register_cell_change([{{1, 4}, {1, 6}}], {{1, 1}, {1, 5}})
      assert [{{1, 1}, {1, 6}}] === register_cell_change([{{1, 4}, {1, 6}}], {{1, 1}, {1, 6}})

      assert [{{1, 1}, {1, :end}}] === register_cell_change([{{1, 4}, {1, :end}}], {{1, 1}, {1, 4}})
      assert [{{1, 1}, {1, :end}}] === register_cell_change([{{1, 4}, {1, :end}}], {{1, 1}, {1, 5}})

      assert [{{1, 1}, :end}] === register_cell_change([{{1, 4}, :end}], {{1, 1}, {1, 4}})
      assert [{{1, 1}, :end}] === register_cell_change([{{1, 4}, :end}], {{1, 1}, {1, 5}})
    end

    test "an identical range is merged through" do
      assert [{{1, 1}, {1, 4}}] === register_cell_change([{{1, 1}, {1, 4}}], {{1, 1}, {1, 4}})
      assert [{{1, 1}, {1, :end}}] === register_cell_change([{{1, 1}, {1, :end}}], {{1, 1}, {1, :end}})
      assert [{{1, 1}, :end}] === register_cell_change([{{1, 1}, :end}], {{1, 1}, :end})
    end

    test "an internal range is merged through" do
      assert [{{1, 1}, {1, 4}}] === register_cell_change([{{1, 1}, {1, 4}}], {{1, 1}, {1, 2}})
      assert [{{1, 1}, {1, 4}}] === register_cell_change([{{1, 1}, {1, 4}}], {{1, 2}, {1, 3}})
      assert [{{1, 1}, {1, 4}}] === register_cell_change([{{1, 1}, {1, 4}}], {{1, 2}, {1, 4}})

      assert [{{1, 1}, {1, :end}}] === register_cell_change([{{1, 1}, {1, :end}}], {{1, 1}, {1, 2}})
      assert [{{1, 1}, {1, :end}}] === register_cell_change([{{1, 1}, {1, :end}}], {{1, 2}, {1, 3}})

      assert [{{1, 1}, :end}] === register_cell_change([{{1, 1}, :end}], {{1, 2}, {1, 3}})
      assert [{{1, 1}, :end}] === register_cell_change([{{1, 1}, :end}], {{1, 1}, {1, 2}})
    end

    test "a surrounding range is merged through" do
      assert [{{1, 1}, {1, 4}}] === register_cell_change([{{1, 1}, {1, 2}}], {{1, 1}, {1, 4}})
      assert [{{1, 1}, {1, 4}}] === register_cell_change([{{1, 2}, {1, 3}}], {{1, 1}, {1, 4}})
      assert [{{1, 1}, {1, 4}}] === register_cell_change([{{1, 2}, {1, 4}}], {{1, 1}, {1, 4}})

      assert [{{1, 1}, {1, :end}}] === register_cell_change([{{1, 1}, {1, 2}}], {{1, 1}, {1, :end}})
      assert [{{1, 1}, {1, :end}}] === register_cell_change([{{1, 2}, {1, 3}}], {{1, 1}, {1, :end}})

      assert [{{1, 1}, :end}] === register_cell_change([{{1, 2}, {1, 3}}], {{1, 1}, :end})
      assert [{{1, 1}, :end}] === register_cell_change([{{1, 1}, {1, 2}}], {{1, 1}, :end})
    end
  end

  describe "the register_cell_change/2 function can merge succesive content" do
    test "location, location, location" do
      assert [{{1, 1}, {1, 3}}] === register_cell_change([{1, 3}, {1, 1}], {1, 2})
    end

    test "location, location, range" do
      assert [{{1, 1}, {1, 4}}] === register_cell_change([{{1, 3}, {1, 4}}, {1, 1}], {1, 2})
      assert [{{1, 1}, {1, :end}}] === register_cell_change([{{1, 3}, {1, :end}}, {1, 1}], {1, 2})
    end

    test "location, range, location" do
      assert [{{1, 1}, {1, 4}}] === register_cell_change([{1, 4}, {1, 1}], {{1, 2}, {1, 3}})
      assert [{{1, 1}, {2, 1}}] === register_cell_change([{2, 1}, {1, 1}], {{1, 2}, {1, :end}})
    end

    test "location, range, range" do
      assert [{{1, 1}, {1, 5}}] === register_cell_change([{{1, 4}, {1, 5}}, {1, 1}], {{1, 2}, {1, 3}})
      assert [{{1, 1}, {2, 2}}] === register_cell_change([{{2, 1}, {2, 2}}, {1, 1}], {{1, 2}, {1, :end}})

      assert [{{1, 1}, {1, :end}}] ===
               register_cell_change([{{1, 4}, {1, :end}}, {1, 1}], {{1, 2}, {1, 3}})

      assert [{{1, 1}, {2, :end}}] ===
               register_cell_change([{{2, 1}, {2, :end}}, {1, 1}], {{1, 2}, {1, :end}})
    end

    test "range, location, location" do
      assert [{{1, 1}, {1, 4}}] === register_cell_change([{1, 4}, {{1, 1}, {1, 2}}], {1, 3})
      assert [{{1, 1}, {2, 2}}] === register_cell_change([{2, 2}, {{1, 1}, {1, :end}}], {2, 1})
    end

    test "range, location, range" do
      assert [{{1, 1}, {1, 5}}] === register_cell_change([{{1, 4}, {1, 5}}, {{1, 1}, {1, 2}}], {1, 3})
      assert [{{1, 1}, {2, 3}}] === register_cell_change([{{2, 2}, {2, 3}}, {{1, 1}, {1, :end}}], {2, 1})

      assert [{{1, 1}, {1, :end}}] ===
               register_cell_change([{{1, 4}, {1, :end}}, {{1, 1}, {1, 2}}], {1, 3})

      assert [{{1, 1}, {2, :end}}] ===
               register_cell_change([{{2, 2}, {2, :end}}, {{1, 1}, {1, :end}}], {2, 1})
    end

    test "range, range, location" do
      assert [{{1, 1}, {1, 5}}] === register_cell_change([{1, 5}, {{1, 1}, {1, 2}}], {{1, 3}, {1, 4}})
      assert [{{1, 1}, {2, 3}}] === register_cell_change([{2, 3}, {{1, 1}, {1, :end}}], {{2, 1}, {2, 2}})
      assert [{{1, 1}, {2, 1}}] === register_cell_change([{2, 1}, {{1, 1}, {1, 2}}], {{1, 3}, {1, :end}})

      assert [{{1, 1}, {3, 1}}] ===
               register_cell_change([{3, 1}, {{1, 1}, {1, :end}}], {{2, 1}, {2, :end}})
    end

    test "range, range, range" do
      assert [{{1, 1}, {1, 6}}] ===
               register_cell_change([{{1, 5}, {1, 6}}, {{1, 1}, {1, 2}}], {{1, 3}, {1, 4}})
    end

    test "ranges that eat locations" do
      assert [{{1, 1}, {1, 9}}] === register_cell_change([{1, 5}, {1, 3}], {{1, 1}, {1, 9}})
      assert [{{1, 1}, {1, :end}}] === register_cell_change([{1, 5}, {1, 3}], {{1, 1}, {1, :end}})
    end
  end
end
