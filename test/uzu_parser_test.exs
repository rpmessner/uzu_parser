defmodule UzuParserTest do
  use ExUnit.Case, async: true

  alias UzuParser
  alias UzuParser.Event

  describe "basic sequences" do
    test "parses simple space-separated sequence" do
      events = UzuParser.parse("bd sd hh sd")

      assert length(events) == 4
      assert [e1, e2, e3, e4] = events

      assert e1.sound == "bd"
      assert e1.time == 0.0
      assert_in_delta e1.duration, 0.25, 0.01

      assert e2.sound == "sd"
      assert_in_delta e2.time, 0.25, 0.01

      assert e3.sound == "hh"
      assert_in_delta e3.time, 0.5, 0.01

      assert e4.sound == "sd"
      assert_in_delta e4.time, 0.75, 0.01
    end

    test "parses single element" do
      events = UzuParser.parse("bd")

      assert length(events) == 1
      assert hd(events).sound == "bd"
      assert hd(events).time == 0.0
      assert_in_delta hd(events).duration, 1.0, 0.01
    end

    test "parses two elements" do
      events = UzuParser.parse("bd sd")

      assert length(events) == 2
      assert Enum.at(events, 0).time == 0.0
      assert_in_delta Enum.at(events, 1).time, 0.5, 0.01
    end

    test "handles extra whitespace" do
      events = UzuParser.parse("  bd   sd  ")

      assert length(events) == 2
      assert Enum.at(events, 0).sound == "bd"
      assert Enum.at(events, 1).sound == "sd"
    end

    test "returns empty list for empty pattern" do
      assert UzuParser.parse("") == []
      assert UzuParser.parse("   ") == []
    end
  end

  describe "rests" do
    test "parses rests with tilde" do
      events = UzuParser.parse("bd ~ sd ~")

      # Should only have 2 events (bd and sd), rests are omitted
      assert length(events) == 2
      assert Enum.at(events, 0).sound == "bd"
      assert Enum.at(events, 0).time == 0.0

      assert Enum.at(events, 1).sound == "sd"
      assert_in_delta Enum.at(events, 1).time, 0.5, 0.01
    end

    test "parses pattern with only rests" do
      events = UzuParser.parse("~ ~ ~ ~")
      assert events == []
    end

    test "parses pattern with rest at start" do
      events = UzuParser.parse("~ bd sd")

      assert length(events) == 2
      assert Enum.at(events, 0).sound == "bd"
      assert_in_delta Enum.at(events, 0).time, 0.333, 0.01
    end
  end

  describe "repetition" do
    test "parses simple repetition" do
      events = UzuParser.parse("bd*4")

      assert length(events) == 4
      assert Enum.all?(events, &(&1.sound == "bd"))
      assert Enum.at(events, 0).time == 0.0
      assert_in_delta Enum.at(events, 1).time, 0.25, 0.01
      assert_in_delta Enum.at(events, 2).time, 0.5, 0.01
      assert_in_delta Enum.at(events, 3).time, 0.75, 0.01
    end

    test "parses repetition in sequence" do
      events = UzuParser.parse("bd*2 sd")

      assert length(events) == 3
      assert Enum.at(events, 0).sound == "bd"
      assert Enum.at(events, 1).sound == "bd"
      assert Enum.at(events, 2).sound == "sd"

      assert Enum.at(events, 0).time == 0.0
      assert_in_delta Enum.at(events, 1).time, 0.333, 0.01
      assert_in_delta Enum.at(events, 2).time, 0.666, 0.01
    end

    test "handles invalid repetition gracefully" do
      # Invalid count should be treated as literal string
      events = UzuParser.parse("bd*abc")

      assert length(events) == 1
      assert hd(events).sound == "bd*abc"
    end

    test "handles zero repetition" do
      # Zero or negative repetition treated as literal
      events = UzuParser.parse("bd*0")

      assert length(events) == 1
      assert hd(events).sound == "bd*0"
    end
  end

  describe "subdivisions" do
    test "parses simple subdivision" do
      events = UzuParser.parse("bd [sd sd]")

      assert length(events) == 3
      assert Enum.at(events, 0).sound == "bd"
      assert Enum.at(events, 1).sound == "sd"
      assert Enum.at(events, 2).sound == "sd"

      assert Enum.at(events, 0).time == 0.0
      assert_in_delta Enum.at(events, 1).time, 0.333, 0.01
      assert_in_delta Enum.at(events, 2).time, 0.666, 0.01
    end

    test "parses subdivision with more elements" do
      events = UzuParser.parse("[bd sd hh sd]")

      assert length(events) == 4
      assert Enum.map(events, & &1.sound) == ["bd", "sd", "hh", "sd"]
    end

    test "parses mixed subdivision and regular" do
      events = UzuParser.parse("bd [sd hh] cp")

      assert length(events) == 4
      assert Enum.map(events, & &1.sound) == ["bd", "sd", "hh", "cp"]
    end

    test "parses subdivision with rests" do
      events = UzuParser.parse("[bd ~ sd ~]")

      assert length(events) == 2
      assert Enum.map(events, & &1.sound) == ["bd", "sd"]
    end
  end

  describe "complex patterns" do
    test "parses pattern with repetition and rests" do
      events = UzuParser.parse("bd*2 ~ sd")

      assert length(events) == 3
      assert Enum.at(events, 0).sound == "bd"
      assert Enum.at(events, 1).sound == "bd"
      assert Enum.at(events, 2).sound == "sd"
    end

    test "parses pattern with subdivision and repetition" do
      events = UzuParser.parse("bd [sd*2]")

      assert length(events) == 3
      assert Enum.map(events, & &1.sound) == ["bd", "sd", "sd"]
    end

    test "parses realistic drum pattern" do
      events = UzuParser.parse("bd sd [hh hh] sd")

      assert length(events) == 5
      assert Enum.map(events, & &1.sound) == ["bd", "sd", "hh", "hh", "sd"]

      # Check timing is evenly distributed
      assert Enum.at(events, 0).time == 0.0
      assert_in_delta Enum.at(events, 1).time, 0.2, 0.01
      assert_in_delta Enum.at(events, 2).time, 0.4, 0.01
      assert_in_delta Enum.at(events, 3).time, 0.6, 0.01
      assert_in_delta Enum.at(events, 4).time, 0.8, 0.01
    end

    test "parses complex layered pattern" do
      events = UzuParser.parse("bd*4 ~ [sd sd] ~")

      # bd appears 4 times, sd appears 2 times, 2 rests
      # Total of 8 steps, 6 events
      assert length(events) == 6
    end
  end

  describe "event properties" do
    test "events have correct structure" do
      [event | _] = UzuParser.parse("bd")

      assert %Event{} = event
      assert is_binary(event.sound)
      assert is_float(event.time)
      assert is_float(event.duration)
      assert is_map(event.params)
    end

    test "duration matches step size for simple sequence" do
      events = UzuParser.parse("bd sd hh sd")

      Enum.each(events, fn event ->
        assert_in_delta event.duration, 0.25, 0.01
      end)
    end

    test "all times are within 0.0 to 1.0 range" do
      events = UzuParser.parse("bd sd hh sd cp oh")

      Enum.each(events, fn event ->
        assert event.time >= 0.0
        assert event.time < 1.0
      end)
    end
  end
end
