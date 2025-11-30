defmodule UzuParser.IntegrationTest do
  @moduledoc """
  Integration tests for UzuParser.parse/1.

  These tests verify end-to-end behavior of the parser by testing
  complete patterns through the public API. Module-specific unit tests
  are located in test/uzu_parser/*.
  """

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

    test "parses subdivision repetition [bd sd]*2" do
      events = UzuParser.parse("[bd sd]*2")

      assert length(events) == 4
      assert Enum.map(events, & &1.sound) == ["bd", "sd", "bd", "sd"]
      assert_in_delta Enum.at(events, 0).duration, 0.25, 0.01
      assert_in_delta Enum.at(events, 0).time, 0.0, 0.01
      assert_in_delta Enum.at(events, 1).time, 0.25, 0.01
      assert_in_delta Enum.at(events, 2).time, 0.5, 0.01
      assert_in_delta Enum.at(events, 3).time, 0.75, 0.01
    end

    test "parses subdivision repetition [bd hh sd]*3" do
      events = UzuParser.parse("[bd hh sd]*3")

      assert length(events) == 9

      assert Enum.map(events, & &1.sound) == [
               "bd",
               "hh",
               "sd",
               "bd",
               "hh",
               "sd",
               "bd",
               "hh",
               "sd"
             ]
    end

    test "parses subdivision repetition in sequence" do
      events = UzuParser.parse("bd [sd hh]*2")

      assert length(events) == 5
      assert Enum.map(events, & &1.sound) == ["bd", "sd", "hh", "sd", "hh"]
    end

    test "parses nested brackets [[bd sd] hh]" do
      events = UzuParser.parse("[[bd sd] hh]")

      assert length(events) == 3
      assert Enum.map(events, & &1.sound) == ["bd", "sd", "hh"]
      assert_in_delta Enum.at(events, 0).duration, 0.333, 0.01
    end

    test "parses nested polyphony inside bracket [[bd,sd] hh]" do
      events = UzuParser.parse("[[bd,sd] hh]")

      assert length(events) == 3
      # bd and sd play together, then hh
      bd = Enum.find(events, &(&1.sound == "bd"))
      sd = Enum.find(events, &(&1.sound == "sd"))
      hh = Enum.find(events, &(&1.sound == "hh"))

      assert_in_delta bd.time, sd.time, 0.01
      assert_in_delta hh.time, 0.5, 0.01
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

    test "parses multiple sequential subdivisions efficiently" do
      # This tests the performance fix - multiple subdivisions should parse quickly
      events = UzuParser.parse("bd [sd hh] cp [oh ch]")

      assert length(events) == 6
      assert Enum.map(events, & &1.sound) == ["bd", "sd", "hh", "cp", "oh", "ch"]
    end

    test "parses long subdivision content efficiently" do
      # Tests performance fix with long strings inside brackets
      long_pattern = "bd [" <> String.duplicate("hh ", 50) <> "]"
      events = UzuParser.parse(long_pattern)

      assert length(events) == 51
      assert hd(events).sound == "bd"
      assert Enum.drop(events, 1) |> Enum.all?(&(&1.sound == "hh"))
    end
  end

  describe "sample selection" do
    test "parses simple sample selection" do
      events = UzuParser.parse("bd:0 sd:1 hh:2")

      assert length(events) == 3
      assert Enum.at(events, 0).sound == "bd"
      assert Enum.at(events, 0).sample == 0

      assert Enum.at(events, 1).sound == "sd"
      assert Enum.at(events, 1).sample == 1

      assert Enum.at(events, 2).sound == "hh"
      assert Enum.at(events, 2).sample == 2
    end

    test "parses mixed samples and non-samples" do
      events = UzuParser.parse("bd:1 sd hh:0")

      assert length(events) == 3
      assert Enum.at(events, 0).sample == 1
      assert Enum.at(events, 1).sample == nil
      assert Enum.at(events, 2).sample == 0
    end

    test "parses sample selection with repetition" do
      events = UzuParser.parse("bd:1*3")

      assert length(events) == 3
      assert Enum.all?(events, &(&1.sound == "bd"))
      assert Enum.all?(events, &(&1.sample == 1))
    end

    test "parses sample selection in subdivisions" do
      events = UzuParser.parse("[bd:0 sd:1]")

      assert length(events) == 2
      assert Enum.at(events, 0).sound == "bd"
      assert Enum.at(events, 0).sample == 0
      assert Enum.at(events, 1).sound == "sd"
      assert Enum.at(events, 1).sample == 1
    end

    test "handles invalid sample numbers gracefully" do
      events = UzuParser.parse("bd:abc")

      assert length(events) == 1
      # Invalid sample number should be treated as part of sound name
      assert hd(events).sound == "bd:abc"
      assert hd(events).sample == nil
    end

    test "handles negative sample numbers gracefully" do
      events = UzuParser.parse("bd:-1")

      assert length(events) == 1
      assert hd(events).sound == "bd:-1"
      assert hd(events).sample == nil
    end
  end

  describe "polyphony" do
    test "parses simple chord" do
      events = UzuParser.parse("[bd,sd]")

      assert length(events) == 2
      assert Enum.at(events, 0).sound == "bd"
      assert Enum.at(events, 1).sound == "sd"
      # Both events should have the same time (polyphony)
      assert Enum.at(events, 0).time == Enum.at(events, 1).time
      assert Enum.at(events, 0).time == 0.0
    end

    test "parses chord with three sounds" do
      events = UzuParser.parse("[bd,sd,hh]")

      assert length(events) == 3
      assert Enum.map(events, & &1.sound) == ["bd", "sd", "hh"]
      # All three should have the same time
      assert Enum.all?(events, &(&1.time == 0.0))
    end

    test "parses chord with sample selection" do
      events = UzuParser.parse("[bd:0,sd:1,hh:2]")

      assert length(events) == 3
      assert Enum.all?(events, &(&1.time == 0.0))
      assert Enum.at(events, 0).sample == 0
      assert Enum.at(events, 1).sample == 1
      assert Enum.at(events, 2).sample == 2
    end

    test "parses chord in sequence" do
      events = UzuParser.parse("bd [sd,hh] cp")

      assert length(events) == 4
      assert Enum.map(events, & &1.sound) == ["bd", "sd", "hh", "cp"]

      # bd at 0.0
      assert Enum.at(events, 0).time == 0.0

      # sd and hh at same time (~0.333)
      sd_time = Enum.at(events, 1).time
      hh_time = Enum.at(events, 2).time
      assert_in_delta sd_time, 0.333, 0.01
      assert sd_time == hh_time

      # cp at ~0.666
      assert_in_delta Enum.at(events, 3).time, 0.666, 0.01
    end

    test "parses chord with repetition inside subdivision" do
      # Note: [bd,sd]*2 syntax has a known limitation with subdivision repetition
      # Using bd*2 within chord works correctly
      events = UzuParser.parse("[bd*2,sd]")

      assert length(events) == 3
      # bd appears twice, sd appears once, all at same time
      assert Enum.at(events, 0).sound == "bd"
      assert Enum.at(events, 1).sound == "bd"
      assert Enum.at(events, 2).sound == "sd"
      # All three events at the same time (polyphony)
      assert Enum.at(events, 0).time == Enum.at(events, 1).time
      assert Enum.at(events, 0).time == Enum.at(events, 2).time
    end

    test "parses multiple chords in sequence" do
      events = UzuParser.parse("[bd,sd] [hh,cp]")

      assert length(events) == 4
      # First chord at 0.0
      assert Enum.at(events, 0).time == Enum.at(events, 1).time
      assert Enum.at(events, 0).time == 0.0

      # Second chord at 0.5
      assert Enum.at(events, 2).time == Enum.at(events, 3).time
      assert_in_delta Enum.at(events, 2).time, 0.5, 0.01
    end

    test "parses chord with rests" do
      events = UzuParser.parse("[bd,~,sd]")

      # Rests should be ignored, so only 2 events
      assert length(events) == 2
      assert Enum.map(events, & &1.sound) == ["bd", "sd"]
      assert Enum.at(events, 0).time == Enum.at(events, 1).time
    end

    test "parses chord mixed with regular sounds" do
      events = UzuParser.parse("bd [cp,oh] hh [sd,bd]")

      assert length(events) == 6
      assert Enum.map(events, & &1.sound) == ["bd", "cp", "oh", "hh", "sd", "bd"]

      # First bd alone
      assert Enum.at(events, 0).time == 0.0

      # cp and oh together
      assert Enum.at(events, 1).time == Enum.at(events, 2).time

      # hh alone
      hh_time = Enum.at(events, 3).time
      assert hh_time != Enum.at(events, 2).time
      assert hh_time != Enum.at(events, 4).time

      # sd and bd together
      assert Enum.at(events, 4).time == Enum.at(events, 5).time
    end
  end

  describe "random removal (probability)" do
    test "parses sound with default probability" do
      events = UzuParser.parse("bd?")

      assert length(events) == 1
      event = hd(events)
      assert event.sound == "bd"
      assert event.params == %{probability: 0.5}
    end

    test "parses sound with custom probability" do
      events = UzuParser.parse("bd?0.25")

      assert length(events) == 1
      event = hd(events)
      assert event.sound == "bd"
      assert event.params == %{probability: 0.25}
    end

    test "parses sound with high probability" do
      events = UzuParser.parse("bd?0.9")

      assert length(events) == 1
      event = hd(events)
      assert event.params == %{probability: 0.9}
    end

    test "parses mixed probabilistic and non-probabilistic sounds" do
      events = UzuParser.parse("bd sd? hh")

      assert length(events) == 3
      assert Enum.at(events, 0).params == %{}
      assert Enum.at(events, 1).params == %{probability: 0.5}
      assert Enum.at(events, 2).params == %{}
    end

    test "parses probability with sample selection" do
      events = UzuParser.parse("bd:0?")

      assert length(events) == 1
      event = hd(events)
      assert event.sound == "bd"
      assert event.sample == 0
      assert event.params == %{probability: 0.5}
    end

    test "parses probability with sample selection and custom value" do
      events = UzuParser.parse("bd:1?0.75")

      assert length(events) == 1
      event = hd(events)
      assert event.sound == "bd"
      assert event.sample == 1
      assert event.params == %{probability: 0.75}
    end

    test "parses probability with repetition" do
      events = UzuParser.parse("bd*3?")

      assert length(events) == 3
      # All three events should have probability
      assert Enum.all?(events, &(&1.params == %{probability: 0.5}))
      assert Enum.all?(events, &(&1.sound == "bd"))
    end

    test "parses probability in subdivisions" do
      events = UzuParser.parse("bd [sd? hh]")

      assert length(events) == 3
      assert Enum.at(events, 0).params == %{}
      assert Enum.at(events, 1).params == %{probability: 0.5}
      assert Enum.at(events, 2).params == %{}
    end

    test "parses probability in chords" do
      events = UzuParser.parse("[bd?,sd]")

      assert length(events) == 2
      assert Enum.at(events, 0).sound == "bd"
      assert Enum.at(events, 0).params == %{probability: 0.5}
      assert Enum.at(events, 1).sound == "sd"
      assert Enum.at(events, 1).params == %{}
    end

    test "handles invalid probability gracefully" do
      # Invalid probability (negative or > 1) should be treated as literal
      events = UzuParser.parse("bd?1.5")

      assert length(events) == 1
      assert hd(events).sound == "bd?1.5"
      assert hd(events).params == %{}
    end

    test "handles probability 0.0" do
      events = UzuParser.parse("bd?0.0")

      assert length(events) == 1
      assert hd(events).params == %{probability: 0.0}
    end

    test "handles probability 1.0" do
      events = UzuParser.parse("bd?1.0")

      assert length(events) == 1
      assert hd(events).params == %{probability: 1.0}
    end
  end

  describe "elongation (temporal weight)" do
    test "parses sound with weight" do
      events = UzuParser.parse("bd@2 sd")

      assert length(events) == 2
      # bd has weight 2, sd has weight 1 (default), total 3
      # bd should be 2/3 = 0.666..., sd should be 1/3 = 0.333...
      assert Enum.at(events, 0).sound == "bd"
      assert_in_delta Enum.at(events, 0).duration, 0.666, 0.01
      assert Enum.at(events, 1).sound == "sd"
      assert_in_delta Enum.at(events, 1).duration, 0.333, 0.01
    end

    test "parses multiple weighted sounds" do
      events = UzuParser.parse("bd@2 sd@1 hh@1")

      assert length(events) == 3
      # Total weight: 4, so bd=2/4=0.5, sd=1/4=0.25, hh=1/4=0.25
      assert_in_delta Enum.at(events, 0).duration, 0.5, 0.01
      assert_in_delta Enum.at(events, 1).duration, 0.25, 0.01
      assert_in_delta Enum.at(events, 2).duration, 0.25, 0.01
    end

    test "parses weight in subdivision" do
      events = UzuParser.parse("[bd sd@3 hh]")

      assert length(events) == 3
      # Total weight: 5 (1+3+1), so bd=1/5=0.2, sd=3/5=0.6, hh=1/5=0.2
      assert_in_delta Enum.at(events, 0).duration, 0.2, 0.01
      assert_in_delta Enum.at(events, 1).duration, 0.6, 0.01
      assert_in_delta Enum.at(events, 2).duration, 0.2, 0.01
    end

    test "parses weight with sample selection" do
      events = UzuParser.parse("bd:0@2")

      assert length(events) == 1
      event = hd(events)
      assert event.sound == "bd"
      assert event.sample == 0
      assert event.duration == 1.0
    end

    test "parses weight with float values" do
      events = UzuParser.parse("bd@1.5 sd")

      assert length(events) == 2
      # Total weight: 2.5, so bd=1.5/2.5=0.6, sd=1/2.5=0.4
      assert_in_delta Enum.at(events, 0).duration, 0.6, 0.01
      assert_in_delta Enum.at(events, 1).duration, 0.4, 0.01
    end

    test "calculates correct timings with weights" do
      events = UzuParser.parse("bd@2 sd")

      # bd starts at 0.0 and lasts 2/3
      assert Enum.at(events, 0).time == 0.0
      assert_in_delta Enum.at(events, 0).duration, 0.666, 0.01

      # sd starts at 2/3 and lasts 1/3
      assert_in_delta Enum.at(events, 1).time, 0.666, 0.01
      assert_in_delta Enum.at(events, 1).duration, 0.333, 0.01
    end

    test "parses weight with probability" do
      events = UzuParser.parse("bd@2?0.5")

      assert length(events) == 1
      event = hd(events)
      assert event.sound == "bd"
      assert event.duration == 1.0
      assert event.params == %{probability: 0.5}
    end

    test "handles weight with rests" do
      events = UzuParser.parse("bd@2 ~ sd")

      # bd weight 2, rest weight 1, sd weight 1, total 4
      assert length(events) == 2
      assert Enum.at(events, 0).sound == "bd"
      assert_in_delta Enum.at(events, 0).duration, 0.5, 0.01
      assert Enum.at(events, 1).sound == "sd"
      assert_in_delta Enum.at(events, 1).duration, 0.25, 0.01
    end

    test "handles invalid weight gracefully" do
      # Invalid weight (negative or zero) should be treated as literal
      events = UzuParser.parse("bd@0")

      assert length(events) == 1
      assert hd(events).sound == "bd@0"
    end

    test "handles weight with chords" do
      events = UzuParser.parse("[bd@2,sd]")

      # Chord itself has weight 1 by default
      assert length(events) == 2
      assert Enum.at(events, 0).sound == "bd"
      assert Enum.at(events, 1).sound == "sd"
      # Both events in chord should have same time and duration
      assert Enum.at(events, 0).time == Enum.at(events, 1).time
      assert Enum.at(events, 0).duration == Enum.at(events, 1).duration
    end
  end

  describe "replication" do
    test "parses simple replication" do
      events = UzuParser.parse("bd!3")

      assert length(events) == 3
      assert Enum.all?(events, &(&1.sound == "bd"))
      assert Enum.at(events, 0).time == 0.0
      assert_in_delta Enum.at(events, 1).time, 0.333, 0.01
      assert_in_delta Enum.at(events, 2).time, 0.666, 0.01
    end

    test "parses replication in sequence" do
      events = UzuParser.parse("bd!2 sd")

      assert length(events) == 3
      assert Enum.at(events, 0).sound == "bd"
      assert Enum.at(events, 1).sound == "bd"
      assert Enum.at(events, 2).sound == "sd"
    end

    test "parses replication with sample selection" do
      events = UzuParser.parse("bd:1!3")

      assert length(events) == 3
      assert Enum.all?(events, &(&1.sound == "bd"))
      assert Enum.all?(events, &(&1.sample == 1))
    end

    test "parses replication with probability" do
      events = UzuParser.parse("bd!2?0.5")

      assert length(events) == 2
      assert Enum.all?(events, &(&1.sound == "bd"))
      assert Enum.all?(events, &(&1.params == %{probability: 0.5}))
    end

    test "handles invalid replication gracefully" do
      events = UzuParser.parse("bd!0")

      assert length(events) == 1
      assert hd(events).sound == "bd!0"
    end

    test "parses replication in subdivisions" do
      events = UzuParser.parse("[bd!2 sd]")

      assert length(events) == 3
      assert Enum.map(events, & &1.sound) == ["bd", "bd", "sd"]
    end

    test "replication behaves like repetition" do
      # bd!3 and bd*3 should produce the same result
      events_replication = UzuParser.parse("bd!3")
      events_repetition = UzuParser.parse("bd*3")

      assert length(events_replication) == length(events_repetition)

      Enum.zip(events_replication, events_repetition)
      |> Enum.each(fn {e1, e2} ->
        assert e1.sound == e2.sound
        assert e1.time == e2.time
        assert e1.duration == e2.duration
      end)
    end
  end

  describe "random choice" do
    test "parses simple random choice" do
      events = UzuParser.parse("bd|sd|hh")

      assert length(events) == 1
      event = hd(events)
      # Default sound is the first option
      assert event.sound == "bd"
      # Options stored in params
      assert Map.has_key?(event.params, :random_choice)
      options = event.params.random_choice
      assert length(options) == 3
      assert Enum.at(options, 0).sound == "bd"
      assert Enum.at(options, 1).sound == "sd"
      assert Enum.at(options, 2).sound == "hh"
    end

    test "parses random choice with two options" do
      events = UzuParser.parse("bd|sd")

      assert length(events) == 1
      event = hd(events)
      assert event.sound == "bd"
      options = event.params.random_choice
      assert length(options) == 2
    end

    test "parses random choice in sequence" do
      events = UzuParser.parse("bd|sd hh")

      assert length(events) == 2
      # First event is random choice
      assert Map.has_key?(Enum.at(events, 0).params, :random_choice)
      # Second event is regular sound
      assert Enum.at(events, 1).sound == "hh"
      assert Enum.at(events, 1).params == %{}
    end

    test "parses random choice with sample selection" do
      events = UzuParser.parse("bd:0|sd:1")

      assert length(events) == 1
      event = hd(events)
      options = event.params.random_choice
      assert Enum.at(options, 0).sound == "bd"
      assert Enum.at(options, 0).sample == 0
      assert Enum.at(options, 1).sound == "sd"
      assert Enum.at(options, 1).sample == 1
    end

    test "parses random choice in subdivision" do
      events = UzuParser.parse("[bd|sd hh]")

      assert length(events) == 2
      # First event is random choice
      assert Map.has_key?(Enum.at(events, 0).params, :random_choice)
      # Second event is regular sound
      assert Enum.at(events, 1).sound == "hh"
    end

    test "single option degrades to simple sound" do
      events = UzuParser.parse("bd|")

      assert length(events) == 1
      event = hd(events)
      assert event.sound == "bd"
      # No random_choice in params for single option
      refute Map.has_key?(event.params, :random_choice)
    end

    test "parses random choice with rest option" do
      events = UzuParser.parse("bd|~")

      assert length(events) == 1
      event = hd(events)
      options = event.params.random_choice
      assert length(options) == 2
      assert Enum.at(options, 0).sound == "bd"
      # rest
      assert Enum.at(options, 1).sound == nil
    end
  end

  describe "alternation" do
    test "parses simple alternation" do
      events = UzuParser.parse("<bd sd hh>")

      assert length(events) == 1
      event = hd(events)
      # Default sound is the first option
      assert event.sound == "bd"
      # Options stored in params
      assert Map.has_key?(event.params, :alternate)
      options = event.params.alternate
      assert length(options) == 3
      assert Enum.at(options, 0).sound == "bd"
      assert Enum.at(options, 1).sound == "sd"
      assert Enum.at(options, 2).sound == "hh"
    end

    test "parses alternation with two options" do
      events = UzuParser.parse("<bd sd>")

      assert length(events) == 1
      event = hd(events)
      options = event.params.alternate
      assert length(options) == 2
      assert Enum.at(options, 0).sound == "bd"
      assert Enum.at(options, 1).sound == "sd"
    end

    test "parses alternation in sequence" do
      events = UzuParser.parse("<bd sd> hh")

      assert length(events) == 2
      # First event is alternation
      assert Map.has_key?(Enum.at(events, 0).params, :alternate)
      # Second event is regular sound
      assert Enum.at(events, 1).sound == "hh"
      assert Enum.at(events, 1).params == %{}
    end

    test "parses alternation with sample selection" do
      events = UzuParser.parse("<bd:0 sd:1 hh:2>")

      assert length(events) == 1
      event = hd(events)
      options = event.params.alternate
      assert Enum.at(options, 0).sound == "bd"
      assert Enum.at(options, 0).sample == 0
      assert Enum.at(options, 1).sound == "sd"
      assert Enum.at(options, 1).sample == 1
      assert Enum.at(options, 2).sound == "hh"
      assert Enum.at(options, 2).sample == 2
    end

    test "parses multiple alternations" do
      events = UzuParser.parse("<bd sd> <hh cp>")

      assert length(events) == 2
      assert Map.has_key?(Enum.at(events, 0).params, :alternate)
      assert Map.has_key?(Enum.at(events, 1).params, :alternate)
    end

    test "parses alternation with probability" do
      events = UzuParser.parse("<bd? sd>")

      assert length(events) == 1
      event = hd(events)
      options = event.params.alternate
      assert Enum.at(options, 0).probability == 0.5
      assert Enum.at(options, 1).probability == nil
    end

    test "single option degrades to simple sound" do
      events = UzuParser.parse("<bd>")

      assert length(events) == 1
      event = hd(events)
      assert event.sound == "bd"
      # No alternate in params for single option
      refute Map.has_key?(event.params, :alternate)
    end

    test "correct timing for alternation in sequence" do
      events = UzuParser.parse("<bd sd> hh cp")

      assert length(events) == 3
      assert Enum.at(events, 0).time == 0.0
      assert_in_delta Enum.at(events, 1).time, 0.333, 0.01
      assert_in_delta Enum.at(events, 2).time, 0.666, 0.01
    end
  end

  describe "pattern elongation" do
    test "parses simple elongation bd _ sd _" do
      events = UzuParser.parse("bd _ sd _")

      assert length(events) == 2
      # bd and sd each have weight 2 (original + 1 from _)
      # Total weight 4, each gets 50%
      assert_in_delta Enum.at(events, 0).duration, 0.5, 0.01
      assert_in_delta Enum.at(events, 1).duration, 0.5, 0.01
    end

    test "parses multiple elongations bd _ _ sd" do
      events = UzuParser.parse("bd _ _ sd")

      assert length(events) == 2
      # bd has weight 3, sd has weight 1, total 4
      assert_in_delta Enum.at(events, 0).duration, 0.75, 0.01
      assert_in_delta Enum.at(events, 1).duration, 0.25, 0.01
    end

    test "parses elongation in subdivision" do
      events = UzuParser.parse("[bd _ sd]")

      assert length(events) == 2
      # bd has weight 2, sd has weight 1, total 3
      assert_in_delta Enum.at(events, 0).duration, 0.666, 0.01
      assert_in_delta Enum.at(events, 1).duration, 0.333, 0.01
    end

    test "elongation at start treated as rest" do
      events = UzuParser.parse("_ bd sd")

      # _ at start has no previous sound, becomes rest
      assert length(events) == 2
      assert Enum.at(events, 0).sound == "bd"
      assert Enum.at(events, 1).sound == "sd"
    end

    test "elongation with sample selection" do
      events = UzuParser.parse("bd:1 _ sd")

      assert length(events) == 2
      assert Enum.at(events, 0).sound == "bd"
      assert Enum.at(events, 0).sample == 1
      assert_in_delta Enum.at(events, 0).duration, 0.666, 0.01
    end
  end

  describe "shorthand separator" do
    test "parses period as separator bd . sd . hh" do
      events = UzuParser.parse("bd . sd . hh")

      assert length(events) == 3
      assert Enum.map(events, & &1.sound) == ["bd", "sd", "hh"]
    end

    test "parses period without spaces" do
      events = UzuParser.parse("bd.sd.hh")

      assert length(events) == 3
      assert Enum.map(events, & &1.sound) == ["bd", "sd", "hh"]
    end

    test "period in subdivision" do
      events = UzuParser.parse("[bd . sd] hh")

      assert length(events) == 3
      assert Enum.map(events, & &1.sound) == ["bd", "sd", "hh"]
    end

    test "period does not break decimal numbers" do
      events = UzuParser.parse("bd|gain:0.8")

      assert length(events) == 1
      assert hd(events).params == %{gain: 0.8}
    end

    test "period does not break decimal in ratio" do
      events = UzuParser.parse("bd%0.5")

      assert length(events) == 1
      assert hd(events).params == %{speed: 2.0}
    end
  end

  describe "ratio notation" do
    test "parses simple ratio bd%2" do
      events = UzuParser.parse("bd%2")

      assert length(events) == 1
      event = hd(events)
      assert event.sound == "bd"
      # %2 means spans 2 cycles, so speed is 0.5
      assert event.params == %{speed: 0.5}
    end

    test "parses ratio with sample selection" do
      events = UzuParser.parse("bd:1%3")

      assert length(events) == 1
      event = hd(events)
      assert event.sound == "bd"
      assert event.sample == 1
      assert_in_delta event.params.speed, 0.333, 0.01
    end

    test "parses fractional ratio bd%0.5" do
      events = UzuParser.parse("bd%0.5")

      assert length(events) == 1
      # %0.5 means spans 0.5 cycles, so speed is 2.0
      assert hd(events).params == %{speed: 2.0}
    end

    test "parses ratio in sequence" do
      events = UzuParser.parse("bd%2 sd")

      assert length(events) == 2
      assert Enum.at(events, 0).params == %{speed: 0.5}
      assert Enum.at(events, 1).params == %{}
    end

    test "handles invalid ratio gracefully" do
      events = UzuParser.parse("bd%0")

      # Zero ratio is invalid, treated as literal
      assert length(events) == 1
      assert hd(events).sound == "bd%0"
    end
  end

  describe "sound parameters" do
    test "parses single parameter bd|gain:0.8" do
      events = UzuParser.parse("bd|gain:0.8")

      assert length(events) == 1
      event = hd(events)
      assert event.sound == "bd"
      assert event.params == %{gain: 0.8}
    end

    test "parses multiple parameters bd|speed:2|pan:0.5" do
      events = UzuParser.parse("bd|speed:2|pan:0.5")

      assert length(events) == 1
      event = hd(events)
      assert event.sound == "bd"
      assert event.params == %{speed: 2.0, pan: 0.5}
    end

    test "parses parameters with sample selection bd:1|gain:0.8" do
      events = UzuParser.parse("bd:1|gain:0.8")

      assert length(events) == 1
      event = hd(events)
      assert event.sound == "bd"
      assert event.sample == 1
      assert event.params == %{gain: 0.8}
    end

    test "parses all supported parameters" do
      events =
        UzuParser.parse(
          "bd|gain:0.8|speed:1.5|pan:-0.5|cutoff:500|resonance:0.7|delay:0.3|room:0.5"
        )

      assert length(events) == 1
      event = hd(events)
      assert event.params.gain == 0.8
      assert event.params.speed == 1.5
      assert event.params.pan == -0.5
      assert event.params.cutoff == 500.0
      assert event.params.resonance == 0.7
      assert event.params.delay == 0.3
      assert event.params.room == 0.5
    end

    test "parses parameters in sequence" do
      events = UzuParser.parse("bd|gain:0.8 sd|pan:0.5")

      assert length(events) == 2
      assert Enum.at(events, 0).params == %{gain: 0.8}
      assert Enum.at(events, 1).params == %{pan: 0.5}
    end

    test "parses parameters in subdivision" do
      events = UzuParser.parse("[bd|gain:0.8 sd]")

      assert length(events) == 2
      assert Enum.at(events, 0).sound == "bd"
      assert Enum.at(events, 0).params == %{gain: 0.8}
      assert Enum.at(events, 1).sound == "sd"
      assert Enum.at(events, 1).params == %{}
    end

    test "ignores unknown parameters" do
      events = UzuParser.parse("bd|gain:0.8|unknown:1.0")

      assert length(events) == 1
      event = hd(events)
      assert event.params == %{gain: 0.8}
      refute Map.has_key?(event.params, :unknown)
    end

    test "random choice still works with pipe" do
      events = UzuParser.parse("bd|sd|hh")

      assert length(events) == 1
      event = hd(events)
      assert Map.has_key?(event.params, :random_choice)
      assert length(event.params.random_choice) == 3
    end

    test "distinguishes params from random choice" do
      # This is random choice (no known params)
      choice_events = UzuParser.parse("bd|sd")
      assert Map.has_key?(hd(choice_events).params, :random_choice)

      # This is parameters (has known param name)
      param_events = UzuParser.parse("bd|gain:0.5")
      assert Map.has_key?(hd(param_events).params, :gain)
      refute Map.has_key?(hd(param_events).params, :random_choice)
    end

    test "handles negative parameter values" do
      events = UzuParser.parse("bd|pan:-1.0")

      assert length(events) == 1
      assert hd(events).params == %{pan: -1.0}
    end

    test "handles integer parameter values" do
      events = UzuParser.parse("bd|cutoff:500")

      assert length(events) == 1
      assert hd(events).params == %{cutoff: 500.0}
    end
  end

  describe "polymetric sequences" do
    test "parses simple polymetric {bd sd hh, cp}" do
      events = UzuParser.parse("{bd sd hh, cp}")

      # Group 1: bd sd hh (3 events), Group 2: cp (1 event)
      assert length(events) == 4

      # Group 1 events at 0, 1/3, 2/3
      bd = Enum.find(events, &(&1.sound == "bd"))
      sd = Enum.find(events, &(&1.sound == "sd"))
      hh = Enum.find(events, &(&1.sound == "hh"))
      cp = Enum.find(events, &(&1.sound == "cp"))

      assert_in_delta bd.time, 0.0, 0.01
      assert_in_delta sd.time, 0.333, 0.01
      assert_in_delta hh.time, 0.666, 0.01

      # cp spans full cycle
      assert_in_delta cp.time, 0.0, 0.01
      assert_in_delta cp.duration, 1.0, 0.01
    end

    test "parses polymetric with different step counts" do
      events = UzuParser.parse("{bd sd, hh cp oh}")

      # Group 1: 2 events, Group 2: 3 events
      assert length(events) == 5

      # Group 1 durations
      bd = Enum.find(events, &(&1.sound == "bd"))
      sd = Enum.find(events, &(&1.sound == "sd"))
      assert_in_delta bd.duration, 0.5, 0.01
      assert_in_delta sd.duration, 0.5, 0.01

      # Group 2 durations
      hh = Enum.find(events, &(&1.sound == "hh"))
      assert_in_delta hh.duration, 0.333, 0.01
    end

    test "parses polymetric with sample selection" do
      events = UzuParser.parse("{bd:0 sd:1, cp:2}")

      assert length(events) == 3
      bd = Enum.find(events, &(&1.sound == "bd"))
      sd = Enum.find(events, &(&1.sound == "sd"))
      cp = Enum.find(events, &(&1.sound == "cp"))

      assert bd.sample == 0
      assert sd.sample == 1
      assert cp.sample == 2
    end

    test "parses polymetric in sequence" do
      events = UzuParser.parse("hh {bd, sd cp}")

      # hh first, then polymetric with 2 groups
      assert length(events) == 4
      assert Enum.at(events, 0).sound == "hh"
    end

    test "single group degrades to subdivision" do
      events = UzuParser.parse("{bd sd hh}")

      # Single group should behave like subdivision
      assert length(events) == 3
      assert Enum.all?(events, fn e -> e.duration < 1.0 end)
    end

    test "empty polymetric returns nil/empty" do
      events = UzuParser.parse("{}")

      assert events == []
    end

    test "polymetric with rests" do
      events = UzuParser.parse("{bd ~ sd, cp}")

      # Group 1: 3 slots but rest at position 1
      # Group 2: cp at full cycle
      # Total 3 events (bd, sd from group 1, cp from group 2)
      assert length(events) == 3
    end
  end

  describe "polymetric subdivision" do
    test "parses {bd sd hh}%8 - 3 events over 8 steps" do
      events = UzuParser.parse("{bd sd hh}%8")

      assert length(events) == 3

      # Each event has duration 1/8 of the cycle
      assert Enum.all?(events, fn e -> abs(e.duration - 0.125) < 0.01 end)

      # Events are distributed across the cycle
      bd = Enum.find(events, &(&1.sound == "bd"))
      sd = Enum.find(events, &(&1.sound == "sd"))
      hh = Enum.find(events, &(&1.sound == "hh"))

      assert_in_delta bd.time, 0.0, 0.01
      assert_in_delta sd.time, 0.333, 0.01
      assert_in_delta hh.time, 0.666, 0.01
    end

    test "parses {bd sd}%4 - 2 events over 4 steps" do
      events = UzuParser.parse("{bd sd}%4")

      assert length(events) == 2

      # Each event has duration 1/4 of the cycle
      assert Enum.all?(events, fn e -> abs(e.duration - 0.25) < 0.01 end)

      bd = Enum.find(events, &(&1.sound == "bd"))
      sd = Enum.find(events, &(&1.sound == "sd"))

      assert_in_delta bd.time, 0.0, 0.01
      assert_in_delta sd.time, 0.5, 0.01
    end

    test "parses {bd sd hh cp}%4 - 4 events over 4 steps" do
      events = UzuParser.parse("{bd sd hh cp}%4")

      assert length(events) == 4

      # Each event has duration 1/4 of the cycle
      assert Enum.all?(events, fn e -> abs(e.duration - 0.25) < 0.01 end)

      # Events are evenly spaced at 0, 0.25, 0.5, 0.75
      times = events |> Enum.map(& &1.time) |> Enum.sort()
      assert_in_delta Enum.at(times, 0), 0.0, 0.01
      assert_in_delta Enum.at(times, 1), 0.25, 0.01
      assert_in_delta Enum.at(times, 2), 0.5, 0.01
      assert_in_delta Enum.at(times, 3), 0.75, 0.01
    end

    test "parses polymetric subdivision with sample selection" do
      events = UzuParser.parse("{bd:0 sd:1}%8")

      assert length(events) == 2
      bd = Enum.find(events, &(&1.sound == "bd"))
      sd = Enum.find(events, &(&1.sound == "sd"))

      assert bd.sample == 0
      assert sd.sample == 1
      assert_in_delta bd.duration, 0.125, 0.01
    end

    test "parses polymetric subdivision in sequence" do
      events = UzuParser.parse("hh {bd sd}%4")

      # hh takes first half, polymetric takes second half
      assert length(events) == 3
      hh = Enum.find(events, &(&1.sound == "hh"))
      assert_in_delta hh.duration, 0.5, 0.01
    end
  end

  describe "division" do
    test "parses simple division bd/2" do
      events = UzuParser.parse("bd/2")

      assert length(events) == 1
      event = hd(events)
      assert event.sound == "bd"
      assert event.params == %{division: 2.0}
    end

    test "parses division with sample selection" do
      events = UzuParser.parse("bd:1/4")

      assert length(events) == 1
      event = hd(events)
      assert event.sound == "bd"
      assert event.sample == 1
      assert event.params == %{division: 4.0}
    end

    test "parses division in sequence" do
      events = UzuParser.parse("bd/2 sd")

      assert length(events) == 2
      assert Enum.at(events, 0).params == %{division: 2.0}
      assert Enum.at(events, 1).params == %{}
    end

    test "parses subdivision with division [bd sd]/2" do
      events = UzuParser.parse("[bd sd]/2")

      assert length(events) == 2
      # Both events should have division applied
      assert Enum.at(events, 0).sound == "bd"
      assert Enum.at(events, 0).params == %{division: 2.0}
      assert Enum.at(events, 1).sound == "sd"
      assert Enum.at(events, 1).params == %{division: 2.0}
    end

    test "parses chord with division [bd,sd]/4" do
      events = UzuParser.parse("[bd,sd]/4")

      assert length(events) == 2
      # Both events in chord should have division
      assert Enum.all?(events, &(&1.params == %{division: 4.0}))
      # Both at same time (polyphony)
      assert Enum.at(events, 0).time == Enum.at(events, 1).time
    end

    test "handles fractional division" do
      events = UzuParser.parse("bd/1.5")

      assert length(events) == 1
      assert hd(events).params == %{division: 1.5}
    end

    test "handles invalid division gracefully" do
      events = UzuParser.parse("bd/0")

      # Zero division is invalid, treated as literal
      assert length(events) == 1
      assert hd(events).sound == "bd/0"
    end

    test "handles invalid division with non-number" do
      events = UzuParser.parse("bd/abc")

      assert length(events) == 1
      assert hd(events).sound == "bd/abc"
    end
  end

  describe "euclidean rhythms" do
    test "parses simple euclidean rhythm bd(3,8)" do
      events = UzuParser.parse("bd(3,8)")

      # 3 hits distributed over 8 steps
      assert length(events) == 3
      assert Enum.all?(events, &(&1.sound == "bd"))

      # Bjorklund(3,8) = [1,0,0,1,0,0,1,0] -> hits at positions 0, 3, 6
      # Times: 0/8=0.0, 3/8=0.375, 6/8=0.75
      assert_in_delta Enum.at(events, 0).time, 0.0, 0.01
      assert_in_delta Enum.at(events, 1).time, 0.375, 0.01
      assert_in_delta Enum.at(events, 2).time, 0.75, 0.01
    end

    test "parses euclidean rhythm bd(5,8)" do
      events = UzuParser.parse("bd(5,8)")

      # 5 hits distributed over 8 steps
      assert length(events) == 5
      assert Enum.all?(events, &(&1.sound == "bd"))
    end

    test "parses euclidean rhythm with offset bd(3,8,2)" do
      events = UzuParser.parse("bd(3,8,2)")

      # 3 hits over 8 steps, rotated by 2
      assert length(events) == 3
      assert Enum.all?(events, &(&1.sound == "bd"))

      # Original pattern [1,0,0,1,0,0,1,0], offset 2 -> [0,1,0,0,1,0,0,1]
      # Hits at positions 1, 4, 7 -> times 0.125, 0.5, 0.875
      # But since rest at 0, first hit is at position 1
      assert_in_delta Enum.at(events, 0).time, 0.125, 0.01
      assert_in_delta Enum.at(events, 1).time, 0.5, 0.01
    end

    test "parses euclidean rhythm with sample selection" do
      events = UzuParser.parse("bd:1(3,8)")

      assert length(events) == 3
      assert Enum.all?(events, &(&1.sound == "bd"))
      assert Enum.all?(events, &(&1.sample == 1))
    end

    test "parses euclidean rhythm in sequence" do
      events = UzuParser.parse("hh bd(3,8)")

      # hh takes 1 slot, bd(3,8) expands to 8 slots, total 9 slots
      # hh at 0/9, bd hits at 1/9, 4/9, 7/9 (approx)
      assert length(events) == 4
      assert Enum.at(events, 0).sound == "hh"
      assert Enum.at(events, 1).sound == "bd"
    end

    test "parses euclidean rhythm bd(4,4) - all hits" do
      events = UzuParser.parse("bd(4,4)")

      assert length(events) == 4
      assert Enum.all?(events, &(&1.sound == "bd"))
    end

    test "parses euclidean rhythm bd(1,4) - single hit" do
      events = UzuParser.parse("bd(1,4)")

      assert length(events) == 1
      assert hd(events).sound == "bd"
      assert hd(events).time == 0.0
    end

    test "handles invalid euclidean - k > n" do
      events = UzuParser.parse("bd(5,3)")

      # Invalid, treated as literal
      assert length(events) == 1
      assert hd(events).sound == "bd(5,3)"
    end

    test "handles invalid euclidean - k = 0" do
      events = UzuParser.parse("bd(0,8)")

      # Invalid, treated as literal
      assert length(events) == 1
      assert hd(events).sound == "bd(0,8)"
    end

    test "handles malformed euclidean gracefully" do
      events = UzuParser.parse("bd(3,)")

      assert length(events) == 1
      assert hd(events).sound == "bd(3,)"
    end

    test "parses common world music euclidean patterns" do
      # Cuban tresillo: 3 over 8
      tresillo = UzuParser.parse("bd(3,8)")
      assert length(tresillo) == 3

      # Cinquillo: 5 over 8
      cinquillo = UzuParser.parse("bd(5,8)")
      assert length(cinquillo) == 5

      # Bembé: 7 over 12
      bembe = UzuParser.parse("bd(7,12)")
      assert length(bembe) == 7
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

    test "sample field is present" do
      [event | _] = UzuParser.parse("bd")
      assert Map.has_key?(event, :sample)
    end
  end
end
