defmodule UzuParser.Structure do
  @moduledoc """
  Structure parsing for mini-notation patterns.

  Handles parsing of structural elements:
  - Subdivisions: `[bd sd]`
  - Alternations: `<bd sd hh>`
  - Polymetric sequences: `{bd sd, cp}`

  These functions require tokenizer and flattener functions to be passed
  in to avoid circular dependencies with the main UzuParser module.
  """

  alias UzuParser.Collectors
  alias UzuParser.TokenParser

  @doc """
  Parse subdivision content: "bd sd" -> {:subdivision, [tokens]}

  For polyphonic content with commas like "bd,sd", creates a chord.

  ## Parameters
  - `inner` - the string content inside brackets
  - `tokenize_fn` - function(string) to tokenize nested content
  - `flatten_token_fn` - function to flatten tokens (for chord sounds)
  """
  def parse_subdivision(inner, tokenize_fn, flatten_token_fn) do
    if Collectors.has_top_level_comma?(inner) do
      # Parse as a chord - flatten any repetitions so we get individual sounds
      sounds =
        inner
        |> Collectors.split_top_level_comma()
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(&TokenParser.parse/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.flat_map(flatten_token_fn)

      {:subdivision, [{:chord, sounds}]}
    else
      # Parse as regular subdivision
      subtokens =
        tokenize_fn.(inner)
        |> Enum.reject(&is_nil/1)

      {:subdivision, subtokens}
    end
  end

  @doc """
  Parse alternation content: "bd sd hh" -> {:alternate, [options]}

  Cycles through options sequentially based on cycle number.
  Simple space-separated tokens, no nested tokenization needed.
  """
  def parse_alternation(inner) do
    options =
      inner
      |> String.split()
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&TokenParser.parse/1)
      |> Enum.reject(&is_nil/1)

    case options do
      [] -> nil
      [single] -> single
      multiple -> {:alternate, multiple}
    end
  end

  @doc """
  Parse polymetric sequence: "bd sd hh, cp" -> {:polymetric, [groups]}

  Each group is independently timed over the cycle.

  ## Parameters
  - `inner` - the string content inside curly braces
  - `tokenize_fn` - function(string) to tokenize each group
  """
  def parse_polymetric(inner, tokenize_fn) do
    groups =
      inner
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn group ->
        tokenize_fn.(group)
        |> Enum.reject(&is_nil/1)
      end)
      |> Enum.reject(&(&1 == []))

    case groups do
      [] -> nil
      [single] -> {:subdivision, single}
      multiple -> {:polymetric, multiple}
    end
  end
end
