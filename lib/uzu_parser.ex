defmodule UzuParser do
  @moduledoc """
  Parses Uzu mini-notation pattern strings into lists of timed events.

  The parser converts text-based pattern notation into structured event data
  that can be scheduled and played back.

  ## Supported Syntax (MVP)

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

  ## Future Features
  - Sample selection: "bd:0", "bd:1"
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
        %Event{sound: "bd", time: 0.0, duration: 0.25},
        %Event{sound: "sd", time: 0.25, duration: 0.25},
        %Event{sound: "hh", time: 0.5, duration: 0.25},
        %Event{sound: "sd", time: 0.75, duration: 0.25}
      ]

      iex> UzuParser.parse("bd ~ sd ~")
      [
        %Event{sound: "bd", time: 0.0, duration: 0.25},
        %Event{sound: "sd", time: 0.5, duration: 0.25}
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
      # Handle repetition: "bd*4"
      String.contains?(token, "*") ->
        parse_repetition(token)

      # Simple sound
      true ->
        {:sound, token}
    end
  end

  # Parse repetition: "bd*4" -> [{:sound, "bd"}, {:sound, "bd"}, {:sound, "bd"}, {:sound, "bd"}]
  defp parse_repetition(token) do
    case String.split(token, "*") do
      [sound, count_str] ->
        case Integer.parse(count_str) do
          {count, ""} when count > 0 ->
            {:repeat, List.duplicate({:sound, sound}, count)}

          _ ->
            # Invalid repetition, treat as literal
            {:sound, token}
        end

      _ ->
        {:sound, token}
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
          :rest -> []
          {:sound, sound} -> [Event.new(sound, time, duration: step_duration)]
          _ -> []
        end
      end)
    end
  end

  # Flatten nested structure (subdivisions, repetitions) into flat list
  defp flatten_structure(tokens) do
    Enum.flat_map(tokens, &flatten_token/1)
  end

  defp flatten_token(:rest), do: [:rest]
  defp flatten_token({:sound, _} = sound), do: [sound]
  defp flatten_token({:repeat, items}), do: Enum.flat_map(items, &flatten_token/1)
  defp flatten_token({:subdivision, items}), do: Enum.flat_map(items, &flatten_token/1)
end
