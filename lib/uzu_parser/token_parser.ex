defmodule UzuParser.TokenParser do
  @moduledoc """
  Token parsing for mini-notation patterns.

  Handles parsing of individual tokens including:
  - Sound tokens: "bd", "bd:0"
  - Modifiers: probability (?), elongation (@), replication (!), repetition (*)
  - Euclidean rhythms: "bd(3,8)"
  - Division/ratio: "bd/2", "bd%2"
  - Random choice: "bd|sd|hh"
  - Jazz notation: "^1", "@Dm7", "@ii"
  - Sound parameters: "bd|gain:0.8|speed:2"
  """

  # Known sound parameters
  @sound_params ~w(gain speed pan cutoff resonance delay room)

  @doc """
  Parse an individual token from mini-notation.

  Returns various token types:
  - `:rest` - silence (~)
  - `:elongate` - hold previous note (_)
  - `{:sound, name, sample, probability, weight}` - basic sound
  - `{:repeat, sounds}` - repeated sounds
  - `{:euclidean, sound, sample, k, n, offset}` - euclidean rhythm
  - `{:division, sound, sample, divisor}` - slowed pattern
  - `{:ratio, sound, sample, cycles}` - speed ratio
  - `{:random_choice, options}` - random selection
  - `{:degree, degree}` - jazz scale degree
  - `{:chord, symbol}` - chord symbol
  - `{:roman, numeral}` - roman numeral
  - `{:sound_with_params, sound, sample, params}` - sound with parameters
  """
  def parse(""), do: nil
  def parse("~"), do: :rest
  def parse("_"), do: :elongate

  def parse(token) do
    cond do
      # Handle jazz scale degree: "^1", "^3", "^5", "^7" (check before @ for elongation)
      String.starts_with?(token, "^") ->
        parse_degree(token)

      # Handle jazz chord/roman: "@Dm7", "@ii", "@V" (check before @ for elongation)
      String.starts_with?(token, "@") and not String.contains?(String.slice(token, 1..-1//1), "@") ->
        parse_chord_or_roman(token)

      # Handle probability: "bd?" or "bd?0.25" (must check before other operators)
      String.contains?(token, "?") ->
        parse_probability(token)

      # Handle elongation: "bd@2" (must check before repetition due to precedence)
      String.contains?(token, "@") ->
        parse_elongation(token)

      # Handle replication: "bd!3" (like repetition but different semantics)
      String.contains?(token, "!") ->
        parse_replication(token)

      # Handle repetition: "bd*4" or "bd:1*4"
      String.contains?(token, "*") ->
        parse_repetition(token)

      # Handle random choice: "bd|sd|hh"
      String.contains?(token, "|") ->
        parse_random_choice(token)

      # Handle euclidean rhythms: "bd(3,8)" or "bd(3,8,2)"
      String.contains?(token, "(") ->
        parse_euclidean(token)

      # Handle division: "bd/2" (slow down over cycles)
      String.contains?(token, "/") ->
        parse_division(token)

      # Handle ratio/speed: "bd%2" (spans multiple cycles)
      String.contains?(token, "%") ->
        parse_ratio(token)

      # Handle sample selection: "bd:0"
      String.contains?(token, ":") ->
        parse_sample_selection(token)

      # Simple sound
      true ->
        {:sound, token, nil, nil, nil}
    end
  end

  @doc """
  Parse the sound part which may include sample selection: "bd" or "bd:0"
  Returns {sound, sample} tuple.
  """
  def parse_sound_part(sound_part) do
    case String.split(sound_part, ":") do
      [sound, sample_str] ->
        case Integer.parse(sample_str) do
          {sample, ""} when sample >= 0 -> {sound, sample}
          _ -> {sound_part, nil}
        end

      _ ->
        {sound_part, nil}
    end
  end

  # Parse probability: "bd?" or "bd?0.25" or "bd:0?" -> {:sound, "bd", sample, probability, weight}
  defp parse_probability(token) do
    case String.split(token, "?", parts: 2) do
      [sound_part, ""] ->
        # "bd?" - default 50% probability
        base_token = parse_token_without_modifiers(sound_part, [:probability])
        add_probability_to_token(base_token, 0.5)

      [sound_part, prob_str] ->
        # "bd?0.25" - custom probability
        case Float.parse(prob_str) do
          {prob, ""} when prob >= 0.0 and prob <= 1.0 ->
            base_token = parse_token_without_modifiers(sound_part, [:probability])
            add_probability_to_token(base_token, prob)

          _ ->
            # Invalid probability, treat as literal
            {:sound, token, nil, nil, nil}
        end

      _ ->
        {:sound, token, nil, nil, nil}
    end
  end

  # Parse elongation: "bd@2" or "bd:0@3" -> {:sound, "bd", sample, probability, weight}
  defp parse_elongation(token) do
    case String.split(token, "@", parts: 2) do
      [sound_part, weight_str] ->
        # Parse weight as positive number
        parsed = parse_number(weight_str)

        case parsed do
          {weight, ""} when weight > 0 ->
            base_token = parse_token_without_modifiers(sound_part, [:elongation])
            add_weight_to_token(base_token, weight)

          _ ->
            # Invalid weight, treat as literal
            {:sound, token, nil, nil, nil}
        end

      _ ->
        {:sound, token, nil, nil, nil}
    end
  end

  @doc """
  Parse a number as either integer or float.
  Returns `{number, rest}` or `:error`.
  """
  def parse_number(str) do
    # Try float first since it handles both integers and floats
    case Float.parse(str) do
      {float, rest} -> {float, rest}
      :error -> :error
    end
  end

  # Parse token without specific modifiers (used by parse_probability and parse_elongation)
  defp parse_token_without_modifiers(token, skip_modifiers) do
    cond do
      # Handle elongation: "bd@2" (unless we're already parsing elongation)
      String.contains?(token, "@") and :elongation not in skip_modifiers ->
        parse_elongation(token)

      # Handle replication: "bd!3"
      String.contains?(token, "!") ->
        parse_replication(token)

      # Handle repetition: "bd*4" or "bd:1*4"
      String.contains?(token, "*") ->
        parse_repetition(token)

      # Handle sample selection: "bd:0"
      String.contains?(token, ":") ->
        parse_sample_selection(token)

      # Simple sound
      true ->
        {:sound, token, nil, nil, nil}
    end
  end

  # Add probability to a token (handles sound and repeat tokens)
  defp add_probability_to_token({:sound, name, sample, _, weight}, prob) do
    {:sound, name, sample, prob, weight}
  end

  defp add_probability_to_token({:repeat, sounds}, prob) do
    # Apply probability to each sound in the repetition
    {:repeat, Enum.map(sounds, &add_probability_to_token(&1, prob))}
  end

  defp add_probability_to_token(token, _prob), do: token

  # Add weight to a token (handles sound and repeat tokens)
  defp add_weight_to_token({:sound, name, sample, probability, _}, weight) do
    {:sound, name, sample, probability, weight}
  end

  defp add_weight_to_token({:repeat, sounds}, weight) do
    # Apply weight to each sound in the repetition
    {:repeat, Enum.map(sounds, &add_weight_to_token(&1, weight))}
  end

  defp add_weight_to_token(token, _weight), do: token

  # Parse jazz scale degree: "^1", "^3", "^b7", "^#5" -> {:degree, degree}
  defp parse_degree(token) do
    case String.slice(token, 1..-1//1) do
      "" ->
        # Just "^" with no number, treat as literal
        {:sound, token, nil, nil, nil}

      degree_str ->
        # Try to parse as degree with optional accidental
        case parse_jazz_degree(degree_str) do
          {:ok, degree} ->
            {:degree, degree}

          :error ->
            # Invalid degree, treat as literal
            {:sound, token, nil, nil, nil}
        end
    end
  end

  # Parse chord symbol or roman numeral: "@Dm7", "@ii", "@V7", "@I" -> {:chord, symbol} or {:roman, numeral}
  defp parse_chord_or_roman(token) do
    case String.slice(token, 1..-1//1) do
      "" ->
        # Just "@" with no symbol, treat as literal
        {:sound, token, nil, nil, nil}

      symbol ->
        # Determine if it's a chord symbol or roman numeral
        first_char = String.first(symbol)

        cond do
          # Roman numerals start with lowercase or uppercase roman letters or 'b'/'#'
          first_char in ["i", "I", "v", "V", "b", "#"] ->
            {:roman, symbol}

          # Chord symbols start with uppercase note letters A-G
          first_char in ["A", "B", "C", "D", "E", "F", "G"] ->
            {:chord, symbol}

          true ->
            # Unknown format, treat as literal
            {:sound, token, nil, nil, nil}
        end
    end
  end

  # Parse jazz degree string: "1", "3", "b7", "#5", "9", "11", "13"
  defp parse_jazz_degree(str) do
    case Integer.parse(str) do
      {degree, ""} when degree >= 1 and degree <= 13 ->
        {:ok, degree}

      _ ->
        # Try with accidental prefix (b or #)
        case str do
          "b" <> rest ->
            case Integer.parse(rest) do
              {degree, ""} when degree >= 1 and degree <= 13 ->
                {:ok, "b#{degree}"}

              _ ->
                :error
            end

          "#" <> rest ->
            case Integer.parse(rest) do
              {degree, ""} when degree >= 1 and degree <= 13 ->
                {:ok, "##{degree}"}

              _ ->
                :error
            end

          _ ->
            :error
        end
    end
  end

  # Parse sample selection: "bd:0" -> {:sound, "bd", 0, nil, nil}
  defp parse_sample_selection(token) do
    case String.split(token, ":") do
      [sound, sample_str] ->
        case Integer.parse(sample_str) do
          {sample, ""} when sample >= 0 ->
            {:sound, sound, sample, nil, nil}

          _ ->
            # Invalid sample number, treat as literal
            {:sound, token, nil, nil, nil}
        end

      _ ->
        {:sound, token, nil, nil, nil}
    end
  end

  # Parse euclidean rhythms: "bd(3,8)" or "bd(3,8,2)" or "bd:0(3,8)"
  # Returns {:euclidean, sound, sample, k, n, offset}
  defp parse_euclidean(token) do
    case Regex.run(~r/^(.+?)\((\d+),(\d+)(?:,(\d+))?\)$/, token) do
      [_, sound_part, k_str, n_str] ->
        k = String.to_integer(k_str)
        n = String.to_integer(n_str)
        {sound, sample} = parse_sound_part(sound_part)

        if k > 0 and n > 0 and k <= n do
          {:euclidean, sound, sample, k, n, 0}
        else
          {:sound, token, nil, nil, nil}
        end

      [_, sound_part, k_str, n_str, offset_str] ->
        k = String.to_integer(k_str)
        n = String.to_integer(n_str)
        offset = String.to_integer(offset_str)
        {sound, sample} = parse_sound_part(sound_part)

        if k > 0 and n > 0 and k <= n do
          {:euclidean, sound, sample, k, n, offset}
        else
          {:sound, token, nil, nil, nil}
        end

      _ ->
        {:sound, token, nil, nil, nil}
    end
  end

  # Parse division: "bd/2" or "bd:0/3" -> {:division, sound, sample, divisor}
  # Division slows down a pattern over multiple cycles
  defp parse_division(token) do
    case String.split(token, "/", parts: 2) do
      [sound_part, divisor_str] ->
        case parse_number(divisor_str) do
          {divisor, ""} when divisor > 0 ->
            {sound, sample} = parse_sound_part(sound_part)
            {:division, sound, sample, divisor}

          _ ->
            # Invalid divisor, treat as literal
            {:sound, token, nil, nil, nil}
        end

      _ ->
        {:sound, token, nil, nil, nil}
    end
  end

  # Parse ratio/speed: "bd%2" or "bd:0%3" -> {:ratio, sound, sample, cycles}
  # Ratio specifies how many cycles the pattern spans (speed = 1/cycles)
  defp parse_ratio(token) do
    case String.split(token, "%", parts: 2) do
      [sound_part, cycles_str] ->
        case parse_number(cycles_str) do
          {cycles, ""} when cycles > 0 ->
            {sound, sample} = parse_sound_part(sound_part)
            {:ratio, sound, sample, cycles}

          _ ->
            # Invalid ratio, treat as literal
            {:sound, token, nil, nil, nil}
        end

      _ ->
        {:sound, token, nil, nil, nil}
    end
  end

  # Parse pipe syntax - either random choice or parameters
  # Random choice: "bd|sd|hh" -> {:random_choice, [options]}
  # Parameters: "bd|gain:0.8|speed:2" -> {:sound, "bd", nil, nil, nil} with params
  defp parse_random_choice(token) do
    parts =
      token
      |> String.split("|")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    # Check if this looks like parameters (parts after first contain "param:value")
    case parts do
      [] ->
        {:sound, token, nil, nil, nil}

      [single] ->
        parse_token_for_choice(single)

      [sound_part | rest] ->
        if looks_like_parameters?(rest) do
          parse_sound_with_params(sound_part, rest)
        else
          # It's random choice
          options =
            parts
            |> Enum.map(&parse_token_for_choice/1)
            |> Enum.reject(&is_nil/1)

          case options do
            [] -> {:sound, token, nil, nil, nil}
            [single] -> single
            multiple -> {:random_choice, multiple}
          end
        end
    end
  end

  # Check if parts look like parameters (contain "name:value" where name is a known param)
  defp looks_like_parameters?(parts) do
    Enum.any?(parts, fn part ->
      case String.split(part, ":", parts: 2) do
        [name, _value] -> name in @sound_params
        _ -> false
      end
    end)
  end

  # Parse sound with parameters: "bd:0|gain:0.8|speed:2"
  defp parse_sound_with_params(sound_part, param_parts) do
    {sound, sample} = parse_sound_part(sound_part)
    params = parse_params(param_parts)
    {:sound_with_params, sound, sample, params}
  end

  # Parse parameter parts into a map
  defp parse_params(parts) do
    Enum.reduce(parts, %{}, fn part, acc ->
      case String.split(part, ":", parts: 2) do
        [name, value_str] when name in @sound_params ->
          case parse_number(value_str) do
            {value, ""} -> Map.put(acc, String.to_atom(name), value)
            _ -> acc
          end

        _ ->
          acc
      end
    end)
  end

  # Parse a token for use in random choice (without random choice recursion)
  defp parse_token_for_choice(token) do
    cond do
      token == "" ->
        nil

      token == "~" ->
        :rest

      String.contains?(token, "?") ->
        parse_probability(token)

      String.contains?(token, "@") ->
        parse_elongation(token)

      String.contains?(token, "!") ->
        parse_replication(token)

      String.contains?(token, "*") ->
        parse_repetition(token)

      String.contains?(token, ":") ->
        parse_sample_selection(token)

      true ->
        {:sound, token, nil, nil, nil}
    end
  end

  # Parse replication: "bd!3" or "bd:1!3" -> replicated sound tokens
  # Functionally similar to repetition but with different syntax
  defp parse_replication(token) do
    case String.split(token, "!", parts: 2) do
      [sound_part, count_str] ->
        case Integer.parse(count_str) do
          {count, ""} when count > 0 ->
            # Parse the sound part (which might have sample selection)
            sound_token =
              if String.contains?(sound_part, ":") do
                parse_sample_selection(sound_part)
              else
                {:sound, sound_part, nil, nil, nil}
              end

            {:repeat, List.duplicate(sound_token, count)}

          _ ->
            # Invalid replication, treat as literal
            {:sound, token, nil, nil, nil}
        end

      _ ->
        {:sound, token, nil, nil, nil}
    end
  end

  # Parse repetition: "bd*4" or "bd:1*4" -> repeated sound tokens
  defp parse_repetition(token) do
    case String.split(token, "*") do
      [sound_part, count_str] ->
        case Integer.parse(count_str) do
          {count, ""} when count > 0 ->
            # Parse the sound part (which might have sample selection)
            sound_token =
              if String.contains?(sound_part, ":") do
                parse_sample_selection(sound_part)
              else
                {:sound, sound_part, nil, nil, nil}
              end

            {:repeat, List.duplicate(sound_token, count)}

          _ ->
            # Invalid repetition, treat as literal
            {:sound, token, nil, nil, nil}
        end

      _ ->
        {:sound, token, nil, nil, nil}
    end
  end
end
