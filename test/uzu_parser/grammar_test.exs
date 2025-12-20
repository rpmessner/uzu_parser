defmodule UzuParser.GrammarTest do
  @moduledoc """
  Tests for mini-notation grammar parsing.

  Covers: sequences, rests, subdivisions, modifiers, polyphony,
  alternation, polymetric, euclidean, parameters.
  """

  use ExUnit.Case, async: true

  # Helper: parse and get AST nodes from sequence
  defp parse_ast(pattern) do
    {:ok, {:sequence, nodes}} = UzuParser.parse(pattern)
    nodes
  end

  # Helper: just get parse result
  defp parse(pattern), do: UzuParser.parse(pattern)

  # ============================================================================
  # Basic Sequences
  # ============================================================================

  describe "basic sequences" do
    test "parses space-separated sounds" do
      nodes = parse_ast("bd sd hh")

      assert length(nodes) == 3
      assert Enum.map(nodes, & &1.value) == ["bd", "sd", "hh"]
      assert Enum.all?(nodes, &(&1.type == :atom))
    end

    test "empty string returns empty sequence" do
      assert {:ok, []} = parse("")
      assert {:ok, []} = parse("   ")
    end

    test "period is part of sound name (Strudel compatibility)" do
      # In Strudel, bd.sd.hh is ONE sound name, not three separate sounds
      nodes = parse_ast("bd.sd.hh")

      assert length(nodes) == 1
      assert hd(nodes).value == "bd.sd.hh"
    end

    test "handles various whitespace" do
      nodes = parse_ast("bd  sd\thh\ncp")
      assert length(nodes) == 4
    end
  end

  # ============================================================================
  # Rests
  # ============================================================================

  describe "rests" do
    test "parses single rest" do
      nodes = parse_ast("~")

      assert length(nodes) == 1
      assert hd(nodes).type == :rest
    end

    test "rests in sequence" do
      nodes = parse_ast("bd ~ sd")

      assert length(nodes) == 3
      assert Enum.at(nodes, 0).type == :atom
      assert Enum.at(nodes, 1).type == :rest
      assert Enum.at(nodes, 2).type == :atom
    end
  end

  # ============================================================================
  # Elongation
  # ============================================================================

  describe "elongation" do
    test "parses underscore as elongation" do
      nodes = parse_ast("bd _ sd")

      assert length(nodes) == 3
      assert Enum.at(nodes, 0).type == :atom
      assert Enum.at(nodes, 1).type == :elongation
      assert Enum.at(nodes, 2).type == :atom
    end

    test "multiple elongations" do
      nodes = parse_ast("bd _ _ _")

      elongations = Enum.filter(nodes, &(&1.type == :elongation))
      assert length(elongations) == 3
    end

    test "underscore in sound name is not elongation" do
      nodes = parse_ast("kick_drum snare_hit")

      assert length(nodes) == 2
      assert Enum.all?(nodes, &(&1.type == :atom))
      assert Enum.map(nodes, & &1.value) == ["kick_drum", "snare_hit"]
    end
  end

  # ============================================================================
  # Subdivisions
  # ============================================================================

  describe "subdivisions" do
    test "parses basic subdivision" do
      nodes = parse_ast("[bd sd]")

      assert length(nodes) == 1
      assert hd(nodes).type == :subdivision
    end

    test "nested subdivisions" do
      nodes = parse_ast("[[bd sd] hh]")

      assert length(nodes) == 1
      assert hd(nodes).type == :subdivision
    end

    test "subdivision with repetition" do
      nodes = parse_ast("[bd sd]*2")

      assert length(nodes) == 1
      assert hd(nodes).type == :subdivision
      assert hd(nodes).repeat == 2
    end

    test "subdivision with division" do
      nodes = parse_ast("[bd sd]/2")

      assert length(nodes) == 1
      assert hd(nodes).type == :subdivision
      assert hd(nodes).division == 2
    end
  end

  # ============================================================================
  # Modifiers
  # ============================================================================

  describe "sample selection" do
    test "parses sample number" do
      nodes = parse_ast("bd:1 sd:2")

      assert length(nodes) == 2
      assert Enum.at(nodes, 0).sample == 1
      assert Enum.at(nodes, 1).sample == 2
    end

    test "sample with other modifiers" do
      nodes = parse_ast("bd:1*2")

      assert length(nodes) == 1
      assert hd(nodes).sample == 1
      assert hd(nodes).repeat == 2
    end
  end

  describe "repetition" do
    test "parses asterisk repetition" do
      nodes = parse_ast("bd*4")

      assert length(nodes) == 1
      assert hd(nodes).repeat == 4
    end
  end

  describe "replication" do
    test "parses exclamation replication" do
      nodes = parse_ast("bd!3")

      assert length(nodes) == 1
      assert hd(nodes).replicate == 3
    end
  end

  describe "probability" do
    test "parses default probability" do
      nodes = parse_ast("bd?")

      assert length(nodes) == 1
      assert hd(nodes).probability == 0.5
    end

    test "parses custom probability" do
      nodes = parse_ast("bd?0.25")

      assert length(nodes) == 1
      assert hd(nodes).probability == 0.25
    end
  end

  describe "weight" do
    test "parses integer weight" do
      nodes = parse_ast("bd@2")

      assert length(nodes) == 1
      assert hd(nodes).weight == 2
    end

    test "parses float weight" do
      nodes = parse_ast("bd@1.5")

      assert length(nodes) == 1
      assert hd(nodes).weight == 1.5
    end
  end

  describe "division" do
    test "parses division modifier" do
      nodes = parse_ast("bd/2")

      assert length(nodes) == 1
      assert hd(nodes).division == 2
    end
  end

  # ============================================================================
  # Euclidean
  # ============================================================================

  describe "euclidean rhythms" do
    test "parses basic euclidean" do
      nodes = parse_ast("bd(3,8)")

      assert length(nodes) == 1
      assert hd(nodes).euclidean == [3, 8]
    end

    test "parses euclidean with offset" do
      nodes = parse_ast("bd(3,8,2)")

      assert length(nodes) == 1
      assert hd(nodes).euclidean == [3, 8, 2]
    end
  end

  # ============================================================================
  # Sound Parameters
  # ============================================================================

  describe "sound parameters" do
    test "parses single parameter" do
      nodes = parse_ast("bd|gain:0.5")

      assert length(nodes) == 1
      assert hd(nodes).params == %{gain: 0.5}
    end

    test "parses multiple parameters" do
      nodes = parse_ast("bd|gain:0.5|speed:2")

      assert length(nodes) == 1
      assert hd(nodes).params == %{gain: 0.5, speed: 2.0}
    end

    test "parses negative parameter" do
      nodes = parse_ast("bd|pan:-0.5")

      assert length(nodes) == 1
      assert hd(nodes).params == %{pan: -0.5}
    end
  end

  # ============================================================================
  # Polyphony (Commas)
  # ============================================================================

  describe "polyphony" do
    test "parses chord notation" do
      {:ok, {:sequence, [subdivision]}} = parse("[bd,sd]")

      assert subdivision.type == :subdivision
      assert [stack: _layers] = subdivision.children
    end

    test "parses three-element chord" do
      {:ok, {:sequence, [subdivision]}} = parse("[bd,sd,hh]")

      assert subdivision.type == :subdivision
    end
  end

  # ============================================================================
  # Alternation
  # ============================================================================

  describe "alternation" do
    test "parses basic alternation" do
      nodes = parse_ast("<bd sd>")

      assert length(nodes) == 1
      assert hd(nodes).type == :alternation
    end

    test "nested alternation" do
      nodes = parse_ast("<<a b> c>")

      assert length(nodes) == 1
      assert hd(nodes).type == :alternation
    end
  end

  # ============================================================================
  # Polymetric
  # ============================================================================

  describe "polymetric" do
    test "parses basic polymetric" do
      nodes = parse_ast("{bd sd, hh}")

      assert length(nodes) == 1
      assert hd(nodes).type == :polymetric
    end

    test "parses polymetric with step count" do
      nodes = parse_ast("{bd sd}%4")

      assert length(nodes) == 1
      assert hd(nodes).type == :polymetric
      assert hd(nodes).steps == 4
    end
  end

  # ============================================================================
  # Random Choice
  # ============================================================================

  describe "random choice" do
    test "parses pipe-separated random choice" do
      nodes = parse_ast("bd|sd|hh")

      assert length(nodes) == 1
      assert hd(nodes).type == :random_choice
    end
  end

  # ============================================================================
  # Source Positions
  # ============================================================================

  describe "source positions" do
    test "tracks positions for basic sounds" do
      nodes = parse_ast("bd sd")

      [bd, sd] = nodes
      assert bd.source_start == 0
      assert bd.source_end == 2
      assert sd.source_start == 3
      assert sd.source_end == 5
    end

    test "tracks positions for sounds with modifiers" do
      nodes = parse_ast("bd:1 sd:2")

      [bd, sd] = nodes
      assert bd.source_end == 4
      assert sd.source_end == 9
    end
  end
end
