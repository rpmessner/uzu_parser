# UzuParser

Parser for Uzu pattern mini-notation, used in live coding and algorithmic music generation.

## Overview

UzuParser converts text-based pattern notation into an Abstract Syntax Tree (AST). It's designed for live coding environments and algorithmic music systems, providing a simple yet expressive syntax for creating rhythmic and melodic patterns.

**Note:** UzuParser handles parsing only. For event generation and pattern transformations, see [UzuPattern](https://github.com/rpmessner/uzu_pattern).

## Installation

Add `uzu_parser` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:uzu_parser, "~> 0.5.0"}
    # Or for local development:
    # {:uzu_parser, path: "../uzu_parser"}
  ]
end
```

## Quick Start

```elixir
# Parse a pattern - returns AST
{:ok, ast} = UzuParser.parse("bd sd hh")
# => {:ok, {:sequence, [
#      %{type: :atom, value: "bd", source_start: 0, source_end: 2},
#      %{type: :atom, value: "sd", source_start: 3, source_end: 5},
#      %{type: :atom, value: "hh", source_start: 6, source_end: 8}
#    ]}}

# For timed events, use uzu_pattern:
pattern = UzuPattern.parse("bd sd hh")
events = UzuPattern.Pattern.query(pattern, 0)
# => [
#   %UzuPattern.Event{sound: "bd", time: 0.0, duration: 0.333...},
#   %UzuPattern.Event{sound: "sd", time: 0.333..., duration: 0.333...},
#   %UzuPattern.Event{sound: "hh", time: 0.666..., duration: 0.333...}
# ]
```

## Syntax

### Basic Sequences

Space-separated sounds create a sequence:

```elixir
UzuParser.parse("bd sd hh sd")  # 4 elements in sequence
```

### Rests

Use `~` for silence:

```elixir
UzuParser.parse("bd ~ sd ~")  # kick and snare on alternating beats
```

### Subdivisions

Brackets create subdivisions within a step:

```elixir
UzuParser.parse("bd [sd sd] hh")  # snare plays twice as fast
UzuParser.parse("bd [sd hh cp]")  # three sounds in the time of one step
```

### Repetition

Asterisk multiplies elements:

```elixir
UzuParser.parse("bd*4")      # equivalent to "bd bd bd bd"
UzuParser.parse("[bd sd]*2") # repeat the subdivision
```

### Division (Slow)

Slash spreads pattern across cycles:

```elixir
UzuParser.parse("[bd sd]/2")  # pattern takes 2 cycles to complete
```

### Sample Selection

Colon selects sample variants:

```elixir
UzuParser.parse("bd:0 bd:1 bd:2")  # different kick drum samples
```

### Polyphony (Chords)

Comma within brackets plays sounds simultaneously:

```elixir
UzuParser.parse("[bd,sd]")        # kick and snare together
UzuParser.parse("[c3,e3,g3]")     # C major chord
```

### Probability

Question mark adds probability:

```elixir
UzuParser.parse("bd?")       # 50% chance to play
UzuParser.parse("bd?0.25")   # 25% chance to play
```

### Weight / Elongation

At sign specifies relative duration:

```elixir
UzuParser.parse("bd@2 sd")   # kick twice as long as snare
```

Underscore extends the previous sound:

```elixir
UzuParser.parse("bd _ sd")   # kick held for 2/3, snare for 1/3
```

### Alternation

Angle brackets cycle through options:

```elixir
UzuParser.parse("<bd sd hh>")  # bd on cycle 0, sd on cycle 1, hh on cycle 2
```

### Polymetric

Curly braces create independent timing:

```elixir
UzuParser.parse("{bd sd, hh hh hh}")  # 2-against-3 polyrhythm
```

### Euclidean Rhythms

Parentheses create Euclidean patterns:

```elixir
UzuParser.parse("bd(3,8)")      # 3 hits distributed over 8 steps
UzuParser.parse("bd(3,8,1)")    # with rotation offset
```

### Random Choice

Pipe randomly selects one option:

```elixir
UzuParser.parse("bd|sd|hh")  # pick one randomly per cycle
```

### Parameters

Pipe with key:value sets parameters:

```elixir
UzuParser.parse("bd|gain:0.8|speed:2")
```

### Jazz/Harmony Extensions

Scale degrees, chord symbols, and roman numerals:

```elixir
UzuParser.parse("^1 ^3 ^5 ^b7")    # scale degrees
UzuParser.parse("@Dm7 @G7 @Cmaj7") # chord symbols
UzuParser.parse("@ii @V @I")       # roman numerals
```

## AST Structure

The parser returns an AST with node types:

- `:sequence` - Sequential elements
- `:stack` - Polyphonic (simultaneous) elements
- `:subdivision` - Bracketed group with optional modifiers
- `:alternation` - Angle bracket alternation
- `:polymetric` - Curly brace polymetric group
- `:atom` - Sound/note with optional modifiers
- `:rest` - Silence
- `:elongation` - Underscore continuation

Each atom node includes:
- `value` - Sound name
- `sample` - Sample number (if `:n` specified)
- `repeat` - Repetition count (if `*n` specified)
- `euclidean` - `[k, n, offset]` (if `(k,n)` specified)
- `probability` - Float (if `?` specified)
- `weight` - Float (if `@n` specified)
- `params` - Map of parameters
- `source_start`, `source_end` - Position in source string

## Ecosystem Role

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   UzuParser     │────▶│   UzuPattern    │────▶│    Waveform     │
│   (parsing)     │     │ (interpretation │     │    (audio)      │
│                 │     │  & transforms)  │     │                 │
│ • parse/1       │     │ • Interpreter   │     │ • OSC           │
│ • mini-notation │     │ • Pattern struct│     │ • SuperDirt     │
│ • AST output    │     │ • fast/slow/rev │     │ • Web Audio     │
│                 │     │ • query/2       │     │ • scheduling    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

- **UzuParser**: Parses mini-notation strings into AST
- **UzuPattern**: Interprets AST into patterns, applies transformations
- **Waveform**: Handles audio output via OSC/SuperDirt/Web Audio

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
