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
- `time` - Position in the cycle (0.0 to 1.0)
- `duration` - How long the event lasts (0.0 to 1.0)
- `params` - Additional parameters (map, for future extensions)

```elixir
%UzuParser.Event{
  sound: "bd",
  time: 0.0,
  duration: 0.25,
  params: %{}
}
```

## Projects Using UzuParser

- [KinoSpaetzle](https://github.com/rpmessner/kino_spaetzle) - Livebook live coding environment
- [discord_uzu](https://github.com/rpmessner/discord_uzu) - Discord bot for live coding

## Future Features

- Sample selection: `"bd:0"`, `"bd:1"`
- Parameters: `"bd|gain:0.8|speed:2"`
- Polyphony: `"[bd,sd]"` (multiple sounds at once)
- Euclidean rhythms: `"bd(3,8)"` (3 hits in 8 steps)
- Pattern transformations: `fast()`, `slow()`, `rev()`

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

Apache 2.0 License - See LICENSE for details

## Credits

Inspired by the pattern mini-notation from [TidalCycles](https://tidalcycles.org/) and [Strudel](https://strudel.cc/).
