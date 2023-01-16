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
      _push_change: 2
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
  end

  describe "the _is_disjoint_greater/2 guard" do
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

    test "correctly identifies disjoint location compared to end range"
  end

  describe "the precede function" do
    test "_location_precedes_location/2 identifies next-door locations" do
      assert _location_precedes_location({1, 1}, {1, 2})
      refute _location_precedes_location({1, 1}, {1, 3})
      refute _location_precedes_location({1, 1}, {2, 2})
      refute _location_precedes_location({1, 2}, {1, 1})
    end

    test "_location_precedes_range/2 identifies next-door locations" do
      assert _location_precedes_range({1, 1}, {{1, 2}, {2, 2}})
      refute _location_precedes_range({1, 1}, {{1, 3}, {2, 2}})
      refute _location_precedes_range({1, 1}, {{2, 2}, {2, 3}})
      refute _location_precedes_range({2, 2}, {{1, 1}, {2, 2}})
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

    test "_range_precedes_range/2 identifies next-door ranges" do
      refute _range_precedes_range({{1, 2}, {2, 1}}, {{2, 3}, {2, 4}})
      assert _range_precedes_range({{1, 2}, {2, 2}}, {{2, 3}, {2, 4}})
    end

    test "_range_precedes_range/2 identifies overlapping ranges" do
      assert _range_precedes_range({{1, 2}, {2, 3}}, {{2, 3}, {2, 5}})
      assert _range_precedes_range({{1, 2}, {2, 4}}, {{2, 3}, {2, 5}})
      assert _range_precedes_range({{1, 2}, {2, 5}}, {{2, 3}, {2, 5}})
      assert _range_precedes_range({{1, 2}, {1, :end}}, {{1, 3}, {2, 5}})
      refute _range_precedes_range({{1, 2}, {2, 6}}, {{2, 3}, {2, 5}})
      refute _range_precedes_range({{1, 2}, {2, :end}}, {{2, 3}, {2, 5}})
    end
  end

  describe "the _push_change/2 function puts into an empty list" do
    test "a single tuple" do
      assert [{1, 1}] === _push_change([], {1, 1})
    end

    test "a basic range" do
      assert [{{1, 1}, {2, 2}}] === _push_change([], {{1, 1}, {2, 2}})
    end

    test "a range with a line end" do
      assert [{{1, 1}, {2, :end}}] === _push_change([], {{1, 1}, {2, :end}})
    end
  end

  describe "the _push_change/2 function puts with two locations" do
    test "a disjoint lesser location is passed through" do
      assert [{1, 3}, {1, 1}] === _push_change([{1, 3}], {1, 1})
    end

    test "a preceding location is merged through" do
      assert [{{1, 1}, {1, 2}}] === _push_change([{1, 2}], {1, 1})
    end

    test "an identical location is merged through" do
      assert [{1, 2}] === _push_change([{1, 2}], {1, 2})
    end

    test "a succeeding location is merged through" do
      assert [{{1, 1}, {1, 2}}] === _push_change([{1, 1}], {1, 2})
    end

    test "a disjoint greater location is passed through" do
      assert [{1, 3}, {1, 1}] === _push_change([{1, 1}], {1, 3})
    end
  end

  describe "the _push_change/2 function puts with a location and a range" do
    test "a disjoint lesser location is passed through" do
      assert [{{1, 3}, {1, 4}}, {1, 1}] === _push_change([{{1, 3}, {1, 4}}], {1, 1})
    end

    test "a preceding location is merged through" do
      assert [{{1, 1}, {1, 4}}] === _push_change([{{1, 2}, {1, 4}}], {1, 1})
    end

    test "an internal location is merged through" do
      assert [{{1, 2}, {1, 4}}] === _push_change([{{1, 2}, {1, 4}}], {1, 2})
      assert [{{1, 2}, {1, 4}}] === _push_change([{{1, 2}, {1, 4}}], {1, 3})
      assert [{{1, 2}, {1, 4}}] === _push_change([{{1, 2}, {1, 4}}], {1, 4})
    end

    test "a succeeding location is merged through" do
      assert [{{1, 1}, {1, 4}}] === _push_change([{{1, 1}, {1, 3}}], {1, 4})
      assert [{{1, 1}, {2, 1}}] === _push_change([{{1, 1}, {1, :end}}], {2, 1})
    end

    test "a disjoint greater location is passed through" do
      assert [{1, 4}, {{1, 1}, {1, 2}}] === _push_change([{{1, 1}, {1, 2}}], {1, 4})
      assert [{2, 2}, {{1, 1}, {1, :end}}] === _push_change([{{1, 1}, {1, :end}}], {2, 2})
    end
  end

  describe "the _push_change/2 function puts with a range and a location" do
    test "a disjoint lesser location is passed through" do
      assert [{{1, 3}, {1, 4}}, {1, 1}] === _push_change([{1, 1}], {{1, 3}, {1, 4}})
    end

    test "a preceding location is merged through" do
      assert [{{1, 1}, {1, 4}}] === _push_change([{1, 1}], {{1, 2}, {1, 4}})
    end

    test "an internal location is merged through" do
      assert [{{1, 2}, {1, 4}}] === _push_change([{1, 2}], {{1, 2}, {1, 4}})
      assert [{{1, 2}, {1, 4}}] === _push_change([{1, 3}], {{1, 2}, {1, 4}})
      assert [{{1, 2}, {1, 4}}] === _push_change([{1, 4}], {{1, 2}, {1, 4}})
    end

    test "a succeeding location is merged through" do
      assert [{{1, 1}, {1, 4}}] === _push_change([{1, 4}], {{1, 1}, {1, 3}})
      assert [{{1, 1}, {2, 1}}] === _push_change([{2, 1}], {{1, 1}, {1, :end}})
    end

    test "a disjoint greater location is passed through" do
      assert [{1, 4}, {{1, 1}, {1, 2}}] === _push_change([{1, 4}], {{1, 1}, {1, 2}})
      assert [{2, 2}, {{1, 1}, {1, :end}}] === _push_change([{2, 2}], {{1, 1}, {1, :end}})
    end
  end

  describe "the _push_change/2 function puts with a range and a range" do
    test "a disjoint lesser range is passed through" do
      assert [{{1, 4}, {1, 5}}, {{1, 1}, {1, 2}}] ===
               _push_change([{{1, 4}, {1, 5}}], {{1, 1}, {1, 2}})
    end

    test "a preceding location is merged through" do
      assert [{{1, 1}, {1, 5}}] === _push_change([{{1, 4}, {1, 5}}], {{1, 1}, {1, 3}})
    end

    test "an preceding location is merged through" do
      assert [{{1, 1}, {1, 5}}] === _push_change([{{1, 4}, {1, 5}}], {{1, 1}, {1, 3}})
    end

    test "an overlapping location is merged through" do
      assert [{{1, 1}, {1, 6}}] === _push_change([{{1, 4}, {1, 6}}], {{1, 1}, {1, 4}})
      assert [{{1, 1}, {1, 6}}] === _push_change([{{1, 4}, {1, 6}}], {{1, 1}, {1, 5}})
      assert [{{1, 1}, {1, 6}}] === _push_change([{{1, 4}, {1, 6}}], {{1, 1}, {1, 6}})
    end

    test "an identical location is merged through" do
      assert [{{1, 1}, {1, 4}}] === _push_change([{{1, 1}, {1, 4}}], {{1, 1}, {1, 4}})
    end

    test "an internal location is merged through" do
      assert [{{1, 1}, {1, 4}}] === _push_change([{{1, 1}, {1, 4}}], {{1, 1}, {1, 2}})
      assert [{{1, 1}, {1, 4}}] === _push_change([{{1, 1}, {1, 4}}], {{1, 2}, {1, 3}})
      assert [{{1, 1}, {1, 4}}] === _push_change([{{1, 1}, {1, 4}}], {{1, 2}, {1, 4}})
    end
  end

  describe "the _push_change/2 function can merge content" do
    test "location, location, location" do
      assert [{{1, 1}, {1, 3}}] === _push_change([{1, 3}, {1, 1}], {1, 2})
    end

    test "location, location, range" do
      assert [{{1, 1}, {1, 4}}] === _push_change([{{1, 3}, {1, 4}}, {1, 1}], {1, 2})
      assert [{{1, 1}, {1, :end}}] === _push_change([{{1, 3}, {1, :end}}, {1, 1}], {1, 2})
    end

    test "location, range, location" do
      assert [{{1, 1}, {1, 4}}] === _push_change([{1, 4}, {1, 1}], {{1, 2}, {1, 3}})
      assert [{{1, 1}, {2, 1}}] === _push_change([{2, 1}, {1, 1}], {{1, 2}, {1, :end}})
    end

    test "location, range, range" do
      assert [{{1, 1}, {1, 5}}] === _push_change([{{1, 4}, {1, 5}}, {1, 1}], {{1, 2}, {1, 3}})
      assert [{{1, 1}, {2, 2}}] === _push_change([{{2, 1}, {2, 2}}, {1, 1}], {{1, 2}, {1, :end}})
      assert [{{1, 1}, {1, :end}}] === _push_change([{{1, 4}, {1, :end}}, {1, 1}], {{1, 2}, {1, 3}})
      assert [{{1, 1}, {2, :end}}] === _push_change([{{2, 1}, {2, :end}}, {1, 1}], {{1, 2}, {1, :end}})
    end

    test "range, location, location" do
      assert [{{1, 1}, {1, 4}}] === _push_change([{1, 4}, {{1, 1}, {1, 2}}], {1, 3})
      assert [{{1, 1}, {2, 2}}] === _push_change([{2, 2}, {{1, 1}, {1, :end}}], {2, 1})
    end

    test "range, location, range" do
      assert [{{1, 1}, {1, 5}}] === _push_change([{{1, 4}, {1, 5}}, {{1, 1}, {1, 2}}], {1, 3})
      assert [{{1, 1}, {2, 3}}] === _push_change([{{2, 2}, {2, 3}}, {{1, 1}, {1, :end}}], {2, 1})
      assert [{{1, 1}, {1, :end}}] === _push_change([{{1, 4}, {1, :end}}, {{1, 1}, {1, 2}}], {1, 3})
      assert [{{1, 1}, {2, :end}}] === _push_change([{{2, 2}, {2, :end}}, {{1, 1}, {1, :end}}], {2, 1})
    end

    test "range, range, location" do
      assert [{{1, 1}, {1, 5}}] === _push_change([{1, 5}, {{1, 1}, {1, 2}}], {{1, 3}, {1, 4}})
      assert [{{1, 1}, {2, 3}}] === _push_change([{2, 3}, {{1, 1}, {1, :end}}], {{2, 1}, {2, 2}})
      assert [{{1, 1}, {2, 1}}] === _push_change([{2, 1}, {{1, 1}, {1, 2}}], {{1, 3}, {1, :end}})
      assert [{{1, 1}, {3, 1}}] === _push_change([{3, 1}, {{1, 1}, {1, :end}}], {{2, 1}, {2, :end}})
    end

    test "range, range, range" do
      assert [{{1, 1}, {1, 6}}] === _push_change([{{1, 5}, {1, 6}}, {{1, 1}, {1, 2}}], {{1, 3}, {1, 4}})
    end

    test "ranges that eat locations" do
      assert [{{1, 1}, {1, 9}}] === _push_change([{1, 5}, {1, 3}], {{1, 1}, {1, 9}})
      assert [{{1, 1}, {1, :end}}] === _push_change([{1, 5}, {1, 3}], {{1, 1}, {1, :end}})
    end
  end
end
