defmodule UzuParser.CombinationTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Tests for combinations of groupers and operators.

  Groupers: [] (subdivision), <> (alternation), {} (polymetric)
  Operators: * (repeat), / (divide), ! (replicate), ? (probability), @ (weight)

  Each grouper should support operators applied to it:
  - [a b]*2  - play subdivision twice as fast
  - [a b]/2  - play subdivision half as slow
  - [a b]!3  - replicate subdivision 3 times in sequence
  - [a b]?   - 50% chance to play
  - [a b]?0.25 - 25% chance to play

  And operators inside groupers on atoms:
  - [a*2 b]  - a repeated twice, then b
  - [a!3 b]  - a replicated 3 times, then b
  """

  # Helper to parse and extract the first node from sequence
  defp parse_first(pattern) do
    {:ok, {:sequence, [node]}} = UzuParser.parse(pattern)
    node
  end

  defp parse_nodes(pattern) do
    {:ok, {:sequence, nodes}} = UzuParser.parse(pattern)
    nodes
  end

  # Extract children from a grouper node - handles [sequence: [...]] keyword list format
  defp get_children(node) do
    case node.children do
      [sequence: items] -> items
      other -> other
    end
  end

  # Extract groups from a polymetric node - handles [groups: [[sequence: ...], ...]] format
  defp get_groups(node) do
    case node.children do
      [groups: groups] -> groups
      other -> other
    end
  end

  # Extract sequence items from a group (for polymetric groups)
  defp get_group_items(group) do
    case group do
      {:sequence, items} -> items
      [sequence: items] -> items
      other -> other
    end
  end

  # ============================================================================
  # Subdivision [] with operators
  # ============================================================================

  describe "subdivision [] with operators" do
    test "[a b]*2 - repeat after subdivision" do
      node = parse_first("[a b]*2")

      assert node.type == :subdivision
      assert node.repeat == 2
      children = get_children(node)
      assert length(children) == 2
    end

    test "[a b]/2 - division after subdivision" do
      node = parse_first("[a b]/2")

      assert node.type == :subdivision
      assert node.division == 2
      children = get_children(node)
      assert length(children) == 2
    end

    @tag :pending
    test "[a b]! - replicate (bare) after subdivision" do
      # Should default to replicate: 1 (or maybe 2?)
      node = parse_first("[a b]!")

      assert node.type == :subdivision
      assert node.replicate == 1
    end

    @tag :pending
    test "[a b]!3 - replicate with count after subdivision" do
      node = parse_first("[a b]!3")

      assert node.type == :subdivision
      assert node.replicate == 3
    end

    @tag :pending
    test "[a b]? - probability (default 0.5) after subdivision" do
      node = parse_first("[a b]?")

      assert node.type == :subdivision
      assert node.probability == 0.5
    end

    @tag :pending
    test "[a b]?0.25 - probability with value after subdivision" do
      node = parse_first("[a b]?0.25")

      assert node.type == :subdivision
      assert node.probability == 0.25
    end

    test "[a*2 b] - repeat inside subdivision" do
      node = parse_first("[a*2 b]")

      assert node.type == :subdivision
      [a, b] = get_children(node)
      assert a.value == "a"
      assert a.repeat == 2
      assert b.value == "b"
      assert b.repeat == nil
    end

    test "[a!3 b] - replicate inside subdivision" do
      node = parse_first("[a!3 b]")

      assert node.type == :subdivision
      [a, b] = get_children(node)
      assert a.value == "a"
      assert a.replicate == 3
      assert b.value == "b"
    end

    test "[a? b] - probability inside subdivision" do
      node = parse_first("[a? b]")

      assert node.type == :subdivision
      [a, b] = get_children(node)
      assert a.value == "a"
      assert a.probability == 0.5
      assert b.value == "b"
    end

    test "[a@2 b] - weight inside subdivision" do
      node = parse_first("[a@2 b]")

      assert node.type == :subdivision
      [a, b] = get_children(node)
      assert a.value == "a"
      assert a.weight == 2
      assert b.value == "b"
      assert b.weight == 1.0
    end
  end

  # ============================================================================
  # Alternation <> with operators
  # ============================================================================

  describe "alternation <> with operators" do
    test "<a b>*2 - repeat after alternation" do
      node = parse_first("<a b>*2")

      assert node.type == :alternation
      assert node.repeat == 2
      children = get_children(node)
      assert length(children) == 2
    end

    test "<a b>/2 - division after alternation" do
      node = parse_first("<a b>/2")

      assert node.type == :alternation
      assert node.division == 2
    end

    @tag :pending
    test "<a b>! - replicate after alternation" do
      node = parse_first("<a b>!")

      assert node.type == :alternation
      assert node.replicate == 1
    end

    @tag :pending
    test "<a b>!3 - replicate with count after alternation" do
      node = parse_first("<a b>!3")

      assert node.type == :alternation
      assert node.replicate == 3
    end

    @tag :pending
    test "<a b>? - probability after alternation" do
      node = parse_first("<a b>?")

      assert node.type == :alternation
      assert node.probability == 0.5
    end

    test "<a*2 b> - repeat inside alternation" do
      node = parse_first("<a*2 b>")

      assert node.type == :alternation
      [a, b] = get_children(node)
      assert a.value == "a"
      assert a.repeat == 2
      assert b.value == "b"
    end
  end

  # ============================================================================
  # Polymetric {} with operators
  # ============================================================================

  describe "polymetric {} with operators" do
    test "{a b, c d}%4 - steps modifier" do
      node = parse_first("{a b, c d}%4")

      assert node.type == :polymetric
      assert node.steps == 4
      groups = get_groups(node)
      assert length(groups) == 2
    end

    @tag :pending
    test "{a b, c d}*2 - repeat after polymetric" do
      node = parse_first("{a b, c d}*2")

      assert node.type == :polymetric
      assert node.repeat == 2
    end

    @tag :pending
    test "{a b, c d}/2 - division after polymetric" do
      node = parse_first("{a b, c d}/2")

      assert node.type == :polymetric
      assert node.division == 2
    end

    @tag :pending
    test "{a b, c d}? - probability after polymetric" do
      node = parse_first("{a b, c d}?")

      assert node.type == :polymetric
      assert node.probability == 0.5
    end

    test "{a*2 b, c} - repeat inside polymetric" do
      node = parse_first("{a*2 b, c}")

      assert node.type == :polymetric
      groups = get_groups(node)
      assert length(groups) == 2
      [group1, _group2] = groups
      [a, b] = get_group_items(group1)
      assert a.value == "a"
      assert a.repeat == 2
      assert b.value == "b"
    end
  end

  # ============================================================================
  # Atoms with operators
  # ============================================================================

  describe "atoms with operators" do
    test "a*2 - repeat" do
      [node] = parse_nodes("a*2")
      assert node.value == "a"
      assert node.repeat == 2
    end

    test "a/2 - division" do
      [node] = parse_nodes("a/2")
      assert node.value == "a"
      assert node.division == 2
    end

    test "a!3 - replicate with count" do
      [node] = parse_nodes("a!3")
      assert node.value == "a"
      assert node.replicate == 3
    end

    @tag :pending
    test "a! - replicate bare (should default)" do
      [node] = parse_nodes("a!")
      assert node.value == "a"
      assert node.replicate == 1
    end

    test "a? - probability default 0.5" do
      [node] = parse_nodes("a?")
      assert node.value == "a"
      assert node.probability == 0.5
    end

    test "a?0.75 - probability with value" do
      [node] = parse_nodes("a?0.75")
      assert node.value == "a"
      assert node.probability == 0.75
    end

    test "a@2 - weight" do
      [node] = parse_nodes("a@2")
      assert node.value == "a"
      assert node.weight == 2
    end

    test "a(3,8) - euclidean" do
      [node] = parse_nodes("a(3,8)")
      assert node.value == "a"
      assert node.euclidean == [3, 8]
    end

    test "a(3,8,2) - euclidean with rotation" do
      [node] = parse_nodes("a(3,8,2)")
      assert node.value == "a"
      assert node.euclidean == [3, 8, 2]
    end

    test "a:1 - sample selection" do
      [node] = parse_nodes("a:1")
      assert node.value == "a"
      assert node.sample == 1
    end
  end

  # ============================================================================
  # Combined operators
  # ============================================================================

  describe "combined operators on atoms" do
    test "a:1*2 - sample and repeat" do
      [node] = parse_nodes("a:1*2")
      assert node.value == "a"
      assert node.sample == 1
      assert node.repeat == 2
    end

    test "a*2? - repeat and probability" do
      [node] = parse_nodes("a*2?")
      assert node.value == "a"
      assert node.repeat == 2
      assert node.probability == 0.5
    end

    test "a@2*3 - weight and repeat" do
      [node] = parse_nodes("a@2*3")
      assert node.value == "a"
      assert node.weight == 2
      assert node.repeat == 3
    end
  end

  # ============================================================================
  # Nested structures
  # ============================================================================

  describe "nested structures" do
    test "[[a b]*2 c] - nested subdivision with repeat" do
      node = parse_first("[[a b]*2 c]")

      assert node.type == :subdivision
      [inner, c] = get_children(node)
      assert inner.type == :subdivision
      assert inner.repeat == 2
      assert c.value == "c"
    end

    test "[<a b> c] - alternation inside subdivision" do
      node = parse_first("[<a b> c]")

      assert node.type == :subdivision
      [alt, c] = get_children(node)
      assert alt.type == :alternation
      assert c.value == "c"
    end

    test "<[a b] c> - subdivision inside alternation" do
      node = parse_first("<[a b] c>")

      assert node.type == :alternation
      [sub, c] = get_children(node)
      assert sub.type == :subdivision
      assert c.value == "c"
    end
  end
end
