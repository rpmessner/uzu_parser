defmodule UzuParser.TokenParserTest do
  use ExUnit.Case, async: true

  alias UzuParser.TokenParser

  describe "parse/1 basic tokens" do
    test "returns nil for empty string" do
      assert nil == TokenParser.parse("")
    end

    test "parses rest ~" do
      assert :rest == TokenParser.parse("~")
    end

    test "parses elongate _" do
      assert :elongate == TokenParser.parse("_")
    end

    test "parses simple sound" do
      assert {:sound, "bd", nil, nil, nil} == TokenParser.parse("bd")
    end

    test "parses sound with different names" do
      assert {:sound, "hh", nil, nil, nil} == TokenParser.parse("hh")
      assert {:sound, "cp", nil, nil, nil} == TokenParser.parse("cp")
      assert {:sound, "bass", nil, nil, nil} == TokenParser.parse("bass")
    end
  end

  describe "parse/1 sample selection" do
    test "parses sound with sample bd:0" do
      assert {:sound, "bd", 0, nil, nil} == TokenParser.parse("bd:0")
    end

    test "parses sound with sample bd:5" do
      assert {:sound, "bd", 5, nil, nil} == TokenParser.parse("bd:5")
    end

    test "handles invalid sample number" do
      assert {:sound, "bd:abc", nil, nil, nil} == TokenParser.parse("bd:abc")
    end

    test "handles negative sample number" do
      assert {:sound, "bd:-1", nil, nil, nil} == TokenParser.parse("bd:-1")
    end
  end

  describe "parse/1 probability" do
    test "parses default probability bd?" do
      assert {:sound, "bd", nil, 0.5, nil} == TokenParser.parse("bd?")
    end

    test "parses custom probability bd?0.25" do
      assert {:sound, "bd", nil, 0.25, nil} == TokenParser.parse("bd?0.25")
    end

    test "parses probability 0.0" do
      assert {:sound, "bd", nil, 0.0, nil} == TokenParser.parse("bd?0.0")
    end

    test "parses probability 1.0" do
      assert {:sound, "bd", nil, 1.0, nil} == TokenParser.parse("bd?1.0")
    end

    test "handles invalid probability > 1" do
      assert {:sound, "bd?1.5", nil, nil, nil} == TokenParser.parse("bd?1.5")
    end

    test "parses probability with sample selection" do
      assert {:sound, "bd", 0, 0.5, nil} == TokenParser.parse("bd:0?")
    end

    test "parses probability with sample and custom value" do
      assert {:sound, "bd", 1, 0.75, nil} == TokenParser.parse("bd:1?0.75")
    end
  end

  describe "parse/1 elongation (weight)" do
    test "parses integer weight bd@2" do
      assert {:sound, "bd", nil, nil, 2.0} == TokenParser.parse("bd@2")
    end

    test "parses float weight bd@1.5" do
      assert {:sound, "bd", nil, nil, 1.5} == TokenParser.parse("bd@1.5")
    end

    test "parses weight with sample selection" do
      assert {:sound, "bd", 0, nil, 2.0} == TokenParser.parse("bd:0@2")
    end

    test "handles invalid weight bd@0" do
      assert {:sound, "bd@0", nil, nil, nil} == TokenParser.parse("bd@0")
    end

    test "handles invalid weight bd@-1" do
      assert {:sound, "bd@-1", nil, nil, nil} == TokenParser.parse("bd@-1")
    end
  end

  describe "parse/1 repetition" do
    test "parses simple repetition bd*4" do
      result = TokenParser.parse("bd*4")
      assert {:repeat, sounds} = result
      assert length(sounds) == 4
      assert Enum.all?(sounds, &(&1 == {:sound, "bd", nil, nil, nil}))
    end

    test "parses repetition with sample bd:1*3" do
      result = TokenParser.parse("bd:1*3")
      assert {:repeat, sounds} = result
      assert length(sounds) == 3
      assert Enum.all?(sounds, &(&1 == {:sound, "bd", 1, nil, nil}))
    end

    test "handles invalid repetition bd*0" do
      assert {:sound, "bd*0", nil, nil, nil} == TokenParser.parse("bd*0")
    end

    test "handles invalid repetition bd*abc" do
      assert {:sound, "bd*abc", nil, nil, nil} == TokenParser.parse("bd*abc")
    end
  end

  describe "parse/1 replication" do
    test "parses simple replication bd!3" do
      result = TokenParser.parse("bd!3")
      assert {:repeat, sounds} = result
      assert length(sounds) == 3
      assert Enum.all?(sounds, &(&1 == {:sound, "bd", nil, nil, nil}))
    end

    test "parses replication with sample bd:1!2" do
      result = TokenParser.parse("bd:1!2")
      assert {:repeat, sounds} = result
      assert length(sounds) == 2
      assert Enum.all?(sounds, &(&1 == {:sound, "bd", 1, nil, nil}))
    end

    test "handles invalid replication bd!0" do
      assert {:sound, "bd!0", nil, nil, nil} == TokenParser.parse("bd!0")
    end
  end

  describe "parse/1 euclidean rhythms" do
    test "parses euclidean bd(3,8)" do
      assert {:euclidean, "bd", nil, 3, 8, 0} == TokenParser.parse("bd(3,8)")
    end

    test "parses euclidean with offset bd(3,8,2)" do
      assert {:euclidean, "bd", nil, 3, 8, 2} == TokenParser.parse("bd(3,8,2)")
    end

    test "parses euclidean with sample bd:1(3,8)" do
      assert {:euclidean, "bd", 1, 3, 8, 0} == TokenParser.parse("bd:1(3,8)")
    end

    test "handles invalid euclidean k > n" do
      assert {:sound, "bd(5,3)", nil, nil, nil} == TokenParser.parse("bd(5,3)")
    end

    test "handles invalid euclidean k = 0" do
      assert {:sound, "bd(0,8)", nil, nil, nil} == TokenParser.parse("bd(0,8)")
    end

    test "handles malformed euclidean" do
      assert {:sound, "bd(3,)", nil, nil, nil} == TokenParser.parse("bd(3,)")
    end
  end

  describe "parse/1 division" do
    test "parses division bd/2" do
      assert {:division, "bd", nil, 2.0} == TokenParser.parse("bd/2")
    end

    test "parses division with sample bd:1/4" do
      assert {:division, "bd", 1, 4.0} == TokenParser.parse("bd:1/4")
    end

    test "parses fractional division bd/1.5" do
      assert {:division, "bd", nil, 1.5} == TokenParser.parse("bd/1.5")
    end

    test "handles invalid division bd/0" do
      assert {:sound, "bd/0", nil, nil, nil} == TokenParser.parse("bd/0")
    end

    test "handles invalid division bd/abc" do
      assert {:sound, "bd/abc", nil, nil, nil} == TokenParser.parse("bd/abc")
    end
  end

  describe "parse/1 ratio" do
    test "parses ratio bd%2" do
      assert {:ratio, "bd", nil, 2.0} == TokenParser.parse("bd%2")
    end

    test "parses ratio with sample bd:1%3" do
      assert {:ratio, "bd", 1, 3.0} == TokenParser.parse("bd:1%3")
    end

    test "parses fractional ratio bd%0.5" do
      assert {:ratio, "bd", nil, 0.5} == TokenParser.parse("bd%0.5")
    end

    test "handles invalid ratio bd%0" do
      assert {:sound, "bd%0", nil, nil, nil} == TokenParser.parse("bd%0")
    end
  end

  describe "parse/1 random choice" do
    test "parses two options bd|sd" do
      result = TokenParser.parse("bd|sd")
      assert {:random_choice, options} = result
      assert length(options) == 2
      assert Enum.at(options, 0) == {:sound, "bd", nil, nil, nil}
      assert Enum.at(options, 1) == {:sound, "sd", nil, nil, nil}
    end

    test "parses three options bd|sd|hh" do
      result = TokenParser.parse("bd|sd|hh")
      assert {:random_choice, options} = result
      assert length(options) == 3
    end

    test "parses options with sample selection bd:0|sd:1" do
      result = TokenParser.parse("bd:0|sd:1")
      assert {:random_choice, options} = result
      assert Enum.at(options, 0) == {:sound, "bd", 0, nil, nil}
      assert Enum.at(options, 1) == {:sound, "sd", 1, nil, nil}
    end

    test "single option degrades to sound" do
      assert {:sound, "bd", nil, nil, nil} == TokenParser.parse("bd|")
    end

    test "parses option with rest bd|~" do
      result = TokenParser.parse("bd|~")
      assert {:random_choice, options} = result
      assert Enum.at(options, 0) == {:sound, "bd", nil, nil, nil}
      assert Enum.at(options, 1) == :rest
    end
  end

  describe "parse/1 sound parameters" do
    test "parses single parameter bd|gain:0.8" do
      result = TokenParser.parse("bd|gain:0.8")
      assert {:sound_with_params, "bd", nil, %{gain: 0.8}} = result
    end

    test "parses multiple parameters bd|speed:2|pan:0.5" do
      result = TokenParser.parse("bd|speed:2|pan:0.5")
      assert {:sound_with_params, "bd", nil, params} = result
      assert params == %{speed: 2.0, pan: 0.5}
    end

    test "parses parameters with sample selection bd:1|gain:0.8" do
      result = TokenParser.parse("bd:1|gain:0.8")
      assert {:sound_with_params, "bd", 1, %{gain: 0.8}} = result
    end

    test "ignores unknown parameters" do
      result = TokenParser.parse("bd|gain:0.8|unknown:1.0")
      assert {:sound_with_params, "bd", nil, params} = result
      assert params == %{gain: 0.8}
      refute Map.has_key?(params, :unknown)
    end

    test "parses all supported parameters" do
      result = TokenParser.parse("bd|gain:0.8|speed:1.5|pan:-0.5|cutoff:500|resonance:0.7|delay:0.3|room:0.5")
      assert {:sound_with_params, "bd", nil, params} = result
      assert params.gain == 0.8
      assert params.speed == 1.5
      assert params.pan == -0.5
      assert params.cutoff == 500.0
      assert params.resonance == 0.7
      assert params.delay == 0.3
      assert params.room == 0.5
    end
  end

  describe "parse/1 jazz tokens - degrees" do
    test "parses simple degree ^1" do
      assert {:degree, 1} == TokenParser.parse("^1")
    end

    test "parses degree ^7" do
      assert {:degree, 7} == TokenParser.parse("^7")
    end

    test "parses extended degree ^13" do
      assert {:degree, 13} == TokenParser.parse("^13")
    end

    test "parses flatted degree ^b7" do
      assert {:degree, "b7"} == TokenParser.parse("^b7")
    end

    test "parses sharped degree ^#5" do
      assert {:degree, "#5"} == TokenParser.parse("^#5")
    end

    test "handles invalid degree ^0" do
      assert {:sound, "^0", nil, nil, nil} == TokenParser.parse("^0")
    end

    test "handles invalid degree ^14" do
      assert {:sound, "^14", nil, nil, nil} == TokenParser.parse("^14")
    end

    test "handles bare ^" do
      assert {:sound, "^", nil, nil, nil} == TokenParser.parse("^")
    end
  end

  describe "parse/1 jazz tokens - chords" do
    test "parses chord @Dm7" do
      assert {:chord, "Dm7"} == TokenParser.parse("@Dm7")
    end

    test "parses chord @Cmaj7" do
      assert {:chord, "Cmaj7"} == TokenParser.parse("@Cmaj7")
    end

    test "parses chord @G7" do
      assert {:chord, "G7"} == TokenParser.parse("@G7")
    end

    test "parses complex chord @Fmaj7#11" do
      assert {:chord, "Fmaj7#11"} == TokenParser.parse("@Fmaj7#11")
    end
  end

  describe "parse/1 jazz tokens - roman numerals" do
    test "parses major roman @I" do
      assert {:roman, "I"} == TokenParser.parse("@I")
    end

    test "parses minor roman @ii" do
      assert {:roman, "ii"} == TokenParser.parse("@ii")
    end

    test "parses dominant @V" do
      assert {:roman, "V"} == TokenParser.parse("@V")
    end

    test "parses roman with quality @ii7" do
      assert {:roman, "ii7"} == TokenParser.parse("@ii7")
    end

    test "parses flatted roman @bVII" do
      assert {:roman, "bVII"} == TokenParser.parse("@bVII")
    end

    test "parses sharped roman @#IV" do
      assert {:roman, "#IV"} == TokenParser.parse("@#IV")
    end
  end

  describe "parse/1 jazz edge cases" do
    test "bare @ is treated as sound" do
      assert {:sound, "@", nil, nil, nil} == TokenParser.parse("@")
    end

    test "@ with number is treated as sound" do
      assert {:sound, "@1", nil, nil, nil} == TokenParser.parse("@1")
    end

    test "bd@2 is elongation not jazz token" do
      assert {:sound, "bd", nil, nil, 2.0} == TokenParser.parse("bd@2")
    end
  end

  describe "parse_sound_part/1" do
    test "parses simple sound" do
      assert {"bd", nil} == TokenParser.parse_sound_part("bd")
    end

    test "parses sound with sample" do
      assert {"bd", 0} == TokenParser.parse_sound_part("bd:0")
    end

    test "parses sound with higher sample number" do
      assert {"bd", 5} == TokenParser.parse_sound_part("bd:5")
    end

    test "handles invalid sample number" do
      assert {"bd:abc", nil} == TokenParser.parse_sound_part("bd:abc")
    end
  end

  describe "parse_number/1" do
    test "parses integer" do
      assert {123.0, ""} == TokenParser.parse_number("123")
    end

    test "parses float" do
      assert {1.5, ""} == TokenParser.parse_number("1.5")
    end

    test "parses negative" do
      assert {-0.5, ""} == TokenParser.parse_number("-0.5")
    end

    test "returns error for invalid" do
      assert :error == TokenParser.parse_number("abc")
    end

    test "parses number with remainder" do
      assert {123.0, "abc"} == TokenParser.parse_number("123abc")
    end
  end

  describe "probability with repetition" do
    test "applies probability to all repeated sounds" do
      result = TokenParser.parse("bd*3?")
      assert {:repeat, sounds} = result
      assert length(sounds) == 3
      assert Enum.all?(sounds, fn {:sound, "bd", nil, prob, nil} -> prob == 0.5 end)
    end

    test "applies custom probability to all repeated sounds" do
      result = TokenParser.parse("bd*2?0.25")
      assert {:repeat, sounds} = result
      assert Enum.all?(sounds, fn {:sound, "bd", nil, prob, nil} -> prob == 0.25 end)
    end
  end

  describe "weight with repetition" do
    test "applies weight to all repeated sounds" do
      result = TokenParser.parse("bd*2@3")
      assert {:repeat, sounds} = result
      assert length(sounds) == 2
      assert Enum.all?(sounds, fn {:sound, "bd", nil, nil, weight} -> weight == 3.0 end)
    end
  end
end
