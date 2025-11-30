defmodule UzuParser.Timing do
  @moduledoc """
  Timing calculation for mini-notation patterns.

  Converts parsed tokens into timed events with:
  - Start time (0.0 to 1.0 within cycle)
  - Duration (fraction of cycle)
  - Source positions for highlighting

  Handles weighted timing for elongation (@), polymetric patterns,
  and various token types.
  """

  alias UzuParser.Event
  alias UzuParser.Euclidean

  @doc """
  Calculate timings for parsed tokens.

  Takes a list of tokens (possibly with position info as {token, start, end} tuples)
  and returns a list of Event structs with timing information.
  """
  def calculate_timings(parsed_tokens) do
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
  defp flatten_structure_with_positions(tokens) do
    tokens
    |> Enum.flat_map(&flatten_token_with_position/1)
    |> process_elongations_with_positions()
  end

  # Flatten a token that may have position info
  defp flatten_token_with_position({token, start_pos, end_pos}) do
    flattened = flatten_token(token)
    attach_positions_to_first(flattened, start_pos, end_pos)
  end

  defp flatten_token_with_position(token) do
    flatten_token(token)
    |> Enum.map(&wrap_token_no_position/1)
  end

  defp wrap_token_no_position(token), do: {token, nil, nil}

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
  defp calculate_weighted_timings(tokens) do
    total_weight =
      tokens
      |> Enum.map(fn {token, _, _} -> get_token_weight(token) end)
      |> Enum.sum()

    {events, _current_time} =
      Enum.reduce(tokens, {[], 0.0}, fn {token, src_start, src_end}, {events_acc, current_time} ->
        weight = get_token_weight(token)
        duration = weight / total_weight

        new_events = token_to_events(token, current_time, duration, src_start, src_end)

        {events_acc ++ new_events, current_time + duration}
      end)

    events
  end

  # Convert a token to events
  defp token_to_events(:rest, _time, _duration, _src_start, _src_end), do: []

  defp token_to_events({:degree, degree}, time, duration, src_start, src_end) do
    sound = "^#{degree}"
    params = %{jazz_type: :degree, jazz_value: degree}
    [Event.new(sound, time, duration: duration, params: params, source_start: src_start, source_end: src_end)]
  end

  defp token_to_events({:chord, chord_symbol}, time, duration, src_start, src_end) when is_binary(chord_symbol) do
    sound = "@#{chord_symbol}"
    params = %{jazz_type: :chord, jazz_value: chord_symbol}
    [Event.new(sound, time, duration: duration, params: params, source_start: src_start, source_end: src_end)]
  end

  defp token_to_events({:roman, roman}, time, duration, src_start, src_end) do
    sound = "@#{roman}"
    params = %{jazz_type: :roman, jazz_value: roman}
    [Event.new(sound, time, duration: duration, params: params, source_start: src_start, source_end: src_end)]
  end

  defp token_to_events({:sound, sound, sample, probability, _weight}, time, duration, src_start, src_end) do
    params = if probability, do: %{probability: probability}, else: %{}
    [Event.new(sound, time, duration: duration, sample: sample, params: params, source_start: src_start, source_end: src_end)]
  end

  defp token_to_events({:sound_with_params, sound, sample, sound_params}, time, duration, src_start, src_end) do
    clean_params = Map.delete(sound_params, :_weight)
    [Event.new(sound, time, duration: duration, sample: sample, params: clean_params, source_start: src_start, source_end: src_end)]
  end

  defp token_to_events({:chord, sounds}, time, duration, src_start, src_end) when is_list(sounds) do
    Enum.map(sounds, fn
      {:sound, sound, sample, probability, _weight} ->
        params = if probability, do: %{probability: probability}, else: %{}
        Event.new(sound, time, duration: duration, sample: sample, params: params, source_start: src_start, source_end: src_end)
      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp token_to_events({:random_choice, options}, time, duration, src_start, src_end) do
    option_data = Enum.map(options, &token_to_option_data/1)
    params = %{random_choice: option_data}
    {default_sound, default_sample} = get_default_from_options(options)
    [Event.new(default_sound, time, duration: duration, sample: default_sample, params: params, source_start: src_start, source_end: src_end)]
  end

  defp token_to_events({:alternate, options}, time, duration, src_start, src_end) do
    option_data = Enum.map(options, &token_to_option_data/1)
    params = %{alternate: option_data}
    {default_sound, default_sample} = get_default_from_options(options)
    [Event.new(default_sound, time, duration: duration, sample: default_sample, params: params, source_start: src_start, source_end: src_end)]
  end

  defp token_to_events({:division, sound, sample, divisor}, time, duration, src_start, src_end) do
    params = %{division: divisor}
    [Event.new(sound, time, duration: duration, sample: sample, params: params, source_start: src_start, source_end: src_end)]
  end

  defp token_to_events({:ratio, sound, sample, cycles}, time, duration, src_start, src_end) do
    params = %{speed: 1.0 / cycles}
    [Event.new(sound, time, duration: duration, sample: sample, params: params, source_start: src_start, source_end: src_end)]
  end

  defp token_to_events({:chord_division, sounds, divisor}, time, duration, src_start, src_end) do
    Enum.map(sounds, fn
      {:sound, sound, sample, probability, _weight} ->
        base_params = if probability, do: %{probability: probability}, else: %{}
        params = Map.put(base_params, :division, divisor)
        Event.new(sound, time, duration: duration, sample: sample, params: params, source_start: src_start, source_end: src_end)
      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp token_to_events({:polymetric, groups}, time, duration, src_start, src_end) do
    groups
    |> Enum.flat_map(fn group_tokens ->
      flattened = flatten_structure(group_tokens)
      calculate_polymetric_group_events(flattened, time, duration, src_start, src_end)
    end)
  end

  defp token_to_events({:polymetric_steps, inner_poly, steps}, time, duration, src_start, src_end) do
    case inner_poly do
      {:polymetric, groups} ->
        groups
        |> Enum.flat_map(fn group_tokens ->
          flattened = flatten_structure(group_tokens)
          calculate_polymetric_stepped_events(flattened, time, duration, steps, src_start, src_end)
        end)

      {:subdivision, items} ->
        flattened = flatten_structure(items)
        calculate_polymetric_stepped_events(flattened, time, duration, steps, src_start, src_end)

      _ ->
        []
    end
  end

  defp token_to_events(_, _time, _duration, _src_start, _src_end), do: []

  # Calculate events for polymetric with step control
  defp calculate_polymetric_stepped_events(tokens, start_time, total_duration, steps, src_start, src_end) do
    if length(tokens) == 0 do
      []
    else
      token_count = length(tokens)
      step_duration = total_duration / steps

      {events, _} =
        Enum.with_index(tokens)
        |> Enum.reduce({[], start_time}, fn {token, idx}, {events_acc, _} ->
          time_offset = idx / token_count * total_duration
          event_duration = step_duration

          new_event = stepped_token_to_event(token, start_time + time_offset, event_duration, src_start, src_end)

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

  defp stepped_token_to_event(:rest, _time, _duration, _src_start, _src_end), do: nil

  defp stepped_token_to_event({:sound, sound, sample, probability, _weight}, time, duration, src_start, src_end) do
    params = if probability, do: %{probability: probability}, else: %{}
    Event.new(sound, time, duration: duration, sample: sample, params: params, source_start: src_start, source_end: src_end)
  end

  defp stepped_token_to_event({:chord, sounds}, time, duration, src_start, src_end) do
    Enum.map(sounds, fn
      {:sound, sound, sample, probability, _weight} ->
        params = if probability, do: %{probability: probability}, else: %{}
        Event.new(sound, time, duration: duration, sample: sample, params: params, source_start: src_start, source_end: src_end)
      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp stepped_token_to_event(_, _time, _duration, _src_start, _src_end), do: nil

  # Calculate events for a polymetric group
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

          new_event = group_token_to_event(token, current_time, duration, src_start, src_end)

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

  defp group_token_to_event(:rest, _time, _duration, _src_start, _src_end), do: nil

  defp group_token_to_event({:sound, sound, sample, probability, _weight}, time, duration, src_start, src_end) do
    params = if probability, do: %{probability: probability}, else: %{}
    Event.new(sound, time, duration: duration, sample: sample, params: params, source_start: src_start, source_end: src_end)
  end

  defp group_token_to_event({:chord, sounds}, time, duration, src_start, src_end) do
    Enum.map(sounds, fn
      {:sound, sound, sample, probability, _weight} ->
        params = if probability, do: %{probability: probability}, else: %{}
        Event.new(sound, time, duration: duration, sample: sample, params: params, source_start: src_start, source_end: src_end)
      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp group_token_to_event(_, _time, _duration, _src_start, _src_end), do: nil

  # Get token weight
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

  # Convert token to option data for random_choice/alternate
  defp token_to_option_data(:rest), do: %{sound: nil, sample: nil, probability: nil}

  defp token_to_option_data({:sound, sound, sample, probability, _weight}) do
    %{sound: sound, sample: sample, probability: probability}
  end

  defp token_to_option_data({:repeat, items}) do
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

  # Flatten nested structure into flat list
  @doc false
  def flatten_structure(tokens) do
    tokens
    |> Enum.flat_map(&flatten_token/1)
    |> process_elongations()
  end

  # Process elongation tokens
  defp process_elongations(tokens) do
    {result, _} =
      Enum.reduce(tokens, {[], nil}, fn token, {acc, prev} ->
        case token do
          :elongate ->
            case prev do
              nil ->
                {acc ++ [:rest], nil}

              _ ->
                updated = increase_token_weight(prev)
                {List.replace_at(acc, -1, updated), updated}
            end

          _ ->
            {acc ++ [token], token}
        end
      end)

    result
  end

  # Increase token weight
  defp increase_token_weight({:sound, name, sample, prob, nil}) do
    {:sound, name, sample, prob, 2.0}
  end

  defp increase_token_weight({:sound, name, sample, prob, weight}) do
    {:sound, name, sample, prob, weight + 1.0}
  end

  defp increase_token_weight({:sound_with_params, name, sample, params}) do
    current_weight = Map.get(params, :_weight, 1.0)
    {:sound_with_params, name, sample, Map.put(params, :_weight, current_weight + 1.0)}
  end

  defp increase_token_weight(token), do: token

  # Flatten individual tokens
  @doc false
  def flatten_token(nil), do: []
  def flatten_token(:rest), do: [:rest]
  def flatten_token(:elongate), do: [:elongate]

  # Handle position-wrapped tokens
  def flatten_token({token, start_pos, end_pos})
      when (is_tuple(token) or is_atom(token)) and
           (is_integer(start_pos) or is_nil(start_pos)) and
           (is_integer(end_pos) or is_nil(end_pos)) do
    flatten_token(token)
  end

  def flatten_token({:sound, _, _, _, _} = sound), do: [sound]
  def flatten_token({:sound_with_params, _, _, _} = sound), do: [sound]
  def flatten_token({:degree, _} = degree), do: [degree]
  def flatten_token({:roman, _} = roman), do: [roman]
  def flatten_token({:chord, chord_symbol}) when is_binary(chord_symbol), do: [{:chord, chord_symbol}]
  def flatten_token({:chord, sounds}) when is_list(sounds), do: [{:chord, sounds}]
  def flatten_token({:repeat, items}), do: Enum.flat_map(items, &flatten_token/1)
  def flatten_token({:subdivision, items}), do: Enum.flat_map(items, &flatten_token/1)
  def flatten_token({:random_choice, _options} = choice), do: [choice]
  def flatten_token({:alternate, _options} = alt), do: [alt]
  def flatten_token({:division, _, _, _} = div), do: [div]
  def flatten_token({:ratio, _, _, _} = ratio), do: [ratio]
  def flatten_token({:polymetric, _groups} = poly), do: [poly]
  def flatten_token({:polymetric_steps, _, _} = poly), do: [poly]

  def flatten_token({:subdivision_division, {:subdivision, items}, divisor}) do
    items
    |> Enum.flat_map(&flatten_token/1)
    |> Enum.map(&apply_division(&1, divisor))
  end

  def flatten_token({:subdivision_repeat, {:subdivision, items}, count}) do
    flattened = Enum.flat_map(items, &flatten_token/1)
    List.duplicate(flattened, count) |> List.flatten()
  end

  def flatten_token({:euclidean, sound, sample, k, n, offset}) do
    pattern = Euclidean.rhythm(k, n, offset)

    Enum.map(pattern, fn
      1 -> {:sound, sound, sample, nil, nil}
      0 -> :rest
    end)
  end

  # Apply division to a token
  defp apply_division(:rest, _divisor), do: :rest

  defp apply_division({:sound, sound, sample, _prob, _weight}, divisor) do
    {:division, sound, sample, divisor}
  end

  defp apply_division({:division, sound, sample, existing_divisor}, new_divisor) do
    {:division, sound, sample, existing_divisor * new_divisor}
  end

  defp apply_division({:chord, sounds}, divisor) do
    {:chord_division, sounds, divisor}
  end

  defp apply_division(token, _divisor), do: token
end
