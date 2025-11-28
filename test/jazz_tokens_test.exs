defmodule UzuParser.JazzTokensTest do
  use ExUnit.Case, async: true

  describe "jazz scale degree tokens" do
    test "parses simple degree ^1" do
      [event] = UzuParser.parse("^1")
      assert event.sound == "^1"
      assert event.params.jazz_type == :degree
      assert event.params.jazz_value == 1
    end

    test "parses degree ^3" do
      [event] = UzuParser.parse("^3")
      assert event.sound == "^3"
      assert event.params.jazz_type == :degree
      assert event.params.jazz_value == 3
    end

    test "parses degree ^5" do
      [event] = UzuParser.parse("^5")
      assert event.sound == "^5"
      assert event.params.jazz_type == :degree
      assert event.params.jazz_value == 5
    end

    test "parses degree ^7" do
      [event] = UzuParser.parse("^7")
      assert event.sound == "^7"
      assert event.params.jazz_type == :degree
      assert event.params.jazz_value == 7
    end

    test "parses extended degrees ^9 ^11 ^13" do
      events = UzuParser.parse("^9 ^11 ^13")
      assert length(events) == 3
      assert Enum.at(events, 0).params.jazz_value == 9
      assert Enum.at(events, 1).params.jazz_value == 11
      assert Enum.at(events, 2).params.jazz_value == 13
    end

    test "parses flatted degree ^b7" do
      [event] = UzuParser.parse("^b7")
      assert event.sound == "^b7"
      assert event.params.jazz_type == :degree
      assert event.params.jazz_value == "b7"
    end

    test "parses flatted degree ^b3" do
      [event] = UzuParser.parse("^b3")
      assert event.params.jazz_value == "b3"
    end

    test "parses sharped degree ^#5" do
      [event] = UzuParser.parse("^#5")
      assert event.params.jazz_value == "#5"
    end

    test "parses sharped degree ^#11" do
      [event] = UzuParser.parse("^#11")
      assert event.params.jazz_value == "#11"
    end

    test "parses degree sequence ^1 ^3 ^5 ^7" do
      events = UzuParser.parse("^1 ^3 ^5 ^7")
      assert length(events) == 4
      assert Enum.map(events, & &1.params.jazz_value) == [1, 3, 5, 7]
    end

    test "treats invalid degree ^0 as sound" do
      [event] = UzuParser.parse("^0")
      assert event.sound == "^0"
      assert event.params == %{}
    end

    test "treats invalid degree ^14 as sound" do
      [event] = UzuParser.parse("^14")
      assert event.sound == "^14"
      assert event.params == %{}
    end

    test "treats bare ^ as sound" do
      [event] = UzuParser.parse("^")
      assert event.sound == "^"
      assert event.params == %{}
    end
  end

  describe "jazz chord symbol tokens" do
    test "parses major chord @Cmaj7" do
      [event] = UzuParser.parse("@Cmaj7")
      assert event.sound == "@Cmaj7"
      assert event.params.jazz_type == :chord
      assert event.params.jazz_value == "Cmaj7"
    end

    test "parses minor chord @Dm7" do
      [event] = UzuParser.parse("@Dm7")
      assert event.params.jazz_type == :chord
      assert event.params.jazz_value == "Dm7"
    end

    test "parses dominant chord @G7" do
      [event] = UzuParser.parse("@G7")
      assert event.params.jazz_type == :chord
      assert event.params.jazz_value == "G7"
    end

    test "parses complex chord @Fmaj7#11" do
      [event] = UzuParser.parse("@Fmaj7#11")
      assert event.params.jazz_type == :chord
      assert event.params.jazz_value == "Fmaj7#11"
    end

    test "parses altered chord @Ab7b5" do
      [event] = UzuParser.parse("@Ab7b5")
      assert event.params.jazz_type == :chord
      assert event.params.jazz_value == "Ab7b5"
    end

    test "parses chord sequence @Dm7 @G7 @Cmaj7" do
      events = UzuParser.parse("@Dm7 @G7 @Cmaj7")
      assert length(events) == 3
      assert Enum.map(events, & &1.params.jazz_value) == ["Dm7", "G7", "Cmaj7"]
    end
  end

  describe "jazz roman numeral tokens" do
    test "parses major roman @I" do
      [event] = UzuParser.parse("@I")
      assert event.sound == "@I"
      assert event.params.jazz_type == :roman
      assert event.params.jazz_value == "I"
    end

    test "parses minor roman @ii" do
      [event] = UzuParser.parse("@ii")
      assert event.params.jazz_type == :roman
      assert event.params.jazz_value == "ii"
    end

    test "parses dominant @V" do
      [event] = UzuParser.parse("@V")
      assert event.params.jazz_type == :roman
      assert event.params.jazz_value == "V"
    end

    test "parses diminished @vii" do
      [event] = UzuParser.parse("@vii")
      assert event.params.jazz_type == :roman
      assert event.params.jazz_value == "vii"
    end

    test "parses roman with quality @ii7" do
      [event] = UzuParser.parse("@ii7")
      assert event.params.jazz_type == :roman
      assert event.params.jazz_value == "ii7"
    end

    test "parses roman with alterations @V7b9" do
      [event] = UzuParser.parse("@V7b9")
      assert event.params.jazz_type == :roman
      assert event.params.jazz_value == "V7b9"
    end

    test "parses flatted roman @bVII" do
      [event] = UzuParser.parse("@bVII")
      assert event.params.jazz_type == :roman
      assert event.params.jazz_value == "bVII"
    end

    test "parses sharped roman @#IV" do
      [event] = UzuParser.parse("@#IV")
      assert event.params.jazz_type == :roman
      assert event.params.jazz_value == "#IV"
    end

    test "parses roman sequence @ii @V @I" do
      events = UzuParser.parse("@ii @V @I")
      assert length(events) == 3
      assert Enum.map(events, & &1.params.jazz_value) == ["ii", "V", "I"]
    end

    test "parses two-five-one @ii7 @V7 @Imaj7" do
      events = UzuParser.parse("@ii7 @V7 @Imaj7")
      assert length(events) == 3
      assert Enum.map(events, & &1.params.jazz_value) == ["ii7", "V7", "Imaj7"]
    end
  end

  describe "jazz tokens in subdivisions" do
    test "parses degrees in brackets" do
      events = UzuParser.parse("[^1 ^3 ^5]")
      assert length(events) == 3
      assert Enum.all?(events, &(&1.params.jazz_type == :degree))
    end

    test "parses chords in brackets" do
      events = UzuParser.parse("[@Dm7 @G7]")
      assert length(events) == 2
      assert Enum.all?(events, &(&1.params.jazz_type == :chord))
    end

    test "parses romans in brackets" do
      events = UzuParser.parse("[@ii @V @I]")
      assert length(events) == 3
      assert Enum.all?(events, &(&1.params.jazz_type == :roman))
    end
  end

  describe "jazz tokens mixed with regular tokens" do
    test "mixes degrees with sounds" do
      events = UzuParser.parse("^1 bd ^3 sd")
      assert length(events) == 4

      assert Enum.at(events, 0).params.jazz_type == :degree
      assert Enum.at(events, 1).sound == "bd"
      assert Enum.at(events, 2).params.jazz_type == :degree
      assert Enum.at(events, 3).sound == "sd"
    end

    test "mixes chords with sounds" do
      events = UzuParser.parse("@Dm7 bd @G7 sd")
      assert length(events) == 4

      assert Enum.at(events, 0).params.jazz_type == :chord
      assert Enum.at(events, 1).sound == "bd"
      assert Enum.at(events, 2).params.jazz_type == :chord
      assert Enum.at(events, 3).sound == "sd"
    end

    test "mixes romans with rests" do
      events = UzuParser.parse("@ii ~ @V ~")
      # Rests are filtered out by default
      roman_events = Enum.filter(events, &Map.has_key?(&1.params, :jazz_type))
      assert length(roman_events) == 2
    end
  end

  describe "edge cases" do
    test "bare @ is treated as sound" do
      [event] = UzuParser.parse("@")
      assert event.sound == "@"
      assert event.params == %{}
    end

    test "@ with number is treated as sound" do
      [event] = UzuParser.parse("@1")
      # Numbers are not valid roman numerals or chord symbols
      assert event.sound == "@1"
      assert event.params == %{}
    end

    test "@ followed by elongation bd@2 is not a jazz token" do
      [event] = UzuParser.parse("bd@2")
      # Should parse as elongation, not as jazz token
      assert event.sound == "bd"
      assert event.params == %{}
      # Weight is internal and affects duration
    end
  end
end
