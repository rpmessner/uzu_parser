defmodule UzuParser.Integration.HarmonyTokensTest do
  @moduledoc """
  Integration tests for harmony token parsing through UzuParser.parse/1.

  Tests scale degrees (^1, ^b7), chord symbols (@Dm7), and roman numerals (@V7).
  These tests verify the AST structure, not event generation.
  """

  use ExUnit.Case, async: true

  # Helper: extract AST nodes from parse result
  defp parse_ast(pattern) do
    {:ok, {:sequence, nodes}} = UzuParser.parse(pattern)
    nodes
  end

  describe "scale degrees" do
    test "parses basic degrees 1-7" do
      for degree <- 1..7 do
        [node] = parse_ast("^#{degree}")
        assert node.value == "^#{degree}"
        assert node.params.harmony_type == :degree
        assert node.params.harmony_value == degree
      end
    end

    test "parses extended degrees 9, 11, 13" do
      nodes = parse_ast("^9 ^11 ^13")

      assert length(nodes) == 3
      assert Enum.map(nodes, & &1.params.harmony_value) == [9, 11, 13]
      assert Enum.all?(nodes, &(&1.params.harmony_type == :degree))
    end

    test "parses flatted degrees ^b3, ^b7" do
      for degree <- ["b3", "b7"] do
        [node] = parse_ast("^#{degree}")
        assert node.params.harmony_type == :degree
        assert node.params.harmony_value == degree
      end
    end

    test "parses sharped degrees ^#5, ^#11" do
      for degree <- ["#5", "#11"] do
        [node] = parse_ast("^#{degree}")
        assert node.params.harmony_type == :degree
        assert node.params.harmony_value == degree
      end
    end

    test "invalid degrees (0, 14+) are treated as regular sounds" do
      for pattern <- ["^0", "^14", "^"] do
        [node] = parse_ast(pattern)
        assert node.value == pattern
        assert node.params == %{}
      end
    end
  end

  describe "chord symbols" do
    test "parses common chord types" do
      chords = [
        {"@Cmaj7", "Cmaj7"},
        {"@Dm7", "Dm7"},
        {"@G7", "G7"},
        {"@Am7b5", "Am7b5"},
        {"@Fmaj7#11", "Fmaj7#11"},
        {"@Ab7b5", "Ab7b5"}
      ]

      for {pattern, expected_value} <- chords do
        [node] = parse_ast(pattern)
        assert node.value == pattern
        assert node.params.harmony_type == :chord
        assert node.params.harmony_value == expected_value
      end
    end

    test "parses chord sequence" do
      nodes = parse_ast("@Dm7 @G7 @Cmaj7")

      assert length(nodes) == 3
      assert Enum.map(nodes, & &1.params.harmony_value) == ["Dm7", "G7", "Cmaj7"]
      assert Enum.all?(nodes, &(&1.params.harmony_type == :chord))
    end
  end

  describe "roman numerals" do
    test "parses basic roman numerals" do
      romans = [
        {"@I", "I", :roman},
        {"@ii", "ii", :roman},
        {"@V", "V", :roman},
        {"@vii", "vii", :roman}
      ]

      for {pattern, expected_value, expected_type} <- romans do
        [node] = parse_ast(pattern)
        assert node.value == pattern
        assert node.params.harmony_type == expected_type
        assert node.params.harmony_value == expected_value
      end
    end

    test "parses roman numerals with qualities and alterations" do
      romans = [
        {"@ii7", "ii7"},
        {"@V7b9", "V7b9"},
        {"@bVII", "bVII"},
        {"@#IV", "#IV"},
        {"@Imaj7", "Imaj7"}
      ]

      for {pattern, expected_value} <- romans do
        [node] = parse_ast(pattern)
        assert node.params.harmony_type == :roman
        assert node.params.harmony_value == expected_value
      end
    end

    test "parses two-five-one progression" do
      nodes = parse_ast("@ii7 @V7 @Imaj7")

      assert length(nodes) == 3
      assert Enum.map(nodes, & &1.params.harmony_value) == ["ii7", "V7", "Imaj7"]
    end
  end

  describe "jazz tokens in subdivisions" do
    test "degrees in brackets maintain jazz params" do
      [subdivision] = parse_ast("[^1 ^3 ^5]")
      assert subdivision.type == :subdivision
      [sequence: children] = subdivision.children

      assert length(children) == 3
      assert Enum.all?(children, &(&1.params.harmony_type == :degree))
    end

    test "chords in brackets maintain jazz params" do
      [subdivision] = parse_ast("[@Dm7 @G7]")
      assert subdivision.type == :subdivision
      [sequence: children] = subdivision.children

      assert length(children) == 2
      assert Enum.all?(children, &(&1.params.harmony_type == :chord))
    end

    test "romans in brackets maintain jazz params" do
      [subdivision] = parse_ast("[@ii @V @I]")
      assert subdivision.type == :subdivision
      [sequence: children] = subdivision.children

      assert length(children) == 3
      assert Enum.all?(children, &(&1.params.harmony_type == :roman))
    end
  end

  describe "mixed with regular sounds" do
    test "degrees interleaved with drum sounds" do
      nodes = parse_ast("^1 bd ^3 sd")

      assert length(nodes) == 4
      assert Enum.at(nodes, 0).params.harmony_type == :degree
      assert Enum.at(nodes, 1).value == "bd"
      assert Enum.at(nodes, 1).params == %{}
      assert Enum.at(nodes, 2).params.harmony_type == :degree
      assert Enum.at(nodes, 3).value == "sd"
    end

    test "chords with rests" do
      nodes = parse_ast("@ii ~ @V ~")

      jazz_nodes =
        Enum.filter(
          nodes,
          &(Map.has_key?(&1, :params) and Map.has_key?(&1.params, :harmony_type))
        )

      assert length(jazz_nodes) == 2
      # rests are in the AST
      rest_nodes = Enum.filter(nodes, &(&1.type == :rest))
      assert length(rest_nodes) == 2
    end
  end

  describe "edge cases" do
    test "bare @ and @number are regular sounds" do
      for pattern <- ["@", "@1", "@123"] do
        [node] = parse_ast(pattern)
        assert node.value == pattern
        assert node.params == %{}
      end
    end

    test "weight modifier bd@2 is not a jazz token" do
      [node] = parse_ast("bd@2")

      assert node.value == "bd"
      assert node.params == %{}
      # Weight is stored in the weight field, not params
      assert node.weight == 2
    end
  end
end
