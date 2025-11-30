defmodule UzuParser.CollectorsTest do
  use ExUnit.Case, async: true

  alias UzuParser.Collectors

  describe "collect_until_bracket_close/1" do
    test "collects simple content" do
      assert {"bd sd", ""} = Collectors.collect_until_bracket_close("bd sd]")
    end

    test "handles empty content" do
      assert {"", ""} = Collectors.collect_until_bracket_close("]")
    end

    test "handles nested brackets" do
      assert {"[bd sd] hh", ""} = Collectors.collect_until_bracket_close("[bd sd] hh]")
    end

    test "handles deeply nested brackets" do
      assert {"[[bd] sd]", ""} = Collectors.collect_until_bracket_close("[[bd] sd]]")
    end

    test "returns remaining content after closing bracket" do
      assert {"bd", " sd hh"} = Collectors.collect_until_bracket_close("bd] sd hh")
    end

    test "handles unclosed bracket gracefully" do
      assert {"bd sd", ""} = Collectors.collect_until_bracket_close("bd sd")
    end

    test "handles utf8 characters" do
      assert {"bd \u00e9 sd", ""} = Collectors.collect_until_bracket_close("bd \u00e9 sd]")
    end
  end

  describe "collect_until_angle_close/2" do
    test "collects simple content" do
      assert {"bd sd hh", ""} = Collectors.collect_until_angle_close("bd sd hh>", [])
    end

    test "handles empty content" do
      assert {"", ""} = Collectors.collect_until_angle_close(">", [])
    end

    test "returns remaining content after closing angle bracket" do
      assert {"bd sd", " rest"} = Collectors.collect_until_angle_close("bd sd> rest", [])
    end

    test "handles unclosed angle bracket gracefully" do
      assert {"bd sd", ""} = Collectors.collect_until_angle_close("bd sd", [])
    end
  end

  describe "collect_until_curly_close/2" do
    test "collects simple content" do
      assert {"bd sd, cp", ""} = Collectors.collect_until_curly_close("bd sd, cp}", [])
    end

    test "handles empty content" do
      assert {"", ""} = Collectors.collect_until_curly_close("}", [])
    end

    test "returns remaining content after closing curly bracket" do
      assert {"bd, sd", " rest"} = Collectors.collect_until_curly_close("bd, sd} rest", [])
    end

    test "handles unclosed curly bracket gracefully" do
      assert {"bd sd", ""} = Collectors.collect_until_curly_close("bd sd", [])
    end
  end

  describe "collect_until_bracket_close_with_length/1" do
    test "returns bytes consumed for simple content" do
      {content, remaining, bytes} = Collectors.collect_until_bracket_close_with_length("bd sd]")
      assert content == "bd sd"
      assert remaining == ""
      assert bytes == 6
    end

    test "handles nested brackets with correct byte count" do
      {content, remaining, bytes} = Collectors.collect_until_bracket_close_with_length("[bd] sd]")
      assert content == "[bd] sd"
      assert remaining == ""
      assert bytes == 8
    end

    test "handles utf8 characters with correct byte count" do
      {content, remaining, bytes} = Collectors.collect_until_bracket_close_with_length("\u00e9]")
      assert content == "\u00e9"
      assert remaining == ""
      assert bytes == 3
    end
  end

  describe "collect_until_angle_close_with_length/1" do
    test "returns bytes consumed" do
      {content, remaining, bytes} = Collectors.collect_until_angle_close_with_length("bd sd>")
      assert content == "bd sd"
      assert remaining == ""
      assert bytes == 6
    end
  end

  describe "collect_until_curly_close_with_length/1" do
    test "returns bytes consumed" do
      {content, remaining, bytes} = Collectors.collect_until_curly_close_with_length("bd, sd}")
      assert content == "bd, sd"
      assert remaining == ""
      assert bytes == 7
    end
  end

  describe "collect_number/2" do
    test "collects integer" do
      assert {"123", ""} = Collectors.collect_number("123", [])
    end

    test "collects float" do
      assert {"12.5", ""} = Collectors.collect_number("12.5", [])
    end

    test "stops at whitespace" do
      assert {"123", " rest"} = Collectors.collect_number("123 rest", [])
    end

    test "stops at non-digit" do
      assert {"123", "abc"} = Collectors.collect_number("123abc", [])
    end

    test "handles empty string" do
      assert {"", ""} = Collectors.collect_number("", [])
    end

    test "handles non-digit start" do
      assert {"", "abc"} = Collectors.collect_number("abc", [])
    end
  end

  describe "has_top_level_comma?/1" do
    test "detects comma at top level" do
      assert Collectors.has_top_level_comma?("bd,sd")
    end

    test "returns false for no comma" do
      refute Collectors.has_top_level_comma?("bd sd")
    end

    test "ignores comma inside brackets" do
      refute Collectors.has_top_level_comma?("[bd,sd]")
    end

    test "ignores comma inside curly braces" do
      refute Collectors.has_top_level_comma?("{bd,sd}")
    end

    test "ignores comma inside angle brackets" do
      refute Collectors.has_top_level_comma?("<bd,sd>")
    end

    test "detects comma outside nested brackets" do
      assert Collectors.has_top_level_comma?("[bd],sd")
    end

    test "handles empty string" do
      refute Collectors.has_top_level_comma?("")
    end

    test "handles deeply nested content" do
      refute Collectors.has_top_level_comma?("[[bd,sd],hh]")
    end

    test "detects comma after nested content" do
      assert Collectors.has_top_level_comma?("[bd sd],hh")
    end
  end

  describe "split_top_level_comma/1" do
    test "splits simple comma-separated values" do
      assert ["bd", "sd"] = Collectors.split_top_level_comma("bd,sd")
    end

    test "splits multiple values" do
      assert ["bd", "sd", "hh"] = Collectors.split_top_level_comma("bd,sd,hh")
    end

    test "preserves brackets in parts" do
      assert ["[bd sd]", "hh"] = Collectors.split_top_level_comma("[bd sd],hh")
    end

    test "preserves curly braces in parts" do
      assert ["{bd sd}", "hh"] = Collectors.split_top_level_comma("{bd sd},hh")
    end

    test "preserves angle brackets in parts" do
      assert ["<bd sd>", "hh"] = Collectors.split_top_level_comma("<bd sd>,hh")
    end

    test "handles nested content with internal commas" do
      assert ["[bd,sd]", "hh"] = Collectors.split_top_level_comma("[bd,sd],hh")
    end

    test "handles no comma" do
      assert ["bd sd"] = Collectors.split_top_level_comma("bd sd")
    end

    test "handles empty string" do
      assert [""] = Collectors.split_top_level_comma("")
    end

    test "handles mixed bracket types" do
      assert ["[bd {a,b}]", "sd"] = Collectors.split_top_level_comma("[bd {a,b}],sd")
    end
  end
end
