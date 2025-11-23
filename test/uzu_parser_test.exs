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
