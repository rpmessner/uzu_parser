defmodule UzuParser.Event do
  @moduledoc """
  Represents a single event in a pattern with timing and sound parameters.

  Events are the atomic units of a pattern - each event represents a sound
  (or control change) that should occur at a specific time.

  ## Fields

    * `:sound` - The sound name (e.g., "bd", "sd", "hh")
    * `:sample` - The sample number (e.g., 0, 1, 2), nil means use default
    * `:time` - The time offset within the cycle (0.0 to 1.0)
    * `:duration` - How long the event lasts (0.0 to 1.0, default 1.0)
    * `:params` - Additional parameters (volume, pan, speed, etc.)

  ## Examples

      # Basic kick drum at beat 0
      %Event{sound: "bd", sample: nil, time: 0.0, duration: 0.25, params: %{}}

      # Snare at beat 2 with specific sample and volume
      %Event{sound: "sd", sample: 1, time: 0.5, duration: 0.25, params: %{gain: 0.8}}
  """

  @type t :: %__MODULE__{
          sound: String.t(),
          sample: non_neg_integer() | nil,
          time: float(),
          duration: float(),
          params: map()
        }

  defstruct sound: "",
            sample: nil,
            time: 0.0,
            duration: 1.0,
            params: %{}

  @doc """
  Creates a new event with the given sound at the specified time.

  ## Examples

      iex> Event.new("bd", 0.0)
      %Event{sound: "bd", sample: nil, time: 0.0, duration: 1.0, params: %{}}

      iex> Event.new("sd", 0.5, sample: 1, duration: 0.25, params: %{gain: 0.8})
      %Event{sound: "sd", sample: 1, time: 0.5, duration: 0.25, params: %{gain: 0.8}}
  """
  def new(sound, time, opts \\ []) do
    %__MODULE__{
      sound: sound,
      sample: Keyword.get(opts, :sample),
      time: time,
      duration: Keyword.get(opts, :duration, 1.0),
      params: Keyword.get(opts, :params, %{})
    }
  end
end
