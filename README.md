# UzuParser

Parser for Strudel/Tidal-style mini-notation, used in live coding and algorithmic music generation.

## Overview

UzuParser converts text-based pattern notation into an Abstract Syntax Tree (AST). It's designed for live coding environments and algorithmic music systems, providing a simple yet expressive syntax for creating rhythmic and melodic patterns.

**Note:** UzuParser handles parsing only. For event generation and pattern transformations, see [UzuPattern](https://github.com/rpmessner/uzu_pattern).

## Installation

Add `uzu_parser` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:uzu_parser, "~> 0.6.0"}
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

# For timed events, use UzuPattern:
pattern = UzuPattern.parse("bd sd hh")
haps = UzuPattern.query(pattern, 0)
# => [%Hap{value: %{sound: "bd"}, part: %{begin: Ratio.new(0,1), ...}}, ...]
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

### Replication

Exclamation mark replicates with weight:

```elixir
UzuParser.parse("bd!4")      # four bds, each with weight 1
UzuParser.parse("[bd!3 sd]") # three bds then one sd in subdivision
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

### Weight

At sign specifies relative duration:

```elixir
UzuParser.parse("bd@2 sd")   # kick twice as long as snare
UzuParser.parse("bd@3 sd@1") # kick takes 3/4, snare takes 1/4
```

### Elongation

Underscore extends the previous sound:

```elixir
UzuParser.parse("bd _ sd")   # kick held for 2/3, snare for 1/3
UzuParser.parse("bd _ _ sd") # kick held for 3/4, snare for 1/4
```

### Alternation

Angle brackets cycle through options:

```elixir
UzuParser.parse("<bd sd hh>")  # bd on cycle 0, sd on cycle 1, hh on cycle 2
```

### Random Choice

Pipe randomly selects one option:

```elixir
UzuParser.parse("bd|sd|hh")  # pick one randomly per cycle
```

### Polymetric

Curly braces create independent timing:

```elixir
UzuParser.parse("{bd sd, hh hh hh}")  # 2-against-3 polyrhythm
UzuParser.parse("{bd sd hh}%8")       # fit pattern into 8 steps
```

### Euclidean Rhythms

Parentheses create Euclidean patterns:

```elixir
UzuParser.parse("bd(3,8)")      # 3 hits distributed over 8 steps
UzuParser.parse("bd(3,8,1)")    # with rotation offset
```

### Parameters

Pipe with key:value sets sound parameters:

```elixir
UzuParser.parse("bd|gain:0.8|speed:2")
UzuParser.parse("bd|lpf:2000|room:0.5")
```

### Period Separator

Period works like space but creates visual grouping:

```elixir
UzuParser.parse("bd sd . hh cp")  # same as "bd sd hh cp"
```

## AST Structure

The parser returns an AST with node types:

- `:sequence` - Sequential elements
- `:stack` - Polyphonic (simultaneous) elements
- `:subdivision` - Bracketed group with optional modifiers
- `:alternation` - Angle bracket alternation
- `:polymetric` - Curly brace polymetric group
- `:atom` - Sound/note with optional modifiers
- `:rest` - Silence (`~`)
- `:elongation` - Underscore continuation (`_`)

Each atom node includes:
- `value` - Sound name
- `sample` - Sample number (from `:n`)
- `repeat` - Repetition count (from `*n`)
- `replicate` - Replication count (from `!n`)
- `euclidean` - `{k, n, offset}` tuple (from `(k,n)` or `(k,n,o)`)
- `probability` - Float 0-1 (from `?` or `?n`)
- `weight` - Float (from `@n`)
- `params` - Map of parameters (from `|key:value`)
- `source_start`, `source_end` - Position in source string

## Source Position Tracking

All AST nodes include source positions for editor integration:

```elixir
{:ok, {:sequence, nodes}} = UzuParser.parse("bd sd")
[bd, sd] = nodes

bd.source_start  # => 0
bd.source_end    # => 2
sd.source_start  # => 3
sd.source_end    # => 5
```

This enables features like syntax highlighting, error reporting, and click-to-edit in live coding environments.

## Ecosystem

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
- **UzuPattern**: Interprets AST into patterns, applies transformations, queries events
- **Waveform**: Handles audio output via OSC/SuperDirt/Web Audio

## Error Handling

```elixir
# Successful parse
{:ok, ast} = UzuParser.parse("bd sd")

# Parse error
{:error, message} = UzuParser.parse("[bd sd")
# => {:error, "missing terminator: ]"}
```

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
