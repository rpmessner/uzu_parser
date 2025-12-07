defmodule UzuParser.Interpreter do
  @moduledoc """
  Interprets the AST from UzuParser.Grammar into timed events.

  Converts the declarative AST into a flat list of Event structs with
  calculated timing information.
  """

  alias UzuParser.Event
  alias UzuParser.Euclidean

  @doc """
  Interpret an AST into a list of events.

  Takes the AST from UzuParser.Grammar.parse/1 and converts it to events
  with timing information.

  ## Parameters
  - `ast` - The AST from grammar parsing
  - `start_time` - Start time within cycle (default 0.0)
  - `duration` - Total duration for this section (default 1.0)

  ## Returns
  List of Event structs with time, duration, and source positions.
  """
  def interpret(ast, start_time \\ 0.0, duration \\ 1.0)

  def interpret({:sequence, items}, start_time, duration) do
    interpret_sequence(items, start_time, duration)
  end

  def interpret({:stack, sequences}, start_time, duration) do
    # Stack means all sequences play simultaneously (polyphony)
    Enum.flat_map(sequences, fn items ->
      interpret_sequence(items, start_time, duration)
    end)
  end

  def interpret(%{type: :subdivision, children: children} = node, start_time, duration) do
    # Children can be various formats from the grammar
    inner =
      case children do
        [sequence: items] -> {:sequence, items}
        [stack: seqs] -> {:stack, seqs}
        {:sequence, _} = seq -> seq
        {:stack, _} = stack -> stack
        other -> other
      end

    # Apply modifiers
    case node do
      %{repeat: n} when is_integer(n) and n > 1 ->
        # Repeat the subdivision n times
        step = duration / n

        Enum.flat_map(0..(n - 1), fn i ->
          interpret(inner, start_time + i * step, step)
        end)

      %{division: div} when is_number(div) ->
        events = interpret(inner, start_time, duration)
        Enum.map(events, fn event -> %{event | params: Map.put(event.params, :division, div)} end)

      _ ->
        interpret(inner, start_time, duration)
    end
  end

  def interpret(%{type: :alternation, children: children}, start_time, duration) do
    # Children can be [sequence: [...]] or {:sequence, [...]}
    items =
      case children do
        [sequence: items] -> items
        {:sequence, items} -> items
        _ -> []
      end

    # Alternation - cycles through options each cycle
    # Store all options and let playback system select
    options = items_to_option_data(items)
    default = get_default_from_items(items)
    params = Map.merge(default.params || %{}, %{alternate: options})

    [
      Event.new(
        default.sound,
        start_time,
        duration: duration,
        sample: default.sample,
        params: params,
        source_start: default.source_start,
        source_end: default.source_end
      )
    ]
  end

  def interpret(%{type: :polymetric, children: children} = node, start_time, duration) do
    # Children can be [groups: [...]] or {:groups, [...]}
    groups =
      case children do
        [groups: g] -> g
        {:groups, g} -> g
        _ -> []
      end

    case node do
      %{steps: steps} when is_integer(steps) ->
        # Polymetric with step control
        interpret_polymetric_stepped(groups, start_time, duration, steps)

      _ ->
        # Regular polymetric - each group has independent timing
        interpret_polymetric(groups, start_time, duration)
    end
  end

  def interpret(%{type: :random_choice} = node, start_time, duration) do
    children = Map.get(node, :children, [])
    options = Enum.map(children, &atom_to_option_data/1)
    default = List.first(children) || %{value: "?"}

    params = %{random_choice: options}

    [
      Event.new(
        default.value,
        start_time,
        duration: duration,
        sample: default[:sample],
        params: params,
        source_start: node[:source_start],
        source_end: node[:source_end]
      )
    ]
  end

  def interpret(other, start_time, duration) do
    # Fallback - try to interpret as a sequence item
    case other do
      %{type: :atom} = atom ->
        [atom_to_event(atom, start_time, duration)]

      %{type: :rest} ->
        []

      %{type: :elongation} ->
        []

      _ ->
        []
    end
  end

  # Interpret a sequence of items with weighted timing
  defp interpret_sequence(items, start_time, duration) do
    # First, process elongations to adjust weights
    processed = process_elongations(items)

    # Filter out rests for event generation (but keep for timing)
    total_weight =
      processed
      |> Enum.map(&get_weight/1)
      |> Enum.sum()

    if total_weight == 0 do
      []
    else
      {events, _} =
        Enum.reduce(processed, {[], start_time}, fn item, {events_acc, current_time} ->
          weight = get_weight(item)
          item_duration = weight / total_weight * duration

          new_events = interpret_item(item, current_time, item_duration)
          {events_acc ++ new_events, current_time + item_duration}
        end)

      events
    end
  end

  # Process elongation items to increase weight of previous items
  defp process_elongations(items) do
    {result, _} =
      Enum.reduce(items, {[], nil}, fn item, {acc, prev} ->
        case item do
          %{type: :elongation} ->
            case prev do
              nil ->
                # Elongation with no previous - treat as rest
                {acc, nil}

              %{} = prev_item ->
                # Increase weight of previous item
                new_weight = (prev_item[:weight] || 1.0) + 1.0
                updated = Map.put(prev_item, :weight, new_weight)
                {List.replace_at(acc, -1, updated), updated}
            end

          _ ->
            {acc ++ [item], item}
        end
      end)

    result
  end

  # Get weight of an item
  defp get_weight(%{type: :rest}), do: 1.0
  defp get_weight(%{type: :elongation}), do: 0.0
  defp get_weight(%{weight: w}) when is_number(w), do: w
  defp get_weight(_), do: 1.0

  # Interpret a single item within a sequence
  defp interpret_item(%{type: :rest}, _start_time, _duration), do: []

  defp interpret_item(%{type: :atom} = atom, start_time, duration) do
    event = atom_to_event(atom, start_time, duration)

    # Handle repetition
    case atom do
      %{repeat: n} when is_integer(n) and n > 1 ->
        step = duration / n

        Enum.map(0..(n - 1), fn i ->
          %{event | time: start_time + i * step, duration: step}
        end)

      %{replicate: n} when is_integer(n) and n > 1 ->
        step = duration / n

        Enum.map(0..(n - 1), fn i ->
          %{event | time: start_time + i * step, duration: step}
        end)

      %{euclidean: euclid} when is_list(euclid) ->
        interpret_euclidean(atom, euclid, start_time, duration)

      _ ->
        [event]
    end
  end

  defp interpret_item(%{type: :subdivision} = sub, start_time, duration) do
    interpret(sub, start_time, duration)
  end

  defp interpret_item(%{type: :alternation} = alt, start_time, duration) do
    interpret(alt, start_time, duration)
  end

  defp interpret_item(%{type: :polymetric} = poly, start_time, duration) do
    interpret(poly, start_time, duration)
  end

  defp interpret_item(%{type: :random_choice} = choice, start_time, duration) do
    interpret(choice, start_time, duration)
  end

  defp interpret_item(item, start_time, duration) do
    # For sequence/stack structures that appear as items
    case item do
      {:sequence, items} ->
        interpret_sequence(items, start_time, duration)

      {:stack, seqs} ->
        Enum.flat_map(seqs, fn items ->
          interpret_sequence(items, start_time, duration)
        end)

      _ ->
        []
    end
  end

  # Convert an atom node to an event
  defp atom_to_event(%{type: :atom} = atom, start_time, duration) do
    base_params = atom[:params] || %{}

    # Add probability if present
    params =
      case atom[:probability] do
        nil -> base_params
        prob -> Map.put(base_params, :probability, prob)
      end

    # Add division if present
    params =
      case atom[:division] do
        nil -> params
        div -> Map.put(params, :division, div)
      end

    Event.new(
      atom.value,
      start_time,
      duration: duration,
      sample: atom[:sample],
      params: params,
      source_start: atom[:source_start],
      source_end: atom[:source_end]
    )
  end

  # Interpret euclidean rhythm
  defp interpret_euclidean(atom, [k, n], start_time, duration) do
    interpret_euclidean(atom, [k, n, 0], start_time, duration)
  end

  defp interpret_euclidean(atom, [k, n, offset], start_time, duration) do
    pattern = Euclidean.rhythm(k, n, offset)
    step = duration / n

    pattern
    |> Enum.with_index()
    |> Enum.flat_map(fn {hit, i} ->
      if hit == 1 do
        time = start_time + i * step
        [atom_to_event(atom, time, step)]
      else
        []
      end
    end)
  end

  # Interpret polymetric groups (independent timing)
  defp interpret_polymetric(groups, start_time, duration) do
    Enum.flat_map(groups, fn group ->
      items = extract_sequence_items(group)
      interpret_sequence(items, start_time, duration)
    end)
  end

  # Interpret polymetric with step control
  defp interpret_polymetric_stepped(groups, start_time, duration, steps) do
    step_duration = duration / steps

    Enum.flat_map(groups, fn group ->
      items = extract_sequence_items(group)
      token_count = length(items)

      items
      |> Enum.with_index()
      |> Enum.flat_map(fn {item, idx} ->
        time_offset = idx / token_count * duration
        interpret_item(item, start_time + time_offset, step_duration)
      end)
    end)
  end

  # Extract items from sequence in various formats
  defp extract_sequence_items({:sequence, items}), do: items
  defp extract_sequence_items(sequence: items), do: items
  defp extract_sequence_items(items) when is_list(items), do: items
  defp extract_sequence_items(_), do: []

  # Convert items to option data for alternation/random choice
  defp items_to_option_data(items) do
    Enum.map(items, &item_to_option_data/1)
  end

  defp item_to_option_data(%{type: :atom} = atom) do
    %{sound: atom.value, sample: atom[:sample], probability: atom[:probability]}
  end

  defp item_to_option_data(%{type: :rest}) do
    %{sound: nil, sample: nil, probability: nil}
  end

  defp item_to_option_data(_), do: %{sound: nil, sample: nil, probability: nil}

  defp atom_to_option_data(%{type: :atom} = atom) do
    %{sound: atom.value, sample: atom[:sample], probability: atom[:probability]}
  end

  defp atom_to_option_data(_), do: %{sound: nil, sample: nil, probability: nil}

  # Get default sound from items (first non-rest)
  defp get_default_from_items([]) do
    %{sound: "?", sample: nil, params: %{}, source_start: nil, source_end: nil}
  end

  defp get_default_from_items([%{type: :atom} = atom | _]) do
    %{
      sound: atom.value,
      sample: atom[:sample],
      params: %{},
      source_start: atom[:source_start],
      source_end: atom[:source_end]
    }
  end

  defp get_default_from_items([_ | rest]), do: get_default_from_items(rest)
end
