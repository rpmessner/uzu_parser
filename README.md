# UzuParser

Parser for Uzu pattern mini-notation, used in live coding and algorithmic music generation.

## Overview

UzuParser converts text-based pattern notation into structured, timed musical events. It's designed for live coding environments and algorithmic music systems, providing a simple yet expressive syntax for creating rhythmic and melodic patterns.

## Installation

Add `uzu_parser` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:uzu_parser, "~> 0.1.0"}
    # Or for local development:
    # {:uzu_parser, path: "../uzu_parser"}
  ]
end
```

## Quick Start

```elixir
# Parse a simple pattern
UzuParser.parse("bd sd hh sd")
# => [
#   %UzuParser.Event{sound: "bd", time: 0.0, duration: 0.25},
#   %UzuParser.Event{sound: "sd", time: 0.25, duration: 0.25},
#   %UzuParser.Event{sound: "hh", time: 0.5, duration: 0.25},
#   %UzuParser.Event{sound: "sd", time: 0.75, duration: 0.25}
# ]
```

## Syntax

### Basic Sequences

Space-separated sounds are evenly distributed across one cycle (0.0 to 1.0):

```elixir
UzuParser.parse("bd sd hh sd")  # 4 events at times 0.0, 0.25, 0.5, 0.75
```

### Rests

Use `~` for silence:

```elixir
UzuParser.parse("bd ~ sd ~")  # kick and snare on alternating beats
```

### Subdivisions

Brackets create faster divisions within a step:

```elixir
UzuParser.parse("bd [sd sd] hh")  # snare plays twice as fast
UzuParser.parse("bd [sd hh cp]")  # three sounds in the time of one step
```

### Repetition

Asterisk multiplies elements:

```elixir
UzuParser.parse("bd*4")      # equivalent to "bd bd bd bd"
UzuParser.parse("bd*2 sd")   # two kicks, one snare
```

### Sample Selection

Colon selects different samples/variations:

```elixir
UzuParser.parse("bd:0")         # kick drum, sample 0
UzuParser.parse("bd:1 bd:2")    # different kick drum samples
UzuParser.parse("bd:0*4")       # repeat sample 0 four times
UzuParser.parse("bd:0 sd:1 hh:2")  # each sound uses a different sample
```

### Polyphony (Chords)

Comma within brackets plays multiple sounds simultaneously:

```elixir
UzuParser.parse("[bd,sd]")        # kick and snare together
UzuParser.parse("[bd,sd,hh]")     # three sounds at once
UzuParser.parse("bd [sd,hh] cp")  # chord on second beat
UzuParser.parse("[bd:0,sd:1]")    # chord with sample selection
```

### Random Removal (Probability)

Question mark adds probability - events may or may not play:

```elixir
UzuParser.parse("bd?")            # 50% chance to play
UzuParser.parse("bd?0.25")        # 25% chance to play
UzuParser.parse("bd sd? hh")      # only sd is probabilistic
UzuParser.parse("bd:0?0.75")      # sample selection + probability
```

The parser stores probability in the event's `params` field. The playback system decides whether to play each event based on this value.

### Elongation (Temporal Weight)

At sign specifies relative duration/weight of events:

```elixir
UzuParser.parse("bd@2 sd")        # kick twice as long as snare (2/3 vs 1/3)
UzuParser.parse("[bd sd@3 hh]")   # snare 3x longer than bd and hh
UzuParser.parse("bd@1.5 sd")      # fractional weights supported
```

Events are assigned time and duration proportionally based on their weights. Default weight is 1.0 if not specified.

### Replication

Exclamation mark repeats events (similar to `*` but clearer intent):

```elixir
UzuParser.parse("bd!3")           # three bd events
UzuParser.parse("bd!2 sd")        # two kicks, one snare
UzuParser.parse("[bd!2 sd]")      # replication in subdivision
```

Note: In this parser, `!` and `*` produce identical results. Both create separate steps rather than subdividing time.

### Random Choice

Pipe randomly selects one option per evaluation:

```elixir
UzuParser.parse("bd|sd|hh")       # pick one each time
UzuParser.parse("[bd|cp] sd")     # randomize first beat
UzuParser.parse("bd:0|sd:1")      # with sample selection
```

The parser stores all options in the event's `params` field. The playback system decides which option to play using random selection.

### Alternation

Angle brackets cycle through options sequentially:

```elixir
UzuParser.parse("<bd sd hh>")     # bd on cycle 1, sd on 2, hh on 3, repeats
UzuParser.parse("<bd sd> hh")     # alternate kick pattern
UzuParser.parse("<bd:0 sd:1>")    # with sample selection
```

The parser stores all options in the event's `params` field. The playback system uses the cycle number to select which option to play.

### Complex Patterns

Combine features for expressive patterns:

```elixir
# Realistic drum pattern
UzuParser.parse("bd sd [hh hh] sd")

