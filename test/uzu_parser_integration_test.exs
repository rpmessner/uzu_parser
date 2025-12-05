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

  describe "source position tracking" do
    test "simple sequence has correct positions" do
      events = UzuParser.parse("bd sd")

      [bd, sd] = events
      # "bd sd"
      #  01 34
      assert bd.source_start == 0
      assert bd.source_end == 2
      assert sd.source_start == 3
      assert sd.source_end == 5
    end

    test "positions map to correct substrings" do
      pattern = "bd sd hh"
      events = UzuParser.parse(pattern)

      Enum.each(events, fn event ->
        substring = String.slice(pattern, event.source_start, event.source_end - event.source_start)
        assert substring == event.sound, "Expected #{event.sound} at [#{event.source_start}:#{event.source_end}], got '#{substring}'"
      end)
    end

    test "subdivision preserves inner positions" do
      pattern = "[bd sd]"
      events = UzuParser.parse(pattern)

      [bd, sd] = events
      # "[bd sd]"
      #  0123456
      assert bd.source_start == 1
      assert bd.source_end == 3
      assert sd.source_start == 4
      assert sd.source_end == 6

      # Verify they map correctly
      assert String.slice(pattern, bd.source_start, bd.source_end - bd.source_start) == "bd"
      assert String.slice(pattern, sd.source_start, sd.source_end - sd.source_start) == "sd"
    end

    test "nested subdivision tracks each token individually" do
      pattern = "[[bd] hh]"
      events = UzuParser.parse(pattern)

      [bd, hh] = events
      # "[[bd] hh]"
      #  012345678
      assert bd.source_start == 2
      assert bd.source_end == 4
      assert hh.source_start == 6
      assert hh.source_end == 8

      assert String.slice(pattern, bd.source_start, bd.source_end - bd.source_start) == "bd"
      assert String.slice(pattern, hh.source_start, hh.source_end - hh.source_start) == "hh"
    end

    test "mixed pattern with subdivision" do
      pattern = "bd [sd hh] cp"
      events = UzuParser.parse(pattern)

      [bd, sd, hh, cp] = events
      # "bd [sd hh] cp"
      #  01234567890123
      assert bd.source_start == 0
      assert bd.source_end == 2
      assert sd.source_start == 4
      assert sd.source_end == 6
      assert hh.source_start == 7
      assert hh.source_end == 9
      assert cp.source_start == 11
      assert cp.source_end == 13
    end

    test "division operator preserves positions" do
      pattern = "[sd sd]/2"
      events = UzuParser.parse(pattern)

      [sd1, sd2] = events
      # "[sd sd]/2"
      #  012345678
      assert sd1.source_start == 1
      assert sd1.source_end == 3
      assert sd2.source_start == 4
      assert sd2.source_end == 6
    end

    test "deeply nested subdivisions" do
      pattern = "[[[bd]]]"
      events = UzuParser.parse(pattern)

      [bd] = events
      # "[[[bd]]]"
      #  01234567
      assert bd.source_start == 3
      assert bd.source_end == 5
      assert String.slice(pattern, bd.source_start, bd.source_end - bd.source_start) == "bd"
    end

    test "multiple nested subdivisions" do
      pattern = "[[bd sd] [hh cp]]"
      events = UzuParser.parse(pattern)

      assert length(events) == 4
      [bd, sd, hh, cp] = events

      # "[[bd sd] [hh cp]]"
      #  01234567890123456
      assert String.slice(pattern, bd.source_start, bd.source_end - bd.source_start) == "bd"
      assert String.slice(pattern, sd.source_start, sd.source_end - sd.source_start) == "sd"
      assert String.slice(pattern, hh.source_start, hh.source_end - hh.source_start) == "hh"
      assert String.slice(pattern, cp.source_start, cp.source_end - cp.source_start) == "cp"
    end

    test "sample selection has correct positions" do
      pattern = "bd:0 sd:1"
      events = UzuParser.parse(pattern)

      [bd, sd] = events
      # "bd:0 sd:1"
      #  012345678
      assert bd.source_start == 0
      assert bd.source_end == 4
      assert sd.source_start == 5
      assert sd.source_end == 9
    end
  end
end
