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

    {subdivision, remaining} = collect_until_bracket_close(rest, [])

    # Check for division modifier after subdivision: [bd sd]/2
    {token, remaining} = parse_subdivision_with_modifiers(subdivision, remaining)
    tokenize_recursive(remaining, [token | acc], "")
  end

  defp tokenize_recursive("<" <> rest, acc, current) do
    # Start of alternation - save current token if any, then collect until >
    acc =
      if current != "" and String.trim(current) != "",
        do: [parse_token(String.trim(current)) | acc],
        else: acc

    {alternation, remaining} = collect_until_angle_close(rest, [])
    tokenize_recursive(remaining, [parse_alternation(alternation) | acc], "")
  end

  defp tokenize_recursive("{" <> rest, acc, current) do
    # Start of polymetric sequence - save current token if any, then collect until }
    acc =
      if current != "" and String.trim(current) != "",
        do: [parse_token(String.trim(current)) | acc],
        else: acc

    {polymetric, remaining} = collect_until_curly_close(rest, [])

    # Check for subdivision modifier after polymetric: {bd sd}%8
    {token, remaining} = parse_polymetric_with_modifiers(polymetric, remaining)
    tokenize_recursive(remaining, [token | acc], "")
  end

  defp tokenize_recursive(<<char::utf8, rest::binary>>, acc, current) do
    char_str = <<char::utf8>>

    cond do
      String.match?(char_str, ~r/\s/) ->
        # Whitespace - end current token
        if current == "" do
          tokenize_recursive(rest, acc, "")
        else
          tokenize_recursive(rest, [parse_token(String.trim(current)) | acc], "")
        end

      char_str == "." and is_separator_dot?(current, rest) ->
        # Period as separator (not part of a number)
        if current == "" do
          tokenize_recursive(rest, acc, "")
        else
          tokenize_recursive(rest, [parse_token(String.trim(current)) | acc], "")
        end

      true ->
        # Regular character - add to current token
        tokenize_recursive(rest, acc, current <> char_str)
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

  # Parse subdivision with possible modifiers like /2 or *2
  defp parse_subdivision_with_modifiers(inner, "/" <> rest) do
    # Collect the divisor (digits until whitespace or end)
    {divisor_str, remaining} = collect_number(rest, [])

    case parse_number(divisor_str) do
      {divisor, ""} when divisor > 0 ->
        {{:subdivision_division, parse_subdivision(inner), divisor}, remaining}

      _ ->
        # Invalid divisor, just return subdivision
        {parse_subdivision(inner), "/" <> rest}
    end
  end

  defp parse_subdivision_with_modifiers(inner, "*" <> rest) do
    # Collect the repetition count (digits until whitespace or end)
    {count_str, remaining} = collect_number(rest, [])

    case parse_number(count_str) do
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
    {steps_str, remaining} = collect_number(rest, [])

    case parse_number(steps_str) do
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

  # Collect digits until whitespace or end
  defp collect_number("", acc), do: {IO.iodata_to_binary(Enum.reverse(acc)), ""}

  defp collect_number(<<char::utf8, rest::binary>> = str, acc) do
    if String.match?(<<char::utf8>>, ~r/[\d.]/) do
      collect_number(rest, [<<char::utf8>> | acc])
    else
      {IO.iodata_to_binary(Enum.reverse(acc)), str}
    end
  end

  # Collect everything until the matching closing bracket
  # Tracks nesting depth to handle nested brackets correctly
  # Uses iolist accumulator for O(n) performance instead of O(n²) string concatenation
  defp collect_until_bracket_close(str, acc) do
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

  # Handle unclosed bracket
  defp collect_until_bracket_close("", acc, _depth) do
    {IO.iodata_to_binary(Enum.reverse(acc)), ""}
  end

  # Collect everything until the closing angle bracket
  # Uses iolist accumulator for O(n) performance
  defp collect_until_angle_close(">" <> rest, acc) do
    {IO.iodata_to_binary(Enum.reverse(acc)), rest}
  end

  defp collect_until_angle_close(<<char::utf8, rest::binary>>, acc) do
    collect_until_angle_close(rest, [<<char::utf8>> | acc])
  end

  # Handle unclosed angle bracket
  defp collect_until_angle_close("", acc) do
    {IO.iodata_to_binary(Enum.reverse(acc)), ""}
  end

  # Collect everything until the closing curly bracket
  # Uses iolist accumulator for O(n) performance
  defp collect_until_curly_close("}" <> rest, acc) do
    {IO.iodata_to_binary(Enum.reverse(acc)), rest}
  end

  defp collect_until_curly_close(<<char::utf8, rest::binary>>, acc) do
    collect_until_curly_close(rest, [<<char::utf8>> | acc])
  end

  # Handle unclosed curly bracket
  defp collect_until_curly_close("", acc) do
    {IO.iodata_to_binary(Enum.reverse(acc)), ""}
  end

  # Parse individual token
  defp parse_token(""), do: nil
  defp parse_token("~"), do: :rest
  defp parse_token("_"), do: :elongate

  defp parse_token(token) do
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

  # Parse a number as either integer or float
  defp parse_number(str) do
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

  # Parse the sound part which may include sample selection: "bd" or "bd:0"
  defp parse_sound_part(sound_part) do
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

  # Known sound parameters
  @sound_params ~w(gain speed pan cutoff resonance delay room)

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

  # Parse subdivision: "bd sd" -> {:subdivision, [{:sound, "bd"}, {:sound, "sd"}]}
  # Or polyphony: "bd,sd" -> {:subdivision, [{:chord, [{:sound, "bd"}, {:sound, "sd"}]}]}
  defp parse_subdivision(inner) do
    # Check if this subdivision contains polyphony (comma-separated at top level)
    # Only check for top-level commas (not inside nested brackets)
    if has_top_level_comma?(inner) do
      # Parse as a chord - flatten any repetitions so we get individual sounds
      # Use split_top_level_comma to respect nesting
      sounds =
        inner
        |> split_top_level_comma()
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(&parse_token/1)
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

  # Check if string has a comma at the top level (not inside nested brackets)
  defp has_top_level_comma?(str) do
    has_top_level_comma?(str, 0)
  end

  defp has_top_level_comma?("", _depth), do: false

  defp has_top_level_comma?("," <> _rest, 0), do: true

  defp has_top_level_comma?("[" <> rest, depth) do
    has_top_level_comma?(rest, depth + 1)
  end

  defp has_top_level_comma?("]" <> rest, depth) do
    has_top_level_comma?(rest, max(0, depth - 1))
  end

  defp has_top_level_comma?("{" <> rest, depth) do
    has_top_level_comma?(rest, depth + 1)
  end

  defp has_top_level_comma?("}" <> rest, depth) do
    has_top_level_comma?(rest, max(0, depth - 1))
  end

  defp has_top_level_comma?("<" <> rest, depth) do
    has_top_level_comma?(rest, depth + 1)
  end

  defp has_top_level_comma?(">" <> rest, depth) do
    has_top_level_comma?(rest, max(0, depth - 1))
  end

  defp has_top_level_comma?(<<_::utf8, rest::binary>>, depth) do
    has_top_level_comma?(rest, depth)
  end

  # Split string by top-level commas only (respecting nesting)
  defp split_top_level_comma(str) do
    split_top_level_comma(str, [], "", 0)
  end

  defp split_top_level_comma("", parts, current, _depth) do
    Enum.reverse([current | parts])
  end

  defp split_top_level_comma("," <> rest, parts, current, 0) do
    split_top_level_comma(rest, [current | parts], "", 0)
  end

  defp split_top_level_comma("[" <> rest, parts, current, depth) do
    split_top_level_comma(rest, parts, current <> "[", depth + 1)
  end

  defp split_top_level_comma("]" <> rest, parts, current, depth) do
    split_top_level_comma(rest, parts, current <> "]", max(0, depth - 1))
  end

  defp split_top_level_comma("{" <> rest, parts, current, depth) do
    split_top_level_comma(rest, parts, current <> "{", depth + 1)
  end

  defp split_top_level_comma("}" <> rest, parts, current, depth) do
    split_top_level_comma(rest, parts, current <> "}", max(0, depth - 1))
  end

  defp split_top_level_comma("<" <> rest, parts, current, depth) do
    split_top_level_comma(rest, parts, current <> "<", depth + 1)
  end

  defp split_top_level_comma(">" <> rest, parts, current, depth) do
    split_top_level_comma(rest, parts, current <> ">", max(0, depth - 1))
  end

  defp split_top_level_comma(<<char::utf8, rest::binary>>, parts, current, depth) do
    split_top_level_comma(rest, parts, current <> <<char::utf8>>, depth)
  end

  # Parse alternation: "bd sd hh" -> {:alternate, [options]}
  # Cycles through options sequentially based on cycle number
  defp parse_alternation(inner) do
    options =
      inner
      |> String.split()
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&parse_token/1)
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
  defp calculate_timings(parsed_tokens) do
    # Flatten any nested structures first
    flattened = flatten_structure(parsed_tokens)

    if length(flattened) == 0 do
      []
    else
      # Calculate total weight and assign time/duration based on weights
      calculate_weighted_timings(flattened)
    end
  end

  # Calculate timings with weight support
  defp calculate_weighted_timings(tokens) do
    # Calculate total weight
    total_weight =
      tokens
      |> Enum.map(&get_token_weight/1)
      |> Enum.sum()

    # Assign time and duration based on weights
    {events, _current_time} =
      Enum.reduce(tokens, {[], 0.0}, fn token, {events_acc, current_time} ->
        weight = get_token_weight(token)
        duration = weight / total_weight

        new_events =
          case token do
            :rest ->
              []

            {:sound, sound, sample, probability, _weight} ->
              params = if probability, do: %{probability: probability}, else: %{}
              [Event.new(sound, current_time, duration: duration, sample: sample, params: params)]

            {:sound_with_params, sound, sample, sound_params} ->
              # Remove internal _weight key before creating event
              clean_params = Map.delete(sound_params, :_weight)

              [
                Event.new(sound, current_time,
                  duration: duration,
                  sample: sample,
                  params: clean_params
                )
              ]

            {:chord, sounds} ->
              # Create multiple events at the same time for polyphony
              Enum.map(sounds, fn
                {:sound, sound, sample, probability, _weight} ->
                  params = if probability, do: %{probability: probability}, else: %{}

                  Event.new(sound, current_time,
                    duration: duration,
                    sample: sample,
                    params: params
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
                  params: params
                )
              ]

            {:division, sound, sample, divisor} ->
              # Store divisor in params; playback system decides if event plays
              params = %{division: divisor}

              [
                Event.new(sound, current_time,
                  duration: duration,
                  sample: sample,
                  params: params
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
                  params: params
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
                    params: params
                  )

                _ ->
                  nil
              end)
              |> Enum.reject(&is_nil/1)

            {:polymetric, groups} ->
              # Each group is timed independently over the full duration
              # Process each group as its own mini-cycle
              groups
              |> Enum.flat_map(fn group_tokens ->
                flattened = flatten_structure(group_tokens)
                calculate_polymetric_group_events(flattened, current_time, duration)
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
                      steps
                    )
                  end)

                {:subdivision, items} ->
                  # Single group, treat like subdivision with steps
                  flattened = flatten_structure(items)
                  calculate_polymetric_stepped_events(flattened, current_time, duration, steps)

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
  defp calculate_polymetric_stepped_events(tokens, start_time, total_duration, steps) do
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
                  params: params
                )

              {:chord, sounds} ->
                Enum.map(sounds, fn
                  {:sound, sound, sample, probability, _weight} ->
                    params = if probability, do: %{probability: probability}, else: %{}

                    Event.new(sound, start_time + time_offset,
                      duration: event_duration,
                      sample: sample,
                      params: params
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
  defp calculate_polymetric_group_events(tokens, start_time, total_duration) do
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
                Event.new(sound, current_time, duration: duration, sample: sample, params: params)

              {:chord, sounds} ->
                # Return list for chord
                Enum.map(sounds, fn
                  {:sound, sound, sample, probability, _weight} ->
                    params = if probability, do: %{probability: probability}, else: %{}

                    Event.new(sound, current_time,
                      duration: duration,
                      sample: sample,
                      params: params
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
  defp flatten_token({:sound, _, _, _, _} = sound), do: [sound]
  defp flatten_token({:sound_with_params, _, _, _} = sound), do: [sound]
  defp flatten_token({:repeat, items}), do: Enum.flat_map(items, &flatten_token/1)
  defp flatten_token({:subdivision, items}), do: Enum.flat_map(items, &flatten_token/1)
  defp flatten_token({:chord, _sounds} = chord), do: [chord]
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
    pattern = bjorklund(k, n)
    # Apply offset (rotate the pattern)
    rotated = rotate_list(pattern, offset)

    Enum.map(rotated, fn
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

  # Bjorklund's algorithm for generating euclidean rhythms
  # Distributes k pulses over n steps as evenly as possible
  # Returns a list of 1s (hits) and 0s (rests)
  defp bjorklund(k, n) when k == n do
    List.duplicate(1, n)
  end

  defp bjorklund(k, n) when k == 0 do
    List.duplicate(0, n)
  end

  defp bjorklund(k, n) do
    # Initialize: k groups of [1] and (n-k) groups of [0]
    ones = List.duplicate([1], k)
    zeros = List.duplicate([0], n - k)
    bjorklund_iterate(ones, zeros)
  end

  # Recursive step of Bjorklund's algorithm
  defp bjorklund_iterate(left, []) do
    List.flatten(left)
  end

  defp bjorklund_iterate(left, right) when length(right) == 1 do
    List.flatten(left ++ right)
  end

  defp bjorklund_iterate(left, right) do
    # Distribute right elements among left elements
    min_len = min(length(left), length(right))
    {left_take, left_rest} = Enum.split(left, min_len)
    {right_take, right_rest} = Enum.split(right, min_len)

    # Combine pairs
    combined = Enum.zip_with(left_take, right_take, fn l, r -> l ++ r end)

    # Continue with combined as left, and remainder as right
    bjorklund_iterate(combined, left_rest ++ right_rest)
  end

  # Rotate a list by offset positions to the left
  defp rotate_list(list, 0), do: list
  defp rotate_list([], _offset), do: []

  defp rotate_list(list, offset) do
    len = length(list)
    normalized_offset = rem(offset, len)
    {front, back} = Enum.split(list, normalized_offset)
    back ++ front
  end
end
