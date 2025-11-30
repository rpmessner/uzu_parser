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
    |> UzuParser.Timing.calculate_timings()
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

  # Check if a dot is a separator (not part of a decimal number)
  # A dot is part of a number if it follows a digit and precedes a digit
  defp is_separator_dot?(current, rest) do
    # Not a number dot if: previous char is not a digit OR next char is not a digit
    prev_is_digit = current != "" and String.match?(String.last(current), ~r/\d/)
    next_is_digit = rest != "" and String.match?(String.first(rest), ~r/\d/)
    not (prev_is_digit and next_is_digit)
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

  # Delegate to Structure module with tokenize/flatten callbacks
  defp parse_subdivision(inner) do
    UzuParser.Structure.parse_subdivision(inner, &tokenize/1, &UzuParser.Timing.flatten_token/1)
  end

  defp parse_alternation(inner) do
    UzuParser.Structure.parse_alternation(inner)
  end

  defp parse_polymetric(inner) do
    UzuParser.Structure.parse_polymetric(inner, &tokenize/1)
  end
end
