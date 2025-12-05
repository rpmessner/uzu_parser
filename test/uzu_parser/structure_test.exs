defmodule UzuParser.StructureTest do
  use ExUnit.Case, async: true

  alias UzuParser.Structure
  alias UzuParser.TokenParser

  # Helper to simulate simple tokenization (accepts offset for position tracking)
  defp simple_tokenize(str, _offset \\ 0) do
    str
    |> String.split()
    |> Enum.map(&TokenParser.parse/1)
    |> Enum.reject(&is_nil/1)
  end

  # Helper to flatten tokens (for chord sounds)
  defp flatten_token({:repeat, items}), do: items
  defp flatten_token(token), do: [token]

  describe "parse_subdivision/4" do
    test "parses simple subdivision" do
      result = Structure.parse_subdivision("bd sd", 0, &simple_tokenize/2, &flatten_token/1)

      assert {:subdivision, tokens} = result
      assert length(tokens) == 2
      assert Enum.at(tokens, 0) == {:sound, "bd", nil, nil, nil}
      assert Enum.at(tokens, 1) == {:sound, "sd", nil, nil, nil}
    end

    test "parses subdivision with multiple tokens" do
      result = Structure.parse_subdivision("bd sd hh cp", 0, &simple_tokenize/2, &flatten_token/1)

      assert {:subdivision, tokens} = result
      assert length(tokens) == 4
    end

    test "parses chord with comma separator" do
      result = Structure.parse_subdivision("bd,sd", 0, &simple_tokenize/2, &flatten_token/1)

      assert {:subdivision, [{:chord, sounds}]} = result
      assert length(sounds) == 2
      assert Enum.at(sounds, 0) == {:sound, "bd", nil, nil, nil}
      assert Enum.at(sounds, 1) == {:sound, "sd", nil, nil, nil}
    end

    test "parses chord with three sounds" do
      result = Structure.parse_subdivision("bd,sd,hh", 0, &simple_tokenize/2, &flatten_token/1)

      assert {:subdivision, [{:chord, sounds}]} = result
      assert length(sounds) == 3
    end

    test "parses chord with sample selection" do
      result = Structure.parse_subdivision("bd:0,sd:1", 0, &simple_tokenize/2, &flatten_token/1)

      assert {:subdivision, [{:chord, sounds}]} = result
      assert Enum.at(sounds, 0) == {:sound, "bd", 0, nil, nil}
      assert Enum.at(sounds, 1) == {:sound, "sd", 1, nil, nil}
    end

    test "filters out nil tokens from tokenizer" do
      # Tokenizer might return nil for empty strings
      tokenizer = fn str, _offset ->
        str
        |> String.split()
        |> Enum.map(fn
          "" -> nil
          token -> TokenParser.parse(token)
        end)
      end

      result = Structure.parse_subdivision("bd  sd", 0, tokenizer, &flatten_token/1)

      assert {:subdivision, tokens} = result
      refute nil in tokens
    end

    test "handles rests in subdivisions" do
      result = Structure.parse_subdivision("bd ~ sd", 0, &simple_tokenize/2, &flatten_token/1)

      assert {:subdivision, tokens} = result
      assert length(tokens) == 3
      assert Enum.at(tokens, 1) == :rest
    end

    test "flattens repetition in chord" do
      result = Structure.parse_subdivision("bd*2,sd", 0, &simple_tokenize/2, &flatten_token/1)

      assert {:subdivision, [{:chord, sounds}]} = result
      assert length(sounds) == 3
    end
  end

  describe "parse_alternation/1" do
    test "parses two options" do
      result = Structure.parse_alternation("bd sd")

      assert {:alternate, options} = result
      assert length(options) == 2
      assert Enum.at(options, 0) == {:sound, "bd", nil, nil, nil}
      assert Enum.at(options, 1) == {:sound, "sd", nil, nil, nil}
    end

    test "parses three options" do
      result = Structure.parse_alternation("bd sd hh")

      assert {:alternate, options} = result
      assert length(options) == 3
    end

    test "single option returns the sound directly" do
      result = Structure.parse_alternation("bd")

      assert {:sound, "bd", nil, nil, nil} = result
    end

    test "empty returns nil" do
      result = Structure.parse_alternation("")
      assert result == nil
    end

    test "parses options with sample selection" do
      result = Structure.parse_alternation("bd:0 sd:1 hh:2")

      assert {:alternate, options} = result
      assert Enum.at(options, 0) == {:sound, "bd", 0, nil, nil}
      assert Enum.at(options, 1) == {:sound, "sd", 1, nil, nil}
      assert Enum.at(options, 2) == {:sound, "hh", 2, nil, nil}
    end

    test "parses options with probability" do
      result = Structure.parse_alternation("bd? sd")

      assert {:alternate, options} = result
      assert {:sound, "bd", nil, 0.5, nil} = Enum.at(options, 0)
      assert {:sound, "sd", nil, nil, nil} = Enum.at(options, 1)
    end

    test "handles extra whitespace" do
      result = Structure.parse_alternation("  bd   sd  ")

      assert {:alternate, options} = result
      assert length(options) == 2
    end
  end

  describe "parse_polymetric/2" do
    test "parses two groups" do
      result = Structure.parse_polymetric("bd sd, cp", &simple_tokenize/1)

      assert {:polymetric, groups} = result
      assert length(groups) == 2
      assert length(Enum.at(groups, 0)) == 2
      assert length(Enum.at(groups, 1)) == 1
    end

    test "parses three groups" do
      result = Structure.parse_polymetric("bd, sd, hh", &simple_tokenize/1)

      assert {:polymetric, groups} = result
      assert length(groups) == 3
    end

    test "single group returns subdivision" do
      result = Structure.parse_polymetric("bd sd hh", &simple_tokenize/1)

      assert {:subdivision, tokens} = result
      assert length(tokens) == 3
    end

    test "empty returns nil" do
      result = Structure.parse_polymetric("", &simple_tokenize/1)
      assert result == nil
    end

    test "handles groups with different lengths" do
      result = Structure.parse_polymetric("bd sd hh, cp", &simple_tokenize/1)

      assert {:polymetric, groups} = result
      assert length(Enum.at(groups, 0)) == 3
      assert length(Enum.at(groups, 1)) == 1
    end

    test "handles sample selection in groups" do
      result = Structure.parse_polymetric("bd:0 sd:1, cp:2", &simple_tokenize/1)

      assert {:polymetric, groups} = result
      [group1, group2] = groups
      assert Enum.at(group1, 0) == {:sound, "bd", 0, nil, nil}
      assert Enum.at(group2, 0) == {:sound, "cp", 2, nil, nil}
    end

    test "filters out empty groups" do
      result = Structure.parse_polymetric("bd sd, , hh", &simple_tokenize/1)

      assert {:polymetric, groups} = result
      assert length(groups) == 2
    end

    test "handles rests in groups" do
      result = Structure.parse_polymetric("bd ~ sd, cp", &simple_tokenize/1)

      assert {:polymetric, groups} = result
      [group1, _group2] = groups
      assert :rest in group1
    end
  end
end
