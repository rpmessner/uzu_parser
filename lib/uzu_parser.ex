defmodule UzuParser do
  @moduledoc """
  Parses Uzu mini-notation pattern strings into lists of timed events.

  The parser converts text-based pattern notation into structured event data
  that can be scheduled and played back.

  ## Supported Syntax

  ### Basic Sequences
  Space-separated sounds are evenly distributed across one cycle:

      "bd sd hh sd"  # 4 events at times 0.0, 0.25, 0.5, 0.75

  ### Rests
  Tilde (~) represents silence:

      "bd ~ sd ~"    # kick and snare on alternating beats

  ### Subdivisions (brackets)
  Brackets create faster subdivisions within a step:

      "bd [sd sd] hh"  # snare plays twice as fast

  ### Repetition
  Asterisk multiplies an element:

      "bd*4"         # equivalent to "bd bd bd bd"

  ### Sample Selection
  Colon selects different samples/variations:

      "bd:0"         # kick drum, sample 0
      "bd:1 bd:2"    # different kick drum samples
      "bd:0*4"       # repeat sample 0 four times

  ## Future Features
  - Parameters: "bd*0.8" (volume), "bd|speed:2"
  - Polyphony: "bd,sd" (sounds together)
  - Euclidean rhythms: "bd(3,8)"
  - Pattern transformations: fast(), slow(), rev()
  """

  alias UzuParser.Event

  @doc """
  Parses a pattern string into a list of events.

  Events are returned with time values between 0.0 and 1.0, representing
  their position within a single cycle.

  ## Examples

      iex> UzuParser.parse("bd sd hh sd")
      [
        %Event{sound: "bd", sample: nil, time: 0.0, duration: 0.25},
        %Event{sound: "sd", sample: nil, time: 0.25, duration: 0.25},
        %Event{sound: "hh", sample: nil, time: 0.5, duration: 0.25},
        %Event{sound: "sd", sample: nil, time: 0.75, duration: 0.25}
      ]

      iex> UzuParser.parse("bd ~ sd ~")
      [
        %Event{sound: "bd", sample: nil, time: 0.0, duration: 0.25},
        %Event{sound: "sd", sample: nil, time: 0.5, duration: 0.25}
      ]

      iex> UzuParser.parse("bd:0 sd:1")
      [
        %Event{sound: "bd", sample: 0, time: 0.0, duration: 0.5},
        %Event{sound: "sd", sample: 1, time: 0.5, duration: 0.5}
      ]
  """
  def parse(pattern_string) when is_binary(pattern_string) do
    pattern_string
    |> String.trim()
    |> tokenize()
    |> calculate_timings()
  end

  # Split pattern into tokens, handling brackets specially
  defp tokenize(pattern) do
    tokenize_recursive(pattern, [], "")
  end

  # Recursive tokenizer that handles brackets
  defp tokenize_recursive("", acc, current) do
    if current == "" do
      Enum.reverse(acc)
    else
      Enum.reverse([parse_token(String.trim(current)) | acc])
    end
  end

  defp tokenize_recursive("[" <> rest, acc, current) do
    # Start of subdivision - save current token if any, then collect until ]
    acc =
      if current != "" and String.trim(current) != "",
        do: [parse_token(String.trim(current)) | acc],
        else: acc

    {subdivision, remaining} = collect_until_bracket_close(rest, "")
    tokenize_recursive(remaining, [parse_subdivision(subdivision) | acc], "")
  end

  defp tokenize_recursive(<<char::utf8, rest::binary>>, acc, current) do
    if String.match?(<<char::utf8>>, ~r/\s/) do
      # Whitespace - end current token
      if current == "" do
        tokenize_recursive(rest, acc, "")
      else
        tokenize_recursive(rest, [parse_token(String.trim(current)) | acc], "")
      end
    else
      # Regular character - add to current token
      tokenize_recursive(rest, acc, current <> <<char::utf8>>)
    end
  end

  # Collect everything until the closing bracket
  defp collect_until_bracket_close("]" <> rest, acc), do: {acc, rest}

  defp collect_until_bracket_close(<<char::utf8, rest::binary>>, acc) do
    collect_until_bracket_close(rest, acc <> <<char::utf8>>)
  end

  # Handle unclosed bracket
  defp collect_until_bracket_close("", acc), do: {acc, ""}

  # Parse individual token
  defp parse_token(""), do: nil
  defp parse_token("~"), do: :rest

  defp parse_token(token) do
    cond do
      # Handle repetition: "bd*4" or "bd:1*4"
      String.contains?(token, "*") ->
        parse_repetition(token)

      # Handle sample selection: "bd:0"
      String.contains?(token, ":") ->
        parse_sample_selection(token)

      # Simple sound
      true ->
        {:sound, token, nil}
    end
  end

  # Parse sample selection: "bd:0" -> {:sound, "bd", 0}
  defp parse_sample_selection(token) do
    case String.split(token, ":") do
      [sound, sample_str] ->
        case Integer.parse(sample_str) do
          {sample, ""} when sample >= 0 ->
            {:sound, sound, sample}

          _ ->
            # Invalid sample number, treat as literal
            {:sound, token, nil}
        end

      _ ->
        {:sound, token, nil}
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
                {:sound, sound_part, nil}
              end

            {:repeat, List.duplicate(sound_token, count)}

          _ ->
            # Invalid repetition, treat as literal
            {:sound, token, nil}
        end

      _ ->
        {:sound, token, nil}
    end
  end

  # Parse subdivision: "bd sd" -> {:subdivision, [{:sound, "bd"}, {:sound, "sd"}]}
  defp parse_subdivision(inner) do
    subtokens =
      inner
      |> tokenize()
      |> Enum.reject(&is_nil/1)

    {:subdivision, subtokens}
  end

  # Calculate actual timing for events
  defp calculate_timings(parsed_tokens) do
    # Flatten any nested structures first
    flattened = flatten_structure(parsed_tokens)
    total_steps = length(flattened)

    if total_steps == 0 do
      []
    else
      step_duration = 1.0 / total_steps

      flattened
      |> Enum.with_index()
      |> Enum.flat_map(fn {token, index} ->
        time = index * step_duration

        case token do
          :rest ->
            []

          {:sound, sound, sample} ->
            [Event.new(sound, time, duration: step_duration, sample: sample)]

          _ ->
            []
        end
      end)
    end
  end

  # Flatten nested structure (subdivisions, repetitions) into flat list
  defp flatten_structure(tokens) do
    Enum.flat_map(tokens, &flatten_token/1)
  end

  defp flatten_token(:rest), do: [:rest]
  defp flatten_token({:sound, _, _} = sound), do: [sound]
  defp flatten_token({:repeat, items}), do: Enum.flat_map(items, &flatten_token/1)
  defp flatten_token({:subdivision, items}), do: Enum.flat_map(items, &flatten_token/1)
end
