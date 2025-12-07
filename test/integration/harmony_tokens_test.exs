defmodule UzuParser.Integration.HarmonyTokensTest do
  @moduledoc """
  Integration tests for harmony token parsing through UzuParser.parse/1.

  Tests scale degrees (^1, ^b7), chord symbols (@Dm7), and roman numerals (@V7).
  """

  use ExUnit.Case, async: true

  describe "scale degrees" do
    test "parses basic degrees 1-7" do
      for degree <- 1..7 do
        [event] = UzuParser.parse("^#{degree}")
        assert event.sound == "^#{degree}"
        assert event.params.harmony_type == :degree
        assert event.params.harmony_value == degree
      end
    end

    test "parses extended degrees 9, 11, 13" do
      events = UzuParser.parse("^9 ^11 ^13")

      assert length(events) == 3
      assert Enum.map(events, & &1.params.harmony_value) == [9, 11, 13]
      assert Enum.all?(events, &(&1.params.harmony_type == :degree))
    end

    test "parses flatted degrees ^b3, ^b7" do
      for degree <- ["b3", "b7"] do
        [event] = UzuParser.parse("^#{degree}")
        assert event.params.harmony_type == :degree
        assert event.params.harmony_value == degree
      end
    end

    test "parses sharped degrees ^#5, ^#11" do
      for degree <- ["#5", "#11"] do
        [event] = UzuParser.parse("^#{degree}")
        assert event.params.harmony_type == :degree
        assert event.params.harmony_value == degree
      end
    end

    test "invalid degrees (0, 14+) are treated as regular sounds" do
      for pattern <- ["^0", "^14", "^"] do
        [event] = UzuParser.parse(pattern)
        assert event.sound == pattern
        assert event.params == %{}
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
        [event] = UzuParser.parse(pattern)
        assert event.sound == pattern
        assert event.params.harmony_type == :chord
        assert event.params.harmony_value == expected_value
      end
    end

    test "parses chord sequence" do
      events = UzuParser.parse("@Dm7 @G7 @Cmaj7")

      assert length(events) == 3
      assert Enum.map(events, & &1.params.harmony_value) == ["Dm7", "G7", "Cmaj7"]
      assert Enum.all?(events, &(&1.params.harmony_type == :chord))
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
        [event] = UzuParser.parse(pattern)
        assert event.sound == pattern
        assert event.params.harmony_type == expected_type
        assert event.params.harmony_value == expected_value
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
        [event] = UzuParser.parse(pattern)
        assert event.params.harmony_type == :roman
        assert event.params.harmony_value == expected_value
      end
    end

    test "parses two-five-one progression" do
      events = UzuParser.parse("@ii7 @V7 @Imaj7")

      assert length(events) == 3
      assert Enum.map(events, & &1.params.harmony_value) == ["ii7", "V7", "Imaj7"]
    end
  end

  describe "jazz tokens in subdivisions" do
    test "degrees in brackets maintain jazz params" do
      events = UzuParser.parse("[^1 ^3 ^5]")

      assert length(events) == 3
      assert Enum.all?(events, &(&1.params.harmony_type == :degree))
    end

    test "chords in brackets maintain jazz params" do
      events = UzuParser.parse("[@Dm7 @G7]")

      assert length(events) == 2
      assert Enum.all?(events, &(&1.params.harmony_type == :chord))
    end

    test "romans in brackets maintain jazz params" do
      events = UzuParser.parse("[@ii @V @I]")

      assert length(events) == 3
      assert Enum.all?(events, &(&1.params.harmony_type == :roman))
    end
  end

  describe "mixed with regular sounds" do
    test "degrees interleaved with drum sounds" do
      events = UzuParser.parse("^1 bd ^3 sd")

      assert length(events) == 4
      assert Enum.at(events, 0).params.harmony_type == :degree
      assert Enum.at(events, 1).sound == "bd"
      assert Enum.at(events, 1).params == %{}
      assert Enum.at(events, 2).params.harmony_type == :degree
      assert Enum.at(events, 3).sound == "sd"
    end

    test "chords with rests" do
      events = UzuParser.parse("@ii ~ @V ~")
      jazz_events = Enum.filter(events, &Map.has_key?(&1.params, :harmony_type))

      assert length(jazz_events) == 2
      # rests produce no events
      assert length(events) == 2
    end
  end

  describe "edge cases" do
    test "bare @ and @number are regular sounds" do
      for pattern <- ["@", "@1", "@123"] do
        [event] = UzuParser.parse(pattern)
        assert event.sound == pattern
        assert event.params == %{}
      end
    end

    test "weight modifier bd@2 is not a jazz token" do
      [event] = UzuParser.parse("bd@2")

      assert event.sound == "bd"
      assert event.params == %{}
      # Weight affects timing distribution, not stored in params
    end
  end
end
