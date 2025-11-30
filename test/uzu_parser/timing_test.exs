defmodule UzuParser.TimingTest do
  use ExUnit.Case, async: true

  alias UzuParser.Timing

  describe "calculate_timings/1 basic" do
    test "returns empty list for empty tokens" do
      assert [] == Timing.calculate_timings([])
    end

    test "single sound fills entire cycle" do
      tokens = [{:sound, "bd", nil, nil, nil}]
      events = Timing.calculate_timings(tokens)

      assert length(events) == 1
      event = hd(events)
      assert event.sound == "bd"
      assert event.time == 0.0
      assert event.duration == 1.0
    end

    test "two sounds split cycle equally" do
      tokens = [{:sound, "bd", nil, nil, nil}, {:sound, "sd", nil, nil, nil}]
      events = Timing.calculate_timings(tokens)

      assert length(events) == 2
      assert Enum.at(events, 0).time == 0.0
      assert_in_delta Enum.at(events, 0).duration, 0.5, 0.01
      assert_in_delta Enum.at(events, 1).time, 0.5, 0.01
      assert_in_delta Enum.at(events, 1).duration, 0.5, 0.01
    end

    test "four sounds split cycle into quarters" do
      tokens = [
        {:sound, "bd", nil, nil, nil},
        {:sound, "sd", nil, nil, nil},
        {:sound, "hh", nil, nil, nil},
        {:sound, "cp", nil, nil, nil}
      ]
      events = Timing.calculate_timings(tokens)

      assert length(events) == 4
      Enum.each(events, fn event ->
        assert_in_delta event.duration, 0.25, 0.01
      end)
    end
  end

  describe "calculate_timings/1 rests" do
    test "rest is omitted from events" do
      tokens = [{:sound, "bd", nil, nil, nil}, :rest, {:sound, "sd", nil, nil, nil}]
      events = Timing.calculate_timings(tokens)

      assert length(events) == 2
      assert Enum.at(events, 0).sound == "bd"
      assert Enum.at(events, 1).sound == "sd"
    end

    test "rest takes up time" do
      tokens = [{:sound, "bd", nil, nil, nil}, :rest, {:sound, "sd", nil, nil, nil}]
      events = Timing.calculate_timings(tokens)

      assert_in_delta Enum.at(events, 0).time, 0.0, 0.01
      assert_in_delta Enum.at(events, 1).time, 0.666, 0.01
    end
  end

  describe "calculate_timings/1 weights" do
    test "weight affects duration" do
      tokens = [
        {:sound, "bd", nil, nil, 2.0},
        {:sound, "sd", nil, nil, nil}
      ]
      events = Timing.calculate_timings(tokens)

      assert_in_delta Enum.at(events, 0).duration, 0.666, 0.01
      assert_in_delta Enum.at(events, 1).duration, 0.333, 0.01
    end

    test "multiple weights" do
      tokens = [
        {:sound, "bd", nil, nil, 2.0},
        {:sound, "sd", nil, nil, 1.0},
        {:sound, "hh", nil, nil, 1.0}
      ]
      events = Timing.calculate_timings(tokens)

      assert_in_delta Enum.at(events, 0).duration, 0.5, 0.01
      assert_in_delta Enum.at(events, 1).duration, 0.25, 0.01
      assert_in_delta Enum.at(events, 2).duration, 0.25, 0.01
    end

    test "weight affects start times" do
      tokens = [
        {:sound, "bd", nil, nil, 2.0},
        {:sound, "sd", nil, nil, nil}
      ]
      events = Timing.calculate_timings(tokens)

      assert Enum.at(events, 0).time == 0.0
      assert_in_delta Enum.at(events, 1).time, 0.666, 0.01
    end
  end

  describe "calculate_timings/1 with position tracking" do
    test "preserves source positions" do
      tokens = [{{:sound, "bd", nil, nil, nil}, 0, 2}]
      events = Timing.calculate_timings(tokens)

      assert length(events) == 1
      event = hd(events)
      assert event.source_start == 0
      assert event.source_end == 2
    end

    test "handles nil positions" do
      tokens = [{{:sound, "bd", nil, nil, nil}, nil, nil}]
      events = Timing.calculate_timings(tokens)

      event = hd(events)
      assert event.source_start == nil
      assert event.source_end == nil
    end
  end

  describe "calculate_timings/1 subdivisions" do
    test "flattens subdivision" do
      tokens = [{:subdivision, [{:sound, "bd", nil, nil, nil}, {:sound, "sd", nil, nil, nil}]}]
      events = Timing.calculate_timings(tokens)

      assert length(events) == 2
    end

    test "nested subdivisions flatten" do
      tokens = [
        {:subdivision, [
          {:subdivision, [{:sound, "bd", nil, nil, nil}, {:sound, "sd", nil, nil, nil}]},
          {:sound, "hh", nil, nil, nil}
        ]}
      ]
      events = Timing.calculate_timings(tokens)

      assert length(events) == 3
    end
  end

  describe "calculate_timings/1 repetition" do
    test "flattens repeat" do
      tokens = [{:repeat, [{:sound, "bd", nil, nil, nil}, {:sound, "bd", nil, nil, nil}]}]
      events = Timing.calculate_timings(tokens)

      assert length(events) == 2
      assert Enum.all?(events, &(&1.sound == "bd"))
    end
  end

  describe "calculate_timings/1 chord" do
    test "chord sounds play at same time" do
      tokens = [{:chord, [{:sound, "bd", nil, nil, nil}, {:sound, "sd", nil, nil, nil}]}]
      events = Timing.calculate_timings(tokens)

      assert length(events) == 2
      assert Enum.at(events, 0).time == Enum.at(events, 1).time
    end

    test "chord sounds have same duration" do
      tokens = [{:chord, [{:sound, "bd", nil, nil, nil}, {:sound, "sd", nil, nil, nil}]}]
      events = Timing.calculate_timings(tokens)

      assert Enum.at(events, 0).duration == Enum.at(events, 1).duration
    end
  end

  describe "calculate_timings/1 probability" do
    test "preserves probability in params" do
      tokens = [{:sound, "bd", nil, 0.5, nil}]
      events = Timing.calculate_timings(tokens)

      event = hd(events)
      assert event.params == %{probability: 0.5}
    end

    test "no probability means empty params" do
      tokens = [{:sound, "bd", nil, nil, nil}]
      events = Timing.calculate_timings(tokens)

      event = hd(events)
      assert event.params == %{}
    end
  end

  describe "calculate_timings/1 sample" do
    test "preserves sample number" do
      tokens = [{:sound, "bd", 5, nil, nil}]
      events = Timing.calculate_timings(tokens)

      event = hd(events)
      assert event.sample == 5
    end
  end

  describe "calculate_timings/1 jazz tokens" do
    test "degree token becomes event with jazz params" do
      tokens = [{:degree, 1}]
      events = Timing.calculate_timings(tokens)

      event = hd(events)
      assert event.sound == "^1"
      assert event.params.jazz_type == :degree
      assert event.params.jazz_value == 1
    end

    test "chord symbol becomes event with jazz params" do
      tokens = [{:chord, "Dm7"}]
      events = Timing.calculate_timings(tokens)

      event = hd(events)
      assert event.sound == "@Dm7"
      assert event.params.jazz_type == :chord
      assert event.params.jazz_value == "Dm7"
    end

    test "roman numeral becomes event with jazz params" do
      tokens = [{:roman, "ii"}]
      events = Timing.calculate_timings(tokens)

      event = hd(events)
      assert event.sound == "@ii"
      assert event.params.jazz_type == :roman
      assert event.params.jazz_value == "ii"
    end
  end

  describe "calculate_timings/1 random choice" do
    test "random choice creates event with options" do
      tokens = [{:random_choice, [{:sound, "bd", nil, nil, nil}, {:sound, "sd", nil, nil, nil}]}]
      events = Timing.calculate_timings(tokens)

      assert length(events) == 1
      event = hd(events)
      assert Map.has_key?(event.params, :random_choice)
      options = event.params.random_choice
      assert length(options) == 2
    end

    test "default sound is first option" do
      tokens = [{:random_choice, [{:sound, "bd", nil, nil, nil}, {:sound, "sd", nil, nil, nil}]}]
      events = Timing.calculate_timings(tokens)

      event = hd(events)
      assert event.sound == "bd"
    end
  end

  describe "calculate_timings/1 alternation" do
    test "alternation creates event with options" do
      tokens = [{:alternate, [{:sound, "bd", nil, nil, nil}, {:sound, "sd", nil, nil, nil}]}]
      events = Timing.calculate_timings(tokens)

      assert length(events) == 1
      event = hd(events)
      assert Map.has_key?(event.params, :alternate)
    end
  end

  describe "calculate_timings/1 division" do
    test "division creates event with division param" do
      tokens = [{:division, "bd", nil, 2.0}]
      events = Timing.calculate_timings(tokens)

      event = hd(events)
      assert event.sound == "bd"
      assert event.params == %{division: 2.0}
    end

    test "division preserves sample" do
      tokens = [{:division, "bd", 1, 2.0}]
      events = Timing.calculate_timings(tokens)

      event = hd(events)
      assert event.sample == 1
    end
  end

  describe "calculate_timings/1 ratio" do
    test "ratio creates event with speed param" do
      tokens = [{:ratio, "bd", nil, 2.0}]
      events = Timing.calculate_timings(tokens)

      event = hd(events)
      assert event.sound == "bd"
      assert event.params == %{speed: 0.5}
    end
  end

  describe "calculate_timings/1 euclidean" do
    test "euclidean expands to pattern" do
      tokens = [{:euclidean, "bd", nil, 3, 8, 0}]
      events = Timing.calculate_timings(tokens)

      assert length(events) == 3
      assert Enum.all?(events, &(&1.sound == "bd"))
    end

    test "euclidean preserves sample" do
      tokens = [{:euclidean, "bd", 1, 3, 8, 0}]
      events = Timing.calculate_timings(tokens)

      assert Enum.all?(events, &(&1.sample == 1))
    end
  end

  describe "calculate_timings/1 polymetric" do
    test "polymetric groups have independent timing" do
      tokens = [{:polymetric, [
        [{:sound, "bd", nil, nil, nil}, {:sound, "sd", nil, nil, nil}],
        [{:sound, "cp", nil, nil, nil}]
      ]}]
      events = Timing.calculate_timings(tokens)

      bd = Enum.find(events, &(&1.sound == "bd"))
      sd = Enum.find(events, &(&1.sound == "sd"))
      cp = Enum.find(events, &(&1.sound == "cp"))

      assert_in_delta bd.duration, 0.5, 0.01
      assert_in_delta sd.duration, 0.5, 0.01
      assert_in_delta cp.duration, 1.0, 0.01
    end
  end

  describe "calculate_timings/1 elongation (_)" do
    test "elongation increases previous sound weight" do
      tokens = [{:sound, "bd", nil, nil, nil}, :elongate, {:sound, "sd", nil, nil, nil}]
      events = Timing.calculate_timings(tokens)

      assert length(events) == 2
      assert_in_delta Enum.at(events, 0).duration, 0.666, 0.01
      assert_in_delta Enum.at(events, 1).duration, 0.333, 0.01
    end

    test "multiple elongations stack" do
      tokens = [{:sound, "bd", nil, nil, nil}, :elongate, :elongate, {:sound, "sd", nil, nil, nil}]
      events = Timing.calculate_timings(tokens)

      assert_in_delta Enum.at(events, 0).duration, 0.75, 0.01
      assert_in_delta Enum.at(events, 1).duration, 0.25, 0.01
    end

    test "elongation at start becomes rest" do
      tokens = [:elongate, {:sound, "bd", nil, nil, nil}]
      events = Timing.calculate_timings(tokens)

      assert length(events) == 1
      assert Enum.at(events, 0).sound == "bd"
    end
  end

  describe "calculate_timings/1 sound with params" do
    test "sound_with_params preserves params" do
      tokens = [{:sound_with_params, "bd", nil, %{gain: 0.8, speed: 2.0}}]
      events = Timing.calculate_timings(tokens)

      event = hd(events)
      assert event.params == %{gain: 0.8, speed: 2.0}
    end

    test "sound_with_params preserves sample" do
      tokens = [{:sound_with_params, "bd", 1, %{gain: 0.8}}]
      events = Timing.calculate_timings(tokens)

      event = hd(events)
      assert event.sample == 1
    end
  end

  describe "flatten_structure/1" do
    test "flattens nil to empty" do
      assert [] == Timing.flatten_structure([nil])
    end

    test "flattens rest to rest" do
      assert [:rest] == Timing.flatten_structure([:rest])
    end

    test "flattens simple sound" do
      result = Timing.flatten_structure([{:sound, "bd", nil, nil, nil}])
      assert [{:sound, "bd", nil, nil, nil}] = result
    end

    test "flattens subdivision" do
      result = Timing.flatten_structure([{:subdivision, [{:sound, "bd", nil, nil, nil}]}])
      assert [{:sound, "bd", nil, nil, nil}] = result
    end

    test "flattens repeat" do
      result = Timing.flatten_structure([{:repeat, [{:sound, "bd", nil, nil, nil}, {:sound, "bd", nil, nil, nil}]}])
      assert length(result) == 2
    end

    test "flattens euclidean to pattern" do
      result = Timing.flatten_structure([{:euclidean, "bd", nil, 3, 8, 0}])
      assert length(result) == 8
      hits = Enum.count(result, fn
        {:sound, _, _, _, _} -> true
        _ -> false
      end)
      assert hits == 3
    end
  end

  describe "flatten_token/1" do
    test "nil returns empty" do
      assert [] == Timing.flatten_token(nil)
    end

    test "rest returns rest" do
      assert [:rest] == Timing.flatten_token(:rest)
    end

    test "elongate returns elongate" do
      assert [:elongate] == Timing.flatten_token(:elongate)
    end

    test "sound returns sound" do
      assert [{:sound, "bd", nil, nil, nil}] == Timing.flatten_token({:sound, "bd", nil, nil, nil})
    end

    test "repeat flattens items" do
      result = Timing.flatten_token({:repeat, [{:sound, "bd", nil, nil, nil}, {:sound, "bd", nil, nil, nil}]})
      assert length(result) == 2
    end

    test "subdivision flattens items" do
      result = Timing.flatten_token({:subdivision, [{:sound, "bd", nil, nil, nil}, {:sound, "sd", nil, nil, nil}]})
      assert length(result) == 2
    end

    test "euclidean generates pattern" do
      result = Timing.flatten_token({:euclidean, "bd", nil, 3, 8, 0})
      assert length(result) == 8
    end

    test "chord list returns as is" do
      chord = {:chord, [{:sound, "bd", nil, nil, nil}]}
      assert [chord] == Timing.flatten_token(chord)
    end

    test "chord string returns as is" do
      chord = {:chord, "Dm7"}
      assert [chord] == Timing.flatten_token(chord)
    end

    test "random choice returns as is" do
      choice = {:random_choice, [{:sound, "bd", nil, nil, nil}]}
      assert [choice] == Timing.flatten_token(choice)
    end

    test "alternate returns as is" do
      alt = {:alternate, [{:sound, "bd", nil, nil, nil}]}
      assert [alt] == Timing.flatten_token(alt)
    end

    test "division returns as is" do
      div = {:division, "bd", nil, 2.0}
      assert [div] == Timing.flatten_token(div)
    end

    test "ratio returns as is" do
      ratio = {:ratio, "bd", nil, 2.0}
      assert [ratio] == Timing.flatten_token(ratio)
    end

    test "polymetric returns as is" do
      poly = {:polymetric, [[{:sound, "bd", nil, nil, nil}]]}
      assert [poly] == Timing.flatten_token(poly)
    end
  end
end
