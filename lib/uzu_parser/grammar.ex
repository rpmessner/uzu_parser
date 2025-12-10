defmodule UzuParser.Grammar do
  @moduledoc """
  NimbleParsec grammar for Uzu mini-notation patterns.

  Parses pattern strings into an AST that can be interpreted into timed events.

  ## Supported Syntax

  - Basic sequences: `bd sd hh`
  - Rests: `~`
  - Subdivisions: `[bd sd]`, nested: `[[bd sd] hh]`
  - Polyphony (chords): `[bd,sd,hh]`
  - Polymetric: `{bd sd hh, cp}`, `{bd sd}%4`
  - Alternation: `<bd sd hh>`
  - Sample selection: `bd:1`
  - Repetition: `bd*3`
  - Replication: `bd!3`
  - Probability: `bd?`, `bd?0.25`
  - Weight: `bd@2`
  - Elongation: `bd _ _`
  - Random choice: `bd|sd|hh`
  - Parameters: `bd|gain:0.8|speed:2`
  - Euclidean: `bd(3,8)`, `bd(3,8,2)`
  - Division: `bd/2`, `[bd sd]/2`
  """

  import NimbleParsec

  # ============================================================
  # Basic Tokens
  # ============================================================

  # Whitespace (spaces, tabs, newlines, carriage returns)
  optional_ws = ascii_string([?\s, ?\t, ?\n, ?\r], min: 0)

  # Numbers (with optional negative sign)
  integer_part = ascii_string([?0..?9], min: 1)
  optional_negative = optional(string("-"))

  float_number =
    optional_negative
    |> concat(integer_part)
    |> string(".")
    |> concat(integer_part)
    |> reduce({Enum, :join, [""]})
    |> map({String, :to_float, []})

  integer_number =
    optional_negative
    |> concat(integer_part)
    |> reduce({Enum, :join, [""]})
    |> map({String, :to_integer, []})

  number = choice([float_number, integer_number])

  # Sound name characters (letters, numbers, some special chars including underscore)
  sound_char = ascii_char([?a..?z, ?A..?Z, ?0..?9, ?-, ?#, ?^, ?_])

  # Basic sound name: bd, sd, hh, 808, etc.
  sound_name =
    times(sound_char, min: 1)
    |> reduce({List, :to_string, []})

  # Rest token
  rest = string("~") |> replace(:rest)

  # Elongation token - standalone underscore only (not followed by alphanumeric)
  elongation =
    string("_")
    |> lookahead_not(ascii_char([?a..?z, ?A..?Z, ?0..?9, ?_]))
    |> replace(:elongation)

  # ============================================================
  # Jazz Tokens (scale degrees, chords, roman numerals)
  # ============================================================

  # Scale degree: ^1, ^3, ^b7, ^#5, ^11, etc.
  degree_modifier = ascii_char([?b, ?#])
  degree_number = ascii_string([?0..?9], min: 1)

  scale_degree =
    string("^")
    |> optional(degree_modifier)
    |> concat(degree_number)
    |> reduce({List, :to_string, []})
    |> post_traverse({:build_scale_degree, []})

  # Chord symbol: @Cmaj7, @Dm7, @G7b5, etc.
  # Roman numeral: @I, @ii, @V7, @bVII, etc.
  # Must start with a letter (not a number) to be a chord/roman
  chord_first_char = ascii_char([?a..?z, ?A..?Z, ?#, ?b])
  chord_rest_chars = ascii_char([?a..?z, ?A..?Z, ?0..?9, ?#, ?b])

  chord_or_roman =
    string("@")
    |> concat(chord_first_char)
    |> repeat(chord_rest_chars)
    |> reduce({List, :to_string, []})
    |> post_traverse({:build_chord_or_roman, []})

  # Bare @ or @number is treated as a sound
  bare_at =
    string("@")
    |> optional(ascii_string([?0..?9], min: 1))
    |> lookahead_not(chord_first_char)
    |> reduce({List, :to_string, []})
    |> post_traverse({:build_bare_at, []})

  # ============================================================
  # Modifiers (applied after sound name)
  # ============================================================

  # Sample selection: :0, :1, :12
  sample_modifier =
    ignore(string(":"))
    |> concat(integer_number)
    |> unwrap_and_tag(:sample)

  # Probability: ?, ?0.5
  probability_modifier =
    ignore(string("?"))
    |> optional(number)
    |> tag(:probability)

  # Weight: @2, @1.5
  weight_modifier =
    ignore(string("@"))
    |> concat(number)
    |> unwrap_and_tag(:weight)

  # Repetition: *3, *4
  repetition_modifier =
    ignore(string("*"))
    |> concat(integer_number)
    |> unwrap_and_tag(:repeat)

  # Replication: !3, !4
  replication_modifier =
    ignore(string("!"))
    |> concat(integer_number)
    |> unwrap_and_tag(:replicate)

  # Division: /2, /4
  division_modifier =
    ignore(string("/"))
    |> concat(number)
    |> unwrap_and_tag(:division)

  # Euclidean rhythm: (3,8) or (3,8,2)
  euclidean_modifier =
    ignore(string("("))
    |> concat(integer_number)
    |> ignore(string(","))
    |> concat(integer_number)
    |> optional(
      ignore(string(","))
      |> concat(integer_number)
    )
    |> ignore(string(")"))
    |> tag(:euclidean)

  # Sound parameter: |gain:0.8, |speed:2
  param_key =
    ascii_char([?a..?z])
    |> repeat(ascii_char([?a..?z, ?A..?Z, ?0..?9, ?_]))
    |> reduce({List, :to_string, []})

  param_pair =
    ignore(string("|"))
    |> concat(param_key)
    |> ignore(string(":"))
    |> concat(number)
    |> tag(:param)

  # All modifiers that can follow a sound
  sound_modifier =
    choice([
      sample_modifier,
      euclidean_modifier,
      probability_modifier,
      weight_modifier,
      repetition_modifier,
      replication_modifier,
      division_modifier
    ])

  # ============================================================
  # Elements
  # ============================================================

  # A basic element: sound with optional modifiers and params
  # e.g., bd:1*3?0.5|gain:0.8
  # Position tracking uses pre_traverse to capture start position
  positioned_element =
    pre_traverse(empty(), {:save_start_position, []})
    |> concat(sound_name)
    |> unwrap_and_tag(:sound)
    |> repeat(sound_modifier)
    |> repeat(param_pair)
    |> post_traverse({:build_positioned_element, []})

  # Rest element (positioned)
  positioned_rest =
    post_traverse(
      rest,
      {:wrap_rest_with_position, []}
    )

  # Elongation element (positioned)
  positioned_elongation =
    post_traverse(
      elongation,
      {:wrap_elongation_with_position, []}
    )

  # Jazz tokens (positioned)
  positioned_scale_degree = scale_degree
  positioned_chord_or_roman = chord_or_roman
  positioned_bare_at = bare_at

  # ============================================================
  # Random Choice (pipe-separated sounds)
  # ============================================================

  # Handle pipe-separated random choice: bd|sd|hh
  # We need to be careful not to confuse with param pipes
  # Random choice has sounds separated by | without colons

  random_choice_sound =
    sound_name
    |> unwrap_and_tag(:sound)
    |> repeat(choice([sample_modifier, probability_modifier, weight_modifier]))
    |> post_traverse({:build_element, []})

  random_choice =
    random_choice_sound
    |> times(
      ignore(string("|"))
      |> lookahead_not(param_key |> ignore(string(":")))
      |> concat(random_choice_sound),
      min: 1
    )
    |> tag(:random_choice)
    |> post_traverse({:wrap_with_position, []})

  # ============================================================
  # Structures (recursive via defcombinatorp)
  # ============================================================

  # Subdivision: [bd sd]
  defcombinatorp(
    :subdivision_inner,
    ignore(string("["))
    |> concat(parsec(:sequence_or_stack))
    |> ignore(optional_ws)
    |> ignore(string("]"))
    |> tag(:subdivision_content)
    |> optional(choice([repetition_modifier, division_modifier]))
    |> post_traverse({:build_subdivision, []})
  )

  # Alternation: <bd sd hh>
  defcombinatorp(
    :alternation_inner,
    ignore(string("<"))
    |> concat(parsec(:sequence_content))
    |> ignore(optional_ws)
    |> ignore(string(">"))
    |> tag(:alternation_content)
    |> post_traverse({:build_alternation, []})
  )

  # Polymetric: {bd sd, hh}
  defcombinatorp(
    :polymetric_inner,
    ignore(string("{"))
    |> concat(parsec(:polymetric_groups))
    |> ignore(optional_ws)
    |> ignore(string("}"))
    |> tag(:polymetric_content)
    |> optional(
      ignore(string("%"))
      |> concat(integer_number)
      |> unwrap_and_tag(:steps)
    )
    |> post_traverse({:build_polymetric, []})
  )

  # Polymetric groups are comma-separated sequences
  defcombinatorp(
    :polymetric_groups,
    parsec(:sequence_content)
    |> repeat(
      ignore(optional_ws)
      |> ignore(string(","))
      |> ignore(optional_ws)
      |> concat(parsec(:sequence_content))
    )
    |> tag(:groups)
  )

  # Sequence or stack (handles comma for polyphony inside [])
  defcombinatorp(
    :sequence_or_stack,
    parsec(:sequence_content)
    |> optional(
      times(
        ignore(optional_ws)
        |> ignore(string(","))
        |> ignore(optional_ws)
        |> concat(parsec(:sequence_content)),
        min: 1
      )
      |> tag(:stack_rest)
    )
    |> post_traverse({:maybe_build_stack, []})
  )

  # Any item that can appear in a sequence
  defcombinatorp(
    :sequence_item,
    choice([
      parsec(:subdivision_inner),
      parsec(:alternation_inner),
      parsec(:polymetric_inner),
      random_choice,
      positioned_rest,
      positioned_elongation,
      positioned_scale_degree,
      positioned_chord_or_roman,
      positioned_bare_at,
      positioned_element
    ])
  )

  # Separator between sequence items (whitespace, period, or implicit between brackets)
  # Adjacent brackets like "][" or "><" are implicit separators
  separator =
    choice([
      # Explicit whitespace or period separator
      times(
        choice([
          ascii_string([?\s, ?\t, ?\n, ?\r], min: 1),
          string(".") |> lookahead_not(ascii_char([?0..?9]))
        ]),
        min: 1
      ),
      # Implicit separator: lookahead for opening bracket/angle (allows [a][b], <a><b>, [a]<b>)
      lookahead(ascii_char([?[, ?<, ?{]))
    ])

  # Sequence content (space or period separated items)
  defcombinatorp(
    :sequence_content,
    ignore(optional_ws)
    |> concat(parsec(:sequence_item))
    |> repeat(
      ignore(separator)
      |> concat(parsec(:sequence_item))
    )
    |> tag(:sequence)
  )

  # Top-level pattern
  defcombinatorp(
    :pattern,
    ignore(optional_ws)
    |> concat(parsec(:sequence_content))
    |> ignore(optional_ws)
  )

  # Public parser
  defparsec(:parse_pattern, parsec(:pattern))

  # ============================================================
  # Post-traverse helpers
  # ============================================================

  defp build_element(rest, args, context, _line, _offset) do
    {sound, modifiers} = extract_sound_and_modifiers(args)

    element = %{
      type: :atom,
      value: sound,
      sample: Keyword.get(modifiers, :sample),
      weight: Keyword.get(modifiers, :weight, 1.0),
      repeat: Keyword.get(modifiers, :repeat),
      replicate: Keyword.get(modifiers, :replicate),
      probability: extract_probability(Keyword.get(modifiers, :probability)),
      division: Keyword.get(modifiers, :division),
      euclidean: Keyword.get(modifiers, :euclidean),
      params: extract_params(modifiers)
    }

    {rest, [element], context}
  end

  defp extract_sound_and_modifiers(args) do
    case Keyword.pop(args, :sound) do
      {nil, rest} -> {"", rest}
      {sound, rest} -> {sound, rest}
    end
  end

  defp extract_probability(nil), do: nil
  defp extract_probability([]), do: 0.5
  defp extract_probability([value]), do: value

  defp extract_params(modifiers) do
    modifiers
    |> Keyword.get_values(:param)
    |> Enum.map(fn [key, value] -> {String.to_atom(key), value} end)
    |> Map.new()
  end

  # Save start position in context for later use
  defp save_start_position(rest, args, context, _line, offset) do
    {rest, args, Map.put(context, :element_start, offset)}
  end

  # Build positioned element using saved start position
  defp build_positioned_element(rest, args, context, _line, offset) do
    {sound, modifiers} = extract_sound_and_modifiers(args)
    start_pos = Map.get(context, :element_start, offset)

    element = %{
      type: :atom,
      value: sound,
      sample: Keyword.get(modifiers, :sample),
      weight: Keyword.get(modifiers, :weight, 1.0),
      repeat: Keyword.get(modifiers, :repeat),
      replicate: Keyword.get(modifiers, :replicate),
      probability: extract_probability(Keyword.get(modifiers, :probability)),
      division: Keyword.get(modifiers, :division),
      euclidean: Keyword.get(modifiers, :euclidean),
      params: extract_params(modifiers),
      source_start: start_pos,
      source_end: offset
    }

    {rest, [element], Map.delete(context, :element_start)}
  end

  # For single atoms (maps) - fallback for wrap_with_position
  defp wrap_with_position(rest, [%{} = item], context, _line, offset) do
    item_size = estimate_item_size(item)
    start_pos = offset - item_size
    wrapped = Map.merge(item, %{source_start: start_pos, source_end: offset})
    {rest, [wrapped], context}
  end

  # For tagged structures like {:subdivision, ...}, {:alternation, ...}, {:random_choice, ...}
  defp wrap_with_position(rest, [{tag, content} | modifiers], context, _line, offset)
       when tag in [:subdivision, :alternation, :polymetric, :random_choice] do
    # Build a structure map from the tagged tuple and modifiers
    base = %{
      type: tag,
      children: content,
      source_start: nil,
      source_end: offset
    }

    # Apply any modifiers (repeat, division, steps)
    wrapped =
      Enum.reduce(modifiers, base, fn
        {:repeat, n}, acc -> Map.put(acc, :repeat, n)
        {:division, n}, acc -> Map.put(acc, :division, n)
        {:steps, n}, acc -> Map.put(acc, :steps, n)
        _, acc -> acc
      end)

    {rest, [wrapped], context}
  end

  # Fallback for other list cases
  defp wrap_with_position(rest, items, context, _line, offset) when is_list(items) do
    wrapped = %{items: items, source_start: nil, source_end: offset}
    {rest, [wrapped], context}
  end

  defp wrap_rest_with_position(rest, [:rest], context, _line, offset) do
    item = %{type: :rest, source_start: offset - 1, source_end: offset}
    {rest, [item], context}
  end

  defp wrap_elongation_with_position(rest, [:elongation], context, _line, offset) do
    item = %{type: :elongation, source_start: offset - 1, source_end: offset}
    {rest, [item], context}
  end

  defp maybe_build_stack(rest, args, context, _line, _offset) do
    # args is a keyword list from tag/2
    case Keyword.get(args, :stack_rest) do
      nil ->
        # No stack, just return as-is
        {rest, args, context}

      stack_rest when is_list(stack_rest) ->
        # Build a stack from first sequence and rest
        first_items = Keyword.get(args, :sequence, [])
        rest_items = Keyword.get_values(stack_rest, :sequence)
        all_seqs = [first_items | rest_items]
        {rest, [{:stack, all_seqs}], context}
    end
  end

  # Build subdivision structure from parsed content and modifiers
  defp build_subdivision(rest, args, context, _line, offset) do
    {content, modifiers} = extract_content_and_modifiers(args, :subdivision_content)

    base = %{
      type: :subdivision,
      children: content,
      source_start: nil,
      source_end: offset
    }

    wrapped = apply_modifiers(base, modifiers)
    {rest, [wrapped], context}
  end

  # Build alternation structure
  defp build_alternation(rest, args, context, _line, offset) do
    {content, _modifiers} = extract_content_and_modifiers(args, :alternation_content)

    wrapped = %{
      type: :alternation,
      children: content,
      source_start: nil,
      source_end: offset
    }

    {rest, [wrapped], context}
  end

  # Build polymetric structure
  defp build_polymetric(rest, args, context, _line, offset) do
    {content, modifiers} = extract_content_and_modifiers(args, :polymetric_content)

    base = %{
      type: :polymetric,
      children: content,
      source_start: nil,
      source_end: offset
    }

    wrapped = apply_modifiers(base, modifiers)
    {rest, [wrapped], context}
  end

  # Extract content and modifiers from args
  defp extract_content_and_modifiers(args, content_tag) do
    case Keyword.pop(args, content_tag) do
      {nil, rest} -> {[], rest}
      {content, rest} -> {content, rest}
    end
  end

  # Apply modifiers to a structure
  defp apply_modifiers(base, modifiers) do
    Enum.reduce(modifiers, base, fn
      {:repeat, n}, acc -> Map.put(acc, :repeat, n)
      {:division, n}, acc -> Map.put(acc, :division, n)
      {:steps, n}, acc -> Map.put(acc, :steps, n)
      _, acc -> acc
    end)
  end

  # ============================================================
  # Jazz Token Builders
  # ============================================================

  # Build scale degree: ^1, ^b3, ^#5
  # Only degrees 1-13 are valid (with optional b/# accidentals)
  defp build_scale_degree(rest, [degree_str], context, _line, offset) do
    # degree_str is like "^1", "^b3", "^#5"
    value_str = String.trim_leading(degree_str, "^")

    # Extract the numeric part (removing accidentals)
    numeric_str = String.replace(value_str, ~r/[b#]/, "")

    # Parse the number to check if it's a valid scale degree
    params =
      case Integer.parse(numeric_str) do
        {n, ""} when n >= 1 and n <= 13 ->
          # Valid scale degree - include jazz params
          value = if value_str == numeric_str, do: n, else: value_str
          %{harmony_type: :degree, harmony_value: value}

        _ ->
          # Invalid scale degree (0, 14+, or non-numeric) - treat as regular sound
          %{}
      end

    item = %{
      type: :atom,
      value: degree_str,
      sample: nil,
      weight: 1.0,
      repeat: nil,
      replicate: nil,
      probability: nil,
      division: nil,
      euclidean: nil,
      params: params,
      source_start: offset - byte_size(degree_str),
      source_end: offset
    }

    {rest, [item], context}
  end

  # Build chord symbol or roman numeral: @Dm7, @V7, @bVII
  defp build_chord_or_roman(rest, [chord_str], context, _line, offset) do
    # chord_str is like "@Dm7", "@V7", "@bVII"
    value = String.trim_leading(chord_str, "@")

    # Determine if it's a roman numeral or chord symbol
    harmony_type = if is_roman_numeral?(value), do: :roman, else: :chord

    item = %{
      type: :atom,
      value: chord_str,
      sample: nil,
      weight: 1.0,
      repeat: nil,
      replicate: nil,
      probability: nil,
      division: nil,
      euclidean: nil,
      params: %{harmony_type: harmony_type, harmony_value: value},
      source_start: offset - byte_size(chord_str),
      source_end: offset
    }

    {rest, [item], context}
  end

  # Build bare @ or @number as a sound
  defp build_bare_at(rest, [value], context, _line, offset) do
    item = %{
      type: :atom,
      value: value,
      sample: nil,
      weight: 1.0,
      repeat: nil,
      replicate: nil,
      probability: nil,
      division: nil,
      euclidean: nil,
      params: %{},
      source_start: offset - byte_size(value),
      source_end: offset
    }

    {rest, [item], context}
  end

  # Check if a string looks like a roman numeral (starts with I, V, i, v, b, #)
  defp is_roman_numeral?(str) do
    case str do
      "I" <> _ -> true
      "V" <> _ -> true
      "i" <> _ -> true
      "v" <> _ -> true
      "b" <> rest -> is_roman_numeral?(rest)
      "#" <> rest -> is_roman_numeral?(rest)
      _ -> false
    end
  end

  # Rough size estimates for position tracking
  defp estimate_item_size(%{type: :atom, value: v}), do: byte_size(v)
  defp estimate_item_size(_), do: 0

  # ============================================================
  # Public API
  # ============================================================

  @doc """
  Parse a pattern string into an AST.

  Returns `{:ok, ast}` on success or `{:error, message}` on failure.
  """
  def parse(input) when is_binary(input) do
    case parse_pattern(input) do
      {:ok, [result], "", _, _, _} ->
        {:ok, result}

      {:ok, result, "", _, _, _} ->
        {:ok, result}

      {:ok, _result, rest, _, _, _} when byte_size(rest) > 0 ->
        {:error, "Unexpected input remaining: #{inspect(rest)}"}

      {:error, reason, rest, _, {line, col}, _} ->
        {:error, "Parse error at #{line}:#{col}: #{reason}, remaining: #{inspect(rest)}"}
    end
  end
end
