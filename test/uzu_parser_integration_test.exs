defmodule UzuParser.IntegrationTest do
  @moduledoc """
  Integration tests for UzuParser.parse/1.

  These tests verify end-to-end behavior of the parser by testing
  complete patterns through the public API. Module-specific unit tests
  are located in test/uzu_parser/*.

  Focus: realistic patterns, feature combinations, edge cases that span modules.
  """

  use ExUnit.Case, async: true

  alias UzuParser
  alias UzuParser.Event

  describe "basic parsing" do
    test "parses space-separated sequence with correct timing" do
      events = UzuParser.parse("bd sd hh sd")

      assert length(events) == 4
      assert Enum.map(events, & &1.sound) == ["bd", "sd", "hh", "sd"]
      assert Enum.at(events, 0).time == 0.0
      assert_in_delta Enum.at(events, 3).time, 0.75, 0.01
      assert Enum.all?(events, &(&1.duration == 0.25))
    end

    test "handles empty and whitespace patterns" do
      assert UzuParser.parse("") == []
      assert UzuParser.parse("   ") == []
    end

    test "rests occupy time but produce no events" do
      events = UzuParser.parse("bd ~ sd ~")

      assert length(events) == 2
      assert Enum.at(events, 0).time == 0.0
      assert_in_delta Enum.at(events, 1).time, 0.5, 0.01
    end
  end

  describe "subdivisions and nesting" do
    test "subdivisions split time within their slot" do
      events = UzuParser.parse("bd [sd hh] cp")

      assert length(events) == 4
      assert Enum.map(events, & &1.sound) == ["bd", "sd", "hh", "cp"]
    end

    test "nested brackets work correctly" do
      events = UzuParser.parse("[[bd sd] hh]")

      assert length(events) == 3
      assert Enum.map(events, & &1.sound) == ["bd", "sd", "hh"]
    end

    test "subdivision repetition [bd sd]*2" do
      events = UzuParser.parse("[bd sd]*2")

      assert length(events) == 4
      assert Enum.map(events, & &1.sound) == ["bd", "sd", "bd", "sd"]
    end

    test "long subdivision parses efficiently" do
      long_pattern = "bd [" <> String.duplicate("hh ", 50) <> "]"
      events = UzuParser.parse(long_pattern)

      assert length(events) == 51
    end
  end

  describe "polyphony (chords)" do
    test "comma creates simultaneous events" do
      events = UzuParser.parse("[bd,sd,hh]")

      assert length(events) == 3
      assert Enum.all?(events, &(&1.time == 0.0))
    end

    test "chords in sequence" do
      events = UzuParser.parse("bd [sd,hh] cp")

      assert length(events) == 4
      sd = Enum.find(events, &(&1.sound == "sd"))
      hh = Enum.find(events, &(&1.sound == "hh"))
      assert sd.time == hh.time
    end

    test "nested polyphony [[bd,sd] hh]" do
      events = UzuParser.parse("[[bd,sd] hh]")

      assert length(events) == 3
      bd = Enum.find(events, &(&1.sound == "bd"))
      sd = Enum.find(events, &(&1.sound == "sd"))
      assert_in_delta bd.time, sd.time, 0.01
    end
  end

  describe "polymetric sequences" do
    test "groups have independent timing" do
      events = UzuParser.parse("{bd sd hh, cp}")

      assert length(events) == 4
      cp = Enum.find(events, &(&1.sound == "cp"))
      assert_in_delta cp.duration, 1.0, 0.01
    end

    test "polymetric step control {bd sd}%4" do
      events = UzuParser.parse("{bd sd}%4")

      assert length(events) == 2
      assert Enum.all?(events, fn e -> abs(e.duration - 0.25) < 0.01 end)
    end
  end

  describe "feature combinations" do
    test "sample selection with repetition" do
      events = UzuParser.parse("bd:1*3")

      assert length(events) == 3
      assert Enum.all?(events, &(&1.sound == "bd" and &1.sample == 1))
    end

    test "probability in subdivisions" do
      events = UzuParser.parse("[bd? sd hh?0.25]")

      assert length(events) == 3
      assert Enum.at(events, 0).params == %{probability: 0.5}
      assert Enum.at(events, 1).params == %{}
      assert Enum.at(events, 2).params == %{probability: 0.25}
    end

    test "weight affects duration distribution" do
      events = UzuParser.parse("bd@2 sd")

      assert length(events) == 2
      assert_in_delta Enum.at(events, 0).duration, 0.666, 0.01
      assert_in_delta Enum.at(events, 1).duration, 0.333, 0.01
    end

    test "elongation _ extends previous sound" do
      events = UzuParser.parse("bd _ _ sd")

      assert length(events) == 2
      assert_in_delta Enum.at(events, 0).duration, 0.75, 0.01
    end

    test "random choice in sequence" do
      events = UzuParser.parse("bd|sd hh")

      assert length(events) == 2
      assert Map.has_key?(Enum.at(events, 0).params, :random_choice)
      assert Enum.at(events, 1).params == %{}
    end

    test "alternation in sequence" do
      events = UzuParser.parse("<bd sd> hh cp")

      assert length(events) == 3
      assert Map.has_key?(Enum.at(events, 0).params, :alternate)
    end

    test "sound parameters pass through" do
      events = UzuParser.parse("bd|gain:0.8|speed:2")

      assert length(events) == 1
      assert hd(events).params == %{gain: 0.8, speed: 2.0}
    end

    test "euclidean rhythm in sequence" do
      events = UzuParser.parse("hh bd(3,8)")

      assert length(events) == 4
      assert Enum.at(events, 0).sound == "hh"
    end

    test "division applies to subdivision [bd sd]/2" do
      events = UzuParser.parse("[bd sd]/2")

      assert length(events) == 2
      assert Enum.all?(events, &(&1.params == %{division: 2.0}))
    end

    test "chord with division [bd,sd]/4" do
      events = UzuParser.parse("[bd,sd]/4")

      assert length(events) == 2
      assert Enum.all?(events, &(&1.params == %{division: 4.0}))
      assert Enum.at(events, 0).time == Enum.at(events, 1).time
    end
  end

  describe "realistic drum patterns" do
    test "basic four-on-the-floor" do
      events = UzuParser.parse("bd sd bd sd")

      assert length(events) == 4
      assert_in_delta Enum.at(events, 0).duration, 0.25, 0.01
    end

    test "hihat subdivisions" do
      events = UzuParser.parse("bd [hh hh] sd [hh hh]")

      assert length(events) == 6
    end

    test "layered kick and hihat" do
      events = UzuParser.parse("[bd,hh] [~,hh] [sd,hh] [~,hh]")

      assert length(events) == 6
    end

    test "euclidean clave pattern" do
      events = UzuParser.parse("cp(3,8)")

      assert length(events) == 3
    end

    test "polyrhythm 3 against 4" do
      events = UzuParser.parse("{bd bd bd bd, cp cp cp}")

      assert length(events) == 7
    end
  end

  describe "shorthand separator" do
    test "period works as separator" do
      events = UzuParser.parse("bd.sd.hh")

      assert length(events) == 3
      assert Enum.map(events, & &1.sound) == ["bd", "sd", "hh"]
    end

    test "period does not break decimal numbers" do
      events = UzuParser.parse("bd|gain:0.8")

      assert hd(events).params == %{gain: 0.8}
    end
  end

  describe "event structure" do
    test "events have all required fields" do
      [event | _] = UzuParser.parse("bd:1")

      assert %Event{} = event
      assert is_binary(event.sound)
      assert is_float(event.time)
      assert is_float(event.duration)
      assert is_map(event.params)
      assert event.sample == 1
    end

    test "times are within cycle bounds" do
      events = UzuParser.parse("bd sd hh cp oh rim")

      Enum.each(events, fn event ->
        assert event.time >= 0.0
        assert event.time < 1.0
      end)
    end
  end
end
