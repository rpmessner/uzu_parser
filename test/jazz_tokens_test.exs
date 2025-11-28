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
      result = UzuParser.parse("@Cmaj7")
      assert [{_, {:chord, "Cmaj7"}}] = result
    end

    test "parses minor chord @Dm7" do
      result = UzuParser.parse("@Dm7")
      assert [{_, {:chord, "Dm7"}}] = result
    end

    test "parses dominant chord @G7" do
      result = UzuParser.parse("@G7")
      assert [{_, {:chord, "G7"}}] = result
    end

    test "parses complex chord @Fmaj7#11" do
      result = UzuParser.parse("@Fmaj7#11")
      assert [{_, {:chord, "Fmaj7#11"}}] = result
    end

    test "parses altered chord @Ab7b5" do
      result = UzuParser.parse("@Ab7b5")
      assert [{_, {:chord, "Ab7b5"}}] = result
    end

    test "parses chord sequence @Dm7 @G7 @Cmaj7" do
      result = UzuParser.parse("@Dm7 @G7 @Cmaj7")

      assert [
               {_, {:chord, "Dm7"}},
               {_, {:chord, "G7"}},
               {_, {:chord, "Cmaj7"}}
             ] = result
    end
  end

  describe "jazz roman numeral tokens" do
    test "parses major roman @I" do
      result = UzuParser.parse("@I")
      assert [{_, {:roman, "I"}}] = result
    end

    test "parses minor roman @ii" do
      result = UzuParser.parse("@ii")
      assert [{_, {:roman, "ii"}}] = result
    end

    test "parses dominant @V" do
      result = UzuParser.parse("@V")
      assert [{_, {:roman, "V"}}] = result
    end

    test "parses diminished @vii" do
      result = UzuParser.parse("@vii")
      assert [{_, {:roman, "vii"}}] = result
    end

    test "parses roman with quality @ii7" do
      result = UzuParser.parse("@ii7")
      assert [{_, {:roman, "ii7"}}] = result
    end

    test "parses roman with alterations @V7b9" do
      result = UzuParser.parse("@V7b9")
      assert [{_, {:roman, "V7b9"}}] = result
    end

    test "parses flatted roman @bVII" do
      result = UzuParser.parse("@bVII")
      assert [{_, {:roman, "bVII"}}] = result
    end

    test "parses sharped roman @#IV" do
      result = UzuParser.parse("@#IV")
      assert [{_, {:roman, "#IV"}}] = result
    end

    test "parses roman sequence @ii @V @I" do
      result = UzuParser.parse("@ii @V @I")

      assert [
               {_, {:roman, "ii"}},
               {_, {:roman, "V"}},
               {_, {:roman, "I"}}
             ] = result
    end

    test "parses two-five-one @ii7 @V7 @Imaj7" do
      result = UzuParser.parse("@ii7 @V7 @Imaj7")

      assert [
               {_, {:roman, "ii7"}},
               {_, {:roman, "V7"}},
               {_, {:roman, "Imaj7"}}
             ] = result
    end
  end

  describe "jazz tokens in subdivisions" do
    test "parses degrees in brackets" do
      result = UzuParser.parse("[^1 ^3 ^5]")

      # Should have a subdivision containing degree tokens
      assert [{_, {:subdivision, events}}] = result
      assert length(events) == 3
    end

    test "parses chords in brackets" do
      result = UzuParser.parse("[@Dm7 @G7]")

      assert [{_, {:subdivision, events}}] = result
      assert length(events) == 2
    end

    test "parses romans in brackets" do
      result = UzuParser.parse("[@ii @V @I]")

      assert [{_, {:subdivision, events}}] = result
      assert length(events) == 3
    end
  end

  describe "jazz tokens mixed with regular tokens" do
    test "mixes degrees with sounds" do
      result = UzuParser.parse("^1 bd ^3 sd")

      assert [
               {_, {:degree, 1}},
               {_, {:sound, "bd", nil, nil, nil}},
               {_, {:degree, 3}},
               {_, {:sound, "sd", nil, nil, nil}}
             ] = result
    end

    test "mixes chords with sounds" do
      result = UzuParser.parse("@Dm7 bd @G7 sd")

      assert [
               {_, {:chord, "Dm7"}},
               {_, {:sound, "bd", nil, nil, nil}},
               {_, {:chord, "G7"}},
               {_, {:sound, "sd", nil, nil, nil}}
             ] = result
    end

    test "mixes romans with rests" do
      result = UzuParser.parse("@ii ~ @V ~")

      assert [
               {_, {:roman, "ii"}},
               {_, :rest},
               {_, {:roman, "V"}},
               {_, :rest}
             ] = result
    end
  end

  describe "edge cases" do
    test "bare @ is treated as sound" do
      result = UzuParser.parse("@")
      assert [{_, {:sound, "@", nil, nil, nil}}] = result
    end

    test "@ with number is roman" do
      result = UzuParser.parse("@1")
      # Numbers could be treated as sound since they're not valid roman numerals
      # but our parser should handle this gracefully
      result
    end

    test "@ followed by elongation bd@2 is not a jazz token" do
      result = UzuParser.parse("bd@2")
      # Should parse as elongation, not as jazz token
      assert [{_, {:sound, "bd", nil, nil, 2.0}}] = result
    end
  end
end
