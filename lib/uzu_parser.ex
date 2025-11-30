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

  ### Polyphony (chords)
  Comma within brackets plays multiple sounds simultaneously:

      "[bd,sd]"           # kick and snare together
      "[bd,sd,hh]"        # three sounds at once
      "bd [sd,hh] cp"     # chord on second beat
      "[bd:0,sd:1]"       # chord with sample selection

  ### Random Removal (probability)
  Question mark adds probability - events may or may not play:

      "bd?"               # 50% chance to play
      "bd?0.25"           # 25% chance to play
      "bd sd? hh"         # only sd is probabilistic
      "bd:0?0.75"         # sample selection + probability

  Note: The parser stores the probability in the event's params.
  The playback system (e.g., Waveform) decides whether to play the event.

  ### Elongation (temporal weight)
  At sign specifies relative duration/weight of events:

      "bd@2 sd"           # kick twice as long as snare (2/3 vs 1/3)
      "[bd sd@3 hh]"      # snare 3x longer than bd and hh
      "bd@1.5 sd"         # fractional weights supported

  Events are assigned time and duration proportionally based on their weights.
  Default weight is 1.0 if not specified.

  ### Replication
  Exclamation mark repeats events (similar to `*` but clearer intent):

      "bd!3"              # three bd events
      "bd!2 sd"           # two kicks, one snare
      "[bd!2 sd]"         # replication in subdivision

  Note: In this parser, `!` and `*` produce identical results. Both create
  separate steps rather than subdividing time.

  ### Random Choice (pipe)
  Pipe randomly selects one option per evaluation:

      "bd|sd|hh"          # pick one each time
      "[bd|cp] sd"        # randomize first beat

  Note: The parser stores all options and the playback system makes
  the random selection. Use `:rand.uniform()` or similar for selection.

  ### Alternation (angle brackets)
  Angle brackets cycle through options sequentially:

      "<bd sd hh>"        # bd on cycle 1, sd on 2, hh on 3, then repeats
      "<bd sd> hh"        # alternate kick pattern

  Note: The parser stores the options with an `:alternate` type.
  The playback system uses the cycle number to select which option to play.

  ### Euclidean Rhythms
  Parentheses generate rhythms using Euclidean distribution:

      "bd(3,8)"          # 3 kicks distributed over 8 steps
      "bd(3,8,2)"        # same with offset of 2
      "bd(5,12)"         # complex polyrhythm

  Note: Uses Bjorklund's algorithm to distribute hits evenly.

  ### Division (slow down)
  Slash slows a pattern over multiple cycles:

      "bd/2"             # play every other cycle
      "bd/4"             # play every 4th cycle
      "[bd sd]/2"        # whole pattern over 2 cycles

  Note: The parser stores the division factor in params. The playback
  system uses the cycle number to decide if the event should play.

  ### Polymetric Sequences
  Curly braces create patterns with different step counts (polyrhythms):

      "{bd sd hh, cp}"     # 3 steps vs 1 step
      "{bd sd, hh cp oh}"  # 2 steps vs 3 steps

  Note: Each comma-separated group runs independently over the cycle.
  This creates polyrhythmic patterns where groups of different lengths
  overlay each other.

  ### Sound Parameters
  Pipe syntax adds parameters to sounds for manipulation:

      "bd|gain:0.8"              # volume control
      "bd|speed:2|pan:0.5"       # multiple params
      "bd:0|gain:1.2"            # sample + params
      "bd|gain:0.8|delay:0.3"    # volume + delay

  Supported parameters: gain, speed, pan, cutoff, resonance, delay, room

  Note: Parameters are stored in the event's params map. The playback
  system (e.g., Waveform) uses these values for sound manipulation.

  ### Pattern Elongation
  Underscore extends the previous event's duration:

      "bd _ sd _"        # bd holds for 2 steps, sd holds for 2 steps
      "bd _ _ sd"        # bd holds for 3 steps, sd for 1 step
      "[bd _ sd _]"      # works in subdivisions too

  Note: Each `_` adds one step of duration to the previous sound event.

  ### Shorthand Separator
  Period provides alternative grouping (equivalent to space in subdivisions):

      "bd . sd . hh"     # same as "[bd] [sd] [hh]" or "bd sd hh"

  Note: Primarily useful for visual separation in complex patterns.

  ### Ratio/Speed Modifier
  Percent specifies how many cycles the pattern spans (opposite of division):

      "bd%2"             # bd spans 2 cycles (stored as speed: 0.5)
      "[bd sd]%3"        # pattern spans 3 cycles

  Note: The parser stores the speed factor in params. The playback system
  uses this to adjust playback rate. `%2` = speed 0.5, `%0.5` = speed 2.

  ### Polymetric Subdivision Control
  Curly braces with percent controls step subdivision:

      "{bd sd hh}%8"     # fit 3-step pattern into 8 subdivisions
      "{bd sd, hh}%16"   # polymetric groups fitted into 16 subdivisions

  Note: This stretches/compresses the polymetric pattern to fit the
  specified number of steps while maintaining internal ratios.

  ## Future Features
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
    trimmed = String.trim(pattern_string)
    # Calculate leading whitespace offset
    leading_ws = byte_size(pattern_string) - byte_size(String.trim_leading(pattern_string))

    trimmed
    |> tokenize_with_positions(leading_ws)
    |> calculate_timings()
  end

  # Split pattern into tokens, handling brackets specially
  # Returns tokens with position info: {token, start_pos, end_pos}
  defp tokenize_with_positions(pattern, start_offset) do
    tokenize_recursive(pattern, [], "", start_offset, start_offset)
  end

  defp tokenize(pattern) do
    tokenize_with_positions(pattern, 0)
  end

  # Recursive tokenizer that handles brackets
  # Now tracks positions: offset is current byte position, token_start is where current token began
  defp tokenize_recursive("", acc, current, offset, token_start) do
    if current == "" do
      Enum.reverse(acc)
    else
      token = UzuParser.TokenParser.parse(String.trim(current))
      Enum.reverse([{token, token_start, offset} | acc])
    end
  end

  defp tokenize_recursive("[" <> rest, acc, current, offset, token_start) do
    # Start of subdivision - save current token if any, then collect until ]
    acc =
      if current != "" and String.trim(current) != "" do
        token = UzuParser.TokenParser.parse(String.trim(current))
        [{token, token_start, offset} | acc]
      else
        acc
      end

    bracket_start = offset
    {subdivision, remaining, bytes_consumed} = UzuParser.Collectors.collect_until_bracket_close_with_length(rest)
    bracket_end = offset + 1 + bytes_consumed  # +1 for the [ itself

    # Check for division modifier after subdivision: [bd sd]/2
    {token, remaining, extra_bytes} = parse_subdivision_with_modifiers_and_length(subdivision, remaining)
    tokenize_recursive(remaining, [{token, bracket_start, bracket_end + extra_bytes} | acc], "", bracket_end + extra_bytes, bracket_end + extra_bytes)
  end

  defp tokenize_recursive("<" <> rest, acc, current, offset, token_start) do
    # Start of alternation - save current token if any, then collect until >
    acc =
      if current != "" and String.trim(current) != "" do
        token = UzuParser.TokenParser.parse(String.trim(current))
        [{token, token_start, offset} | acc]
      else
        acc
      end

    angle_start = offset
    {alternation, remaining, bytes_consumed} = UzuParser.Collectors.collect_until_angle_close_with_length(rest)
    angle_end = offset + 1 + bytes_consumed

    tokenize_recursive(remaining, [{parse_alternation(alternation), angle_start, angle_end} | acc], "", angle_end, angle_end)
  end

  defp tokenize_recursive("{" <> rest, acc, current, offset, token_start) do
    # Start of polymetric sequence - save current token if any, then collect until }
    acc =
      if current != "" and String.trim(current) != "" do
        token = UzuParser.TokenParser.parse(String.trim(current))
        [{token, token_start, offset} | acc]
      else
        acc
      end

    curly_start = offset
    {polymetric, remaining, bytes_consumed} = UzuParser.Collectors.collect_until_curly_close_with_length(rest)
    curly_end = offset + 1 + bytes_consumed

    # Check for subdivision modifier after polymetric: {bd sd}%8
    {token, remaining, extra_bytes} = parse_polymetric_with_modifiers_and_length(polymetric, remaining)
    tokenize_recursive(remaining, [{token, curly_start, curly_end + extra_bytes} | acc], "", curly_end + extra_bytes, curly_end + extra_bytes)
  end

  defp tokenize_recursive(<<char::utf8, rest::binary>>, acc, current, offset, token_start) do
    char_str = <<char::utf8>>
    char_bytes = byte_size(char_str)
    new_offset = offset + char_bytes

    cond do
      String.match?(char_str, ~r/\s/) ->
        # Whitespace - end current token
        if current == "" do
          tokenize_recursive(rest, acc, "", new_offset, new_offset)
        else
          token = UzuParser.TokenParser.parse(String.trim(current))
          tokenize_recursive(rest, [{token, token_start, offset} | acc], "", new_offset, new_offset)
        end

      char_str == "." and is_separator_dot?(current, rest) ->
        # Period as separator (not part of a number)
        if current == "" do
          tokenize_recursive(rest, acc, "", new_offset, new_offset)
        else
          token = UzuParser.TokenParser.parse(String.trim(current))
          tokenize_recursive(rest, [{token, token_start, offset} | acc], "", new_offset, new_offset)
        end

      true ->
        # Regular character - add to current token
        tokenize_recursive(rest, acc, current <> char_str, new_offset, token_start)
    end
  end

  # Legacy 3-arg version for internal calls that don't need positions
  defp tokenize_recursive("", acc, current) do
    tokenize_recursive("", acc, current, 0, 0)
  end

  defp tokenize_recursive("[" <> rest, acc, current) do
    tokenize_recursive("[" <> rest, acc, current, 0, 0)
  end

  defp tokenize_recursive("<" <> rest, acc, current) do
    tokenize_recursive("<" <> rest, acc, current, 0, 0)
  end

  defp tokenize_recursive("{" <> rest, acc, current) do
    tokenize_recursive("{" <> rest, acc, current, 0, 0)
  end

  defp tokenize_recursive(<<char::utf8, rest::binary>>, acc, current) do
    tokenize_recursive(<<char::utf8, rest::binary>>, acc, current, 0, 0)
  end

  # Check if a dot is a separator (not part of a decimal number)
  # A dot is part of a number if it follows a digit and precedes a digit
  defp is_separator_dot?(current, rest) do
    # Not a number dot if: previous char is not a digit OR next char is not a digit
    prev_is_digit = current != "" and String.match?(String.last(current), ~r/\d/)
    next_is_digit = rest != "" and String.match?(String.first(rest), ~r/\d/)
    not (prev_is_digit and next_is_digit)
  end

  # Parse subdivision with possible modifiers like /2 or *2
  defp parse_subdivision_with_modifiers(inner, "/" <> rest) do
    # Collect the divisor (digits until whitespace or end)
    {divisor_str, remaining} = UzuParser.Collectors.collect_number(rest, [])

    case UzuParser.TokenParser.parse_number(divisor_str) do
      {divisor, ""} when divisor > 0 ->
        {{:subdivision_division, parse_subdivision(inner), divisor}, remaining}

      _ ->
        # Invalid divisor, just return subdivision
        {parse_subdivision(inner), "/" <> rest}
    end
  end

  defp parse_subdivision_with_modifiers(inner, "*" <> rest) do
    # Collect the repetition count (digits until whitespace or end)
    {count_str, remaining} = UzuParser.Collectors.collect_number(rest, [])

    case UzuParser.TokenParser.parse_number(count_str) do
      {count, ""} when count > 0 ->
        # Create repeated subdivisions
        subdivision = parse_subdivision(inner)
        repeated = {:subdivision_repeat, subdivision, round(count)}
        {repeated, remaining}

      _ ->
        # Invalid count, just return subdivision
        {parse_subdivision(inner), "*" <> rest}
    end
  end

  defp parse_subdivision_with_modifiers(inner, remaining) do
    {parse_subdivision(inner), remaining}
  end

  # Parse polymetric with possible modifiers like %8
  defp parse_polymetric_with_modifiers(inner, "%" <> rest) do
    # Collect the step count (digits until whitespace or end)
    {steps_str, remaining} = UzuParser.Collectors.collect_number(rest, [])

    case UzuParser.TokenParser.parse_number(steps_str) do
      {steps, ""} when steps > 0 ->
        {{:polymetric_steps, parse_polymetric(inner), steps}, remaining}

      _ ->
        # Invalid steps, just return polymetric
        {parse_polymetric(inner), "%" <> rest}
    end
  end

  defp parse_polymetric_with_modifiers(inner, remaining) do
    {parse_polymetric(inner), remaining}
  end

  # ============================================================
  # Position-tracking versions of modifier parsing
  # These return {token, remaining, extra_bytes_consumed}
  # ============================================================

  defp parse_subdivision_with_modifiers_and_length(inner, "/" <> rest) do
    {divisor_str, remaining} = UzuParser.Collectors.collect_number(rest, [])

    case UzuParser.TokenParser.parse_number(divisor_str) do
      {divisor, ""} when divisor > 0 ->
        extra = 1 + byte_size(divisor_str)  # "/" + number
        {{:subdivision_division, parse_subdivision(inner), divisor}, remaining, extra}

      _ ->
        {parse_subdivision(inner), "/" <> rest, 0}
    end
  end

  defp parse_subdivision_with_modifiers_and_length(inner, "*" <> rest) do
    {count_str, remaining} = UzuParser.Collectors.collect_number(rest, [])

    case UzuParser.TokenParser.parse_number(count_str) do
      {count, ""} when count > 0 ->
        subdivision = parse_subdivision(inner)
        extra = 1 + byte_size(count_str)  # "*" + number
        {{:subdivision_repeat, subdivision, round(count)}, remaining, extra}

      _ ->
        {parse_subdivision(inner), "*" <> rest, 0}
    end
  end

  defp parse_subdivision_with_modifiers_and_length(inner, remaining) do
    {parse_subdivision(inner), remaining, 0}
  end

  defp parse_polymetric_with_modifiers_and_length(inner, "%" <> rest) do
    {steps_str, remaining} = UzuParser.Collectors.collect_number(rest, [])

    case UzuParser.TokenParser.parse_number(steps_str) do
      {steps, ""} when steps > 0 ->
        extra = 1 + byte_size(steps_str)  # "%" + number
        {{:polymetric_steps, parse_polymetric(inner), steps}, remaining, extra}

      _ ->
        {parse_polymetric(inner), "%" <> rest, 0}
    end
  end

  defp parse_polymetric_with_modifiers_and_length(inner, remaining) do
    {parse_polymetric(inner), remaining, 0}
  end

  # Parse subdivision: "bd sd" -> {:subdivision, [{:sound, "bd"}, {:sound, "sd"}]}
  # Or polyphony: "bd,sd" -> {:subdivision, [{:chord, [{:sound, "bd"}, {:sound, "sd"}]}]}
  defp parse_subdivision(inner) do
    # Check if this subdivision contains polyphony (comma-separated at top level)
    # Only check for top-level commas (not inside nested brackets)
    if UzuParser.Collectors.has_top_level_comma?(inner) do
      # Parse as a chord - flatten any repetitions so we get individual sounds
      # Use split_top_level_comma to respect nesting
      sounds =
        inner
        |> UzuParser.Collectors.split_top_level_comma()
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(&UzuParser.TokenParser.parse/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.flat_map(&flatten_token/1)

      {:subdivision, [{:chord, sounds}]}
    else
      # Parse as regular subdivision
      subtokens =
        inner
        |> tokenize()
        |> Enum.reject(&is_nil/1)

      {:subdivision, subtokens}
    end
  end

  # Parse alternation: "bd sd hh" -> {:alternate, [options]}
  # Cycles through options sequentially based on cycle number
  defp parse_alternation(inner) do
    options =
      inner
      |> String.split()
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&UzuParser.TokenParser.parse/1)
      |> Enum.reject(&is_nil/1)

    case options do
      [] -> nil
      [single] -> single
      multiple -> {:alternate, multiple}
    end
  end

  # Parse polymetric sequence: "bd sd hh, cp" -> {:polymetric, [groups]}
  # Each group is independently timed over the cycle
  defp parse_polymetric(inner) do
    groups =
      inner
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn group ->
        group
        |> tokenize()
        |> Enum.reject(&is_nil/1)
      end)
      |> Enum.reject(&(&1 == []))

    case groups do
      [] -> nil
      [single] -> {:subdivision, single}
      multiple -> {:polymetric, multiple}
    end
  end

  # Calculate actual timing for events
  # Tokens may be {token, start_pos, end_pos} tuples or bare tokens
  defp calculate_timings(parsed_tokens) do
    # Flatten any nested structures first, preserving positions
    flattened = flatten_structure_with_positions(parsed_tokens)

    if length(flattened) == 0 do
      []
    else
      # Calculate total weight and assign time/duration based on weights
      calculate_weighted_timings(flattened)
    end
  end

  # Flatten structure while preserving position info
  # Input: list of {token, start, end} or bare tokens
  # Output: list of {token, start, end} where positions may be nil for internal tokens
  defp flatten_structure_with_positions(tokens) do
    tokens
    |> Enum.flat_map(&flatten_token_with_position/1)
    |> process_elongations_with_positions()
  end

  # Flatten a token that may have position info
  defp flatten_token_with_position({token, start_pos, end_pos}) do
    # Flatten the inner token and attach positions to the first result
    flattened = flatten_token(token)
    attach_positions_to_first(flattened, start_pos, end_pos)
  end

  defp flatten_token_with_position(token) do
    # Bare token without positions
    flatten_token(token)
    |> Enum.map(&wrap_token_no_position/1)
  end

  # Wrap a token with nil positions
  defp wrap_token_no_position(token), do: {token, nil, nil}

  # Attach positions to the first token in a list, rest get nil positions
  defp attach_positions_to_first([], _start, _end), do: []
  defp attach_positions_to_first([first | rest], start_pos, end_pos) do
    [{first, start_pos, end_pos} | Enum.map(rest, &wrap_token_no_position/1)]
  end

  # Process elongations while preserving positions
  defp process_elongations_with_positions(tokens) do
    {result, _} =
      Enum.reduce(tokens, {[], nil}, fn {token, start_pos, end_pos}, {acc, prev} ->
        case token do
          :elongate ->
            case prev do
              nil ->
                {acc ++ [{:rest, nil, nil}], nil}

              {prev_token, prev_start, _prev_end} ->
                # Increase weight and extend end position
                updated_token = increase_token_weight(prev_token)
                updated = {updated_token, prev_start, end_pos}
                {List.replace_at(acc, -1, updated), updated}
            end

          _ ->
            {acc ++ [{token, start_pos, end_pos}], {token, start_pos, end_pos}}
        end
      end)

    result
  end

  # Calculate timings with weight support
  # Tokens are now {token, start_pos, end_pos} tuples
  defp calculate_weighted_timings(tokens) do
    # Calculate total weight (unwrap positions)
    total_weight =
      tokens
      |> Enum.map(fn {token, _, _} -> get_token_weight(token) end)
      |> Enum.sum()

    # Assign time and duration based on weights
    {events, _current_time} =
      Enum.reduce(tokens, {[], 0.0}, fn {token, src_start, src_end}, {events_acc, current_time} ->
        weight = get_token_weight(token)
        duration = weight / total_weight

        new_events =
          case token do
            :rest ->
              []

            {:degree, degree} ->
              # Store degree as jazz token in params
              sound = "^#{degree}"
              params = %{jazz_type: :degree, jazz_value: degree}
              [Event.new(sound, current_time, duration: duration, params: params, source_start: src_start, source_end: src_end)]

            {:chord, chord_symbol} when is_binary(chord_symbol) ->
              # Jazz chord symbol (not polyphonic chord)
              sound = "@#{chord_symbol}"
              params = %{jazz_type: :chord, jazz_value: chord_symbol}
              [Event.new(sound, current_time, duration: duration, params: params, source_start: src_start, source_end: src_end)]

            {:roman, roman} ->
              # Roman numeral chord
              sound = "@#{roman}"
              params = %{jazz_type: :roman, jazz_value: roman}
              [Event.new(sound, current_time, duration: duration, params: params, source_start: src_start, source_end: src_end)]

            {:sound, sound, sample, probability, _weight} ->
              params = if probability, do: %{probability: probability}, else: %{}
              [Event.new(sound, current_time, duration: duration, sample: sample, params: params, source_start: src_start, source_end: src_end)]

            {:sound_with_params, sound, sample, sound_params} ->
              # Remove internal _weight key before creating event
              clean_params = Map.delete(sound_params, :_weight)

              [
                Event.new(sound, current_time,
                  duration: duration,
                  sample: sample,
                  params: clean_params,
                  source_start: src_start,
                  source_end: src_end
                )
              ]

            {:chord, sounds} ->
              # Create multiple events at the same time for polyphony
              # All sounds in chord share same source position
              Enum.map(sounds, fn
                {:sound, sound, sample, probability, _weight} ->
                  params = if probability, do: %{probability: probability}, else: %{}

                  Event.new(sound, current_time,
                    duration: duration,
                    sample: sample,
                    params: params,
                    source_start: src_start,
                    source_end: src_end
                  )

                _ ->
                  nil
              end)
              |> Enum.reject(&is_nil/1)

            {:random_choice, options} ->
              # Store all options in params; playback system selects one randomly
              option_data = Enum.map(options, &token_to_option_data/1)
              params = %{random_choice: option_data}
              # Use first option's sound as default for the event
              {default_sound, default_sample} = get_default_from_options(options)

              [
                Event.new(default_sound, current_time,
                  duration: duration,
                  source_start: src_start,
                  source_end: src_end,
                  sample: default_sample,
                  params: params
                )
              ]

            {:alternate, options} ->
              # Store all options in params; playback system cycles through them
              option_data = Enum.map(options, &token_to_option_data/1)
              params = %{alternate: option_data}
              # Use first option's sound as default for the event
              {default_sound, default_sample} = get_default_from_options(options)

              [
                Event.new(default_sound, current_time,
                  duration: duration,
                  sample: default_sample,
                  params: params,
                  source_start: src_start,
                  source_end: src_end
                )
              ]

            {:division, sound, sample, divisor} ->
              # Store divisor in params; playback system decides if event plays
              params = %{division: divisor}

              [
                Event.new(sound, current_time,
                  duration: duration,
                  sample: sample,
                  params: params,
                  source_start: src_start,
                  source_end: src_end
                )
              ]

            {:ratio, sound, sample, cycles} ->
              # Store speed in params (speed = 1/cycles)
              # e.g., %2 means spans 2 cycles, so speed is 0.5
              params = %{speed: 1.0 / cycles}

              [
                Event.new(sound, current_time,
                  duration: duration,
                  sample: sample,
                  params: params,
                  source_start: src_start,
                  source_end: src_end
                )
              ]

            {:chord_division, sounds, divisor} ->
              # Create chord events with division applied to each
              Enum.map(sounds, fn
                {:sound, sound, sample, probability, _weight} ->
                  base_params = if probability, do: %{probability: probability}, else: %{}
                  params = Map.put(base_params, :division, divisor)

                  Event.new(sound, current_time,
                    duration: duration,
                    sample: sample,
                    params: params,
                    source_start: src_start,
                    source_end: src_end
                  )

                _ ->
                  nil
              end)
              |> Enum.reject(&is_nil/1)

            {:polymetric, groups} ->
              # Each group is timed independently over the full duration
              # Process each group as its own mini-cycle
              # Note: polymetric events don't get individual source positions
              groups
              |> Enum.flat_map(fn group_tokens ->
                flattened = flatten_structure(group_tokens)
                calculate_polymetric_group_events(flattened, current_time, duration, src_start, src_end)
              end)

            {:polymetric_steps, inner_poly, steps} ->
              # Polymetric with step subdivision control
              # The pattern is stretched/compressed to fit `steps` subdivisions
              case inner_poly do
                {:polymetric, groups} ->
                  # Each group spans the full duration but is subdivided into `steps`
                  groups
                  |> Enum.flat_map(fn group_tokens ->
                    flattened = flatten_structure(group_tokens)
                    # Calculate with step-based timing
                    calculate_polymetric_stepped_events(
                      flattened,
                      current_time,
                      duration,
                      steps,
                      src_start,
                      src_end
                    )
                  end)

                {:subdivision, items} ->
                  # Single group, treat like subdivision with steps
                  flattened = flatten_structure(items)
                  calculate_polymetric_stepped_events(flattened, current_time, duration, steps, src_start, src_end)

                _ ->
                  []
              end

            _ ->
              []
          end

        {events_acc ++ new_events, current_time + duration}
      end)

    events
  end

  # Calculate events for polymetric with step control {pattern}%steps
  # Events are distributed across the specified number of steps
  defp calculate_polymetric_stepped_events(tokens, start_time, total_duration, steps, src_start, src_end) do
    if length(tokens) == 0 do
      []
    else
      # Each token gets (token_count / steps) of the duration
      # But we distribute based on the pattern's internal structure
      token_count = length(tokens)
      step_duration = total_duration / steps

      # Map each token to its step position
      # If pattern has fewer events than steps, events are spread out
      # If pattern has more events than steps, events are compressed
      {events, _} =
        Enum.with_index(tokens)
        |> Enum.reduce({[], start_time}, fn {token, idx}, {events_acc, _} ->
          # Calculate position based on pattern index relative to steps
          time_offset = idx / token_count * total_duration
          # Each event's duration is one step
          event_duration = step_duration

          new_event =
            case token do
              :rest ->
                nil

              {:sound, sound, sample, probability, _weight} ->
                params = if probability, do: %{probability: probability}, else: %{}

                Event.new(sound, start_time + time_offset,
                  duration: event_duration,
                  sample: sample,
                  params: params,
                  source_start: src_start,
                  source_end: src_end
                )

              {:chord, sounds} ->
                Enum.map(sounds, fn
                  {:sound, sound, sample, probability, _weight} ->
                    params = if probability, do: %{probability: probability}, else: %{}

                    Event.new(sound, start_time + time_offset,
                      duration: event_duration,
                      sample: sample,
                      params: params,
                      source_start: src_start,
                      source_end: src_end
                    )

                  _ ->
                    nil
                end)
                |> Enum.reject(&is_nil/1)

              _ ->
                nil
            end

          new_events =
            case new_event do
              nil -> []
              list when is_list(list) -> list
              event -> [event]
            end

          {events_acc ++ new_events, start_time + time_offset + event_duration}
        end)

      events
    end
  end

  # Calculate events for a polymetric group with its own timing
  defp calculate_polymetric_group_events(tokens, start_time, total_duration, src_start, src_end) do
    if length(tokens) == 0 do
      []
    else
      total_weight =
        tokens
        |> Enum.map(&get_token_weight/1)
        |> Enum.sum()

      {events, _} =
        Enum.reduce(tokens, {[], start_time}, fn token, {events_acc, current_time} ->
          weight = get_token_weight(token)
          duration = weight / total_weight * total_duration

          new_event =
            case token do
              :rest ->
                nil

              {:sound, sound, sample, probability, _weight} ->
                params = if probability, do: %{probability: probability}, else: %{}
                Event.new(sound, current_time, duration: duration, sample: sample, params: params, source_start: src_start, source_end: src_end)

              {:chord, sounds} ->
                # Return list for chord
                Enum.map(sounds, fn
                  {:sound, sound, sample, probability, _weight} ->
                    params = if probability, do: %{probability: probability}, else: %{}

                    Event.new(sound, current_time,
                      duration: duration,
                      sample: sample,
                      params: params,
                      source_start: src_start,
                      source_end: src_end
                    )

                  _ ->
                    nil
                end)
                |> Enum.reject(&is_nil/1)

              _ ->
                nil
            end

          new_events =
            case new_event do
              nil -> []
              list when is_list(list) -> list
              event -> [event]
            end

          {events_acc ++ new_events, current_time + duration}
        end)

      events
    end
  end

  # Get the weight of a token (default 1.0 if no weight specified)
  defp get_token_weight(:rest), do: 1.0
  defp get_token_weight({:sound, _, _, _, nil}), do: 1.0
  defp get_token_weight({:sound, _, _, _, weight}), do: weight
  defp get_token_weight({:sound_with_params, _, _, params}), do: Map.get(params, :_weight, 1.0)
  defp get_token_weight({:chord, _}), do: 1.0
  defp get_token_weight({:random_choice, _}), do: 1.0
  defp get_token_weight({:alternate, _}), do: 1.0
  defp get_token_weight({:division, _, _, _}), do: 1.0
  defp get_token_weight({:ratio, _, _, _}), do: 1.0
  defp get_token_weight({:chord_division, _, _}), do: 1.0
  defp get_token_weight({:polymetric, _}), do: 1.0
  defp get_token_weight({:polymetric_steps, _, _}), do: 1.0
  defp get_token_weight(_), do: 1.0

  # Convert a token to option data for random_choice/alternate params
  defp token_to_option_data(:rest), do: %{sound: nil, sample: nil, probability: nil}

  defp token_to_option_data({:sound, sound, sample, probability, _weight}) do
    %{sound: sound, sample: sample, probability: probability}
  end

  defp token_to_option_data({:repeat, items}) do
    # For repeat, use the first item's data
    case items do
      [first | _] -> token_to_option_data(first)
      _ -> %{sound: nil, sample: nil, probability: nil}
    end
  end

  defp token_to_option_data(_), do: %{sound: nil, sample: nil, probability: nil}

  # Get default sound and sample from first option
  defp get_default_from_options([]), do: {"?", nil}

  defp get_default_from_options([first | _]) do
    case first do
      :rest -> {"~", nil}
      {:sound, sound, sample, _, _} -> {sound, sample}
      {:repeat, [{:sound, sound, sample, _, _} | _]} -> {sound, sample}
      _ -> {"?", nil}
    end
  end

  # Flatten nested structure (subdivisions, repetitions) into flat list
  defp flatten_structure(tokens) do
    tokens
    |> Enum.flat_map(&flatten_token/1)
    |> process_elongations()
  end

  # Process elongation tokens (_) by increasing weight of previous sound
  defp process_elongations(tokens) do
    {result, _} =
      Enum.reduce(tokens, {[], nil}, fn token, {acc, prev} ->
        case token do
          :elongate ->
            # Add weight to previous sound token
            case prev do
              nil ->
                # No previous token, treat as rest
                {acc ++ [:rest], nil}

              _ ->
                # Increase weight of previous token
                updated = increase_token_weight(prev)
                # Replace last element in acc with updated version
                {List.replace_at(acc, -1, updated), updated}
            end

          _ ->
            {acc ++ [token], token}
        end
      end)

    result
  end

  # Increase the weight of a token by 1.0
  defp increase_token_weight({:sound, name, sample, prob, nil}) do
    {:sound, name, sample, prob, 2.0}
  end

  defp increase_token_weight({:sound, name, sample, prob, weight}) do
    {:sound, name, sample, prob, weight + 1.0}
  end

  defp increase_token_weight({:sound_with_params, name, sample, params}) do
    # For sound_with_params, we need to track weight differently
    # Store it in params temporarily
    current_weight = Map.get(params, :_weight, 1.0)
    {:sound_with_params, name, sample, Map.put(params, :_weight, current_weight + 1.0)}
  end

  defp increase_token_weight(token), do: token

  defp flatten_token(nil), do: []
  defp flatten_token(:rest), do: [:rest]
  defp flatten_token(:elongate), do: [:elongate]
  # Handle position-wrapped tokens from internal tokenization (3-tuples where first element is token)
  # Must check this early, but be specific about shape: {token, integer|nil, integer|nil}
  defp flatten_token({token, start_pos, end_pos})
       when (is_tuple(token) or is_atom(token)) and
            (is_integer(start_pos) or is_nil(start_pos)) and
            (is_integer(end_pos) or is_nil(end_pos)) do
    flatten_token(token)
  end
  defp flatten_token({:sound, _, _, _, _} = sound), do: [sound]
  defp flatten_token({:sound_with_params, _, _, _} = sound), do: [sound]
  defp flatten_token({:degree, _} = degree), do: [degree]
  defp flatten_token({:roman, _} = roman), do: [roman]
  # Jazz chord symbol (string) vs polyphonic chord (list)
  defp flatten_token({:chord, chord_symbol}) when is_binary(chord_symbol), do: [{:chord, chord_symbol}]
  defp flatten_token({:chord, sounds}) when is_list(sounds), do: [{:chord, sounds}]
  defp flatten_token({:repeat, items}), do: Enum.flat_map(items, &flatten_token/1)
  defp flatten_token({:subdivision, items}), do: Enum.flat_map(items, &flatten_token/1)
  defp flatten_token({:random_choice, _options} = choice), do: [choice]
  defp flatten_token({:alternate, _options} = alt), do: [alt]
  defp flatten_token({:division, _, _, _} = div), do: [div]
  defp flatten_token({:ratio, _, _, _} = ratio), do: [ratio]
  defp flatten_token({:polymetric, _groups} = poly), do: [poly]
  defp flatten_token({:polymetric_steps, _, _} = poly), do: [poly]

  defp flatten_token({:subdivision_division, {:subdivision, items}, divisor}) do
    # Flatten the subdivision and wrap each item with division info
    items
    |> Enum.flat_map(&flatten_token/1)
    |> Enum.map(&apply_division(&1, divisor))
  end

  defp flatten_token({:subdivision_repeat, {:subdivision, items}, count}) do
    # Flatten the subdivision and repeat the entire pattern count times
    flattened = Enum.flat_map(items, &flatten_token/1)
    List.duplicate(flattened, count) |> List.flatten()
  end

  defp flatten_token({:euclidean, sound, sample, k, n, offset}) do
    # Generate euclidean pattern and convert to sound/rest tokens
    pattern = UzuParser.Euclidean.rhythm(k, n, offset)

    Enum.map(pattern, fn
      1 -> {:sound, sound, sample, nil, nil}
      0 -> :rest
    end)
  end

  # Apply division to a token (convert sound to division)
  defp apply_division(:rest, _divisor), do: :rest

  defp apply_division({:sound, sound, sample, _prob, _weight}, divisor) do
    {:division, sound, sample, divisor}
  end

  defp apply_division({:division, sound, sample, existing_divisor}, new_divisor) do
    # Combine divisors (multiply)
    {:division, sound, sample, existing_divisor * new_divisor}
  end

  defp apply_division({:chord, sounds}, divisor) do
    # Apply division to each sound in the chord
    {:chord_division, sounds, divisor}
  end

  defp apply_division(token, _divisor), do: token

end