# Layered pattern with repetition and subdivisions
UzuParser.parse("bd*4 ~ [sd sd] ~")

# Nested subdivisions and rests
UzuParser.parse("[bd ~ sd ~] hh")
```

## Event Structure

Each parsed event contains:

- `sound` - The sound/sample name (string)
- `sample` - Sample number (integer >= 0, or nil for default)
- `time` - Position in the cycle (0.0 to 1.0)
- `duration` - How long the event lasts (0.0 to 1.0)
- `params` - Additional parameters (map, for future extensions)

```elixir
%UzuParser.Event{
  sound: "bd",
  sample: 0,
  time: 0.0,
  duration: 0.25,
  params: %{}
}
```

## Projects Using UzuParser

- [KinoHarmony](https://github.com/rpmessner/kino_harmony) - Livebook live coding environment with advanced jazz harmony
- [discord_uzu](https://github.com/rpmessner/discord_uzu) - Discord bot for live coding

## Future Features

- Parameters: `"bd|gain:0.8|speed:2"`
- Euclidean rhythms: `"bd(3,8)"` (3 hits in 8 steps)

## Pattern Transformations

For pattern transformations like `fast`, `slow`, `rev`, `stack`, `cat`, `every`, and `jux`, see [UzuPattern](https://github.com/rpmessner/uzu_pattern) - the pattern orchestration library that builds on UzuParser.

## Ecosystem Role

UzuParser is part of the Elixir music ecosystem:

```
┌───────────────────────────────────────────────────────┐
│                    HarmonyServer                       │
│                   (coordination)                       │
│                                                        │
│  ┌─────────────────┐     ┌─────────────────┐          │
│  │   UzuParser     │────▶│   UzuPattern    │          │
│  │   (parsing)     │     │  (transforms)   │          │
│  │   ◀── HERE      │     │                 │          │
│  │ • parse/1       │     │ • fast/slow/rev │          │
│  │ • mini-notation │     │ • stack/cat     │          │
│  │ • [%Event{}]    │     │ • every/when    │          │
│  └─────────────────┘     └─────────────────┘          │
│                                                        │
└────────────────────────────┬──────────────────────────┘
                             │
                             ▼
                   ┌─────────────────┐
                   │    Waveform     │
                   │    (audio)      │
                   └─────────────────┘
```

- **HarmonyServer**: Coordinates parsing, transforms, and audio output
- **UzuParser**: Parses mini-notation strings into event lists
- **UzuPattern**: Applies transformations to patterns (fast, slow, rev, stack, cat, every, jux)
- **Waveform**: Handles audio output via OSC/SuperDirt/MIDI

## Development

```bash
# Run tests
mix test

# Generate documentation
mix docs

# Format code
mix format
```

## License

MIT License - See LICENSE for details

## Credits

Inspired by the pattern mini-notation from [TidalCycles](https://tidalcycles.org/) and [Strudel](https://strudel.cc/).
