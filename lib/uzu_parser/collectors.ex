defmodule UzuParser.Collectors do
  @moduledoc """
  String collection utilities for bracket-delimited content.

  These functions collect characters until a closing delimiter is found,
  handling nested brackets correctly and tracking byte positions.
  """

  @doc """
  Collect everything until the matching closing bracket `]`.
  Handles nested brackets correctly.

  Returns `{content, remaining}`.
  """
  def collect_until_bracket_close(str, acc \\ []) do
    collect_until_bracket_close(str, acc, 0)
  end

  defp collect_until_bracket_close("]" <> rest, acc, 0) do
    {IO.iodata_to_binary(Enum.reverse(acc)), rest}
  end

  defp collect_until_bracket_close("]" <> rest, acc, depth) when depth > 0 do
    collect_until_bracket_close(rest, ["]" | acc], depth - 1)
  end

  defp collect_until_bracket_close("[" <> rest, acc, depth) do
    collect_until_bracket_close(rest, ["[" | acc], depth + 1)
  end

  defp collect_until_bracket_close(<<char::utf8, rest::binary>>, acc, depth) do
    collect_until_bracket_close(rest, [<<char::utf8>> | acc], depth)
  end

  defp collect_until_bracket_close("", acc, _depth) do
    {IO.iodata_to_binary(Enum.reverse(acc)), ""}
  end

  @doc """
  Collect everything until the closing angle bracket `>`.

  Returns `{content, remaining}`.
  """
  def collect_until_angle_close(">" <> rest, acc) do
    {IO.iodata_to_binary(Enum.reverse(acc)), rest}
  end

  def collect_until_angle_close(<<char::utf8, rest::binary>>, acc) do
    collect_until_angle_close(rest, [<<char::utf8>> | acc])
  end

  def collect_until_angle_close("", acc) do
    {IO.iodata_to_binary(Enum.reverse(acc)), ""}
  end

  @doc """
  Collect everything until the closing curly bracket `}`.

  Returns `{content, remaining}`.
  """
  def collect_until_curly_close("}" <> rest, acc) do
    {IO.iodata_to_binary(Enum.reverse(acc)), rest}
  end

  def collect_until_curly_close(<<char::utf8, rest::binary>>, acc) do
    collect_until_curly_close(rest, [<<char::utf8>> | acc])
  end

  def collect_until_curly_close("", acc) do
    {IO.iodata_to_binary(Enum.reverse(acc)), ""}
  end

  # ============================================================
  # Position-tracking versions
  # These return {content, remaining, bytes_consumed}
  # ============================================================

  @doc """
  Collect until closing bracket, tracking bytes consumed.

  Returns `{content, remaining, bytes_consumed}`.
  """
  def collect_until_bracket_close_with_length(str, acc \\ []) do
    do_collect_bracket_with_length(str, acc, 0, 0)
  end

  defp do_collect_bracket_with_length("]" <> rest, acc, 0, bytes) do
    {IO.iodata_to_binary(Enum.reverse(acc)), rest, bytes + 1}
  end

  defp do_collect_bracket_with_length("]" <> rest, acc, depth, bytes) when depth > 0 do
    do_collect_bracket_with_length(rest, ["]" | acc], depth - 1, bytes + 1)
  end

  defp do_collect_bracket_with_length("[" <> rest, acc, depth, bytes) do
    do_collect_bracket_with_length(rest, ["[" | acc], depth + 1, bytes + 1)
  end

  defp do_collect_bracket_with_length(<<char::utf8, rest::binary>>, acc, depth, bytes) do
    char_str = <<char::utf8>>
    do_collect_bracket_with_length(rest, [char_str | acc], depth, bytes + byte_size(char_str))
  end

  defp do_collect_bracket_with_length("", acc, _depth, bytes) do
    {IO.iodata_to_binary(Enum.reverse(acc)), "", bytes}
  end

  @doc """
  Collect until closing angle bracket, tracking bytes consumed.

  Returns `{content, remaining, bytes_consumed}`.
  """
  def collect_until_angle_close_with_length(str, acc \\ []) do
    do_collect_angle_with_length(str, acc, 0)
  end

  defp do_collect_angle_with_length(">" <> rest, acc, bytes) do
    {IO.iodata_to_binary(Enum.reverse(acc)), rest, bytes + 1}
  end

  defp do_collect_angle_with_length(<<char::utf8, rest::binary>>, acc, bytes) do
    char_str = <<char::utf8>>
    do_collect_angle_with_length(rest, [char_str | acc], bytes + byte_size(char_str))
  end

  defp do_collect_angle_with_length("", acc, bytes) do
    {IO.iodata_to_binary(Enum.reverse(acc)), "", bytes}
  end

  @doc """
  Collect until closing curly bracket, tracking bytes consumed.

  Returns `{content, remaining, bytes_consumed}`.
  """
  def collect_until_curly_close_with_length(str, acc \\ []) do
    do_collect_curly_with_length(str, acc, 0)
  end

  defp do_collect_curly_with_length("}" <> rest, acc, bytes) do
    {IO.iodata_to_binary(Enum.reverse(acc)), rest, bytes + 1}
  end

  defp do_collect_curly_with_length(<<char::utf8, rest::binary>>, acc, bytes) do
    char_str = <<char::utf8>>
    do_collect_curly_with_length(rest, [char_str | acc], bytes + byte_size(char_str))
  end

  defp do_collect_curly_with_length("", acc, bytes) do
    {IO.iodata_to_binary(Enum.reverse(acc)), "", bytes}
  end

  @doc """
  Collect digits until whitespace or end.

  Returns `{digits_string, remaining}`.
  """
  def collect_number("", acc), do: {IO.iodata_to_binary(Enum.reverse(acc)), ""}

  def collect_number(<<char::utf8, rest::binary>> = str, acc) do
    if String.match?(<<char::utf8>>, ~r/[\d.]/) do
      collect_number(rest, [<<char::utf8>> | acc])
    else
      {IO.iodata_to_binary(Enum.reverse(acc)), str}
    end
  end

  # ============================================================
  # Top-level comma utilities
  # ============================================================

  @doc """
  Check if string has a comma at the top level (not inside nested brackets).
  """
  def has_top_level_comma?(str) do
    do_has_top_level_comma?(str, 0)
  end

  defp do_has_top_level_comma?("", _depth), do: false
  defp do_has_top_level_comma?("," <> _rest, 0), do: true
  defp do_has_top_level_comma?("[" <> rest, depth), do: do_has_top_level_comma?(rest, depth + 1)
  defp do_has_top_level_comma?("]" <> rest, depth), do: do_has_top_level_comma?(rest, max(0, depth - 1))
  defp do_has_top_level_comma?("{" <> rest, depth), do: do_has_top_level_comma?(rest, depth + 1)
  defp do_has_top_level_comma?("}" <> rest, depth), do: do_has_top_level_comma?(rest, max(0, depth - 1))
  defp do_has_top_level_comma?("<" <> rest, depth), do: do_has_top_level_comma?(rest, depth + 1)
  defp do_has_top_level_comma?(">" <> rest, depth), do: do_has_top_level_comma?(rest, max(0, depth - 1))
  defp do_has_top_level_comma?(<<_::utf8, rest::binary>>, depth), do: do_has_top_level_comma?(rest, depth)

  @doc """
  Split string by top-level commas only (respecting nesting).

  Returns list of string parts.
  """
  def split_top_level_comma(str) do
    do_split_top_level_comma(str, [], "", 0)
  end

  defp do_split_top_level_comma("", parts, current, _depth) do
    Enum.reverse([current | parts])
  end

  defp do_split_top_level_comma("," <> rest, parts, current, 0) do
    do_split_top_level_comma(rest, [current | parts], "", 0)
  end

  defp do_split_top_level_comma("[" <> rest, parts, current, depth) do
    do_split_top_level_comma(rest, parts, current <> "[", depth + 1)
  end

  defp do_split_top_level_comma("]" <> rest, parts, current, depth) do
    do_split_top_level_comma(rest, parts, current <> "]", max(0, depth - 1))
  end

  defp do_split_top_level_comma("{" <> rest, parts, current, depth) do
    do_split_top_level_comma(rest, parts, current <> "{", depth + 1)
  end

  defp do_split_top_level_comma("}" <> rest, parts, current, depth) do
    do_split_top_level_comma(rest, parts, current <> "}", max(0, depth - 1))
  end

  defp do_split_top_level_comma("<" <> rest, parts, current, depth) do
    do_split_top_level_comma(rest, parts, current <> "<", depth + 1)
  end

  defp do_split_top_level_comma(">" <> rest, parts, current, depth) do
    do_split_top_level_comma(rest, parts, current <> ">", max(0, depth - 1))
  end

  defp do_split_top_level_comma(<<char::utf8, rest::binary>>, parts, current, depth) do
    do_split_top_level_comma(rest, parts, current <> <<char::utf8>>, depth)
  end
end
