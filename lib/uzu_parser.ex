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
  """

  alias UzuParser.Grammar
  alias UzuParser.Interpreter

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

    if trimmed == "" do
      []
    else
      case Grammar.parse(trimmed) do
        {:ok, ast} ->
          Interpreter.interpret(ast)

        {:error, _reason} ->
          # Return empty list on parse error for backwards compatibility
          []
      end
    end
  end
end
