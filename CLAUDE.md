# CLAUDE.md - UzuParser

## Project Overview

**uzu_parser** is a NimbleParsec-based parser for pattern mini-notation used in live coding. It converts text patterns into timed musical events.

**Purpose:** Parse Strudel/TidalCycles-style pattern strings into event lists.

**Version:** 0.4.0

**Status:** Stable - core parsing complete

## Architecture

```
Pattern String → Grammar (NimbleParsec) → Interpreter → Events
    "bd sd"    →        AST            →   timing    → [{0, 0.5, %{s: "bd"}}, ...]
```

## Key Modules

| Module | Purpose |
|--------|---------|
| `UzuParser` | Main public API |
| `UzuParser.Grammar` | NimbleParsec grammar definition |
| `UzuParser.Interpreter` | AST to timed events |
| `UzuParser.Event` | Event struct and utilities |
| `UzuParser.Euclidean` | Euclidean rhythm generation |

## Quick Reference

```elixir
# Parse a pattern
{:ok, events} = UzuParser.parse("bd sd hh sd")

# Returns list of events with timing
[
  %UzuParser.Event{start: 0.0, duration: 0.25, value: "bd"},
  %UzuParser.Event{start: 0.25, duration: 0.25, value: "sd"},
  %UzuParser.Event{start: 0.5, duration: 0.25, value: "hh"},
  %UzuParser.Event{start: 0.75, duration: 0.25, value: "sd"}
]

# Pattern syntax examples
"bd sd"           # Sequential
"[bd sd] hh"      # Grouped
"bd*4"            # Repeat
"bd(3,8)"         # Euclidean rhythm
"bd?"             # Random (50% chance)
"bd@2"            # Elongate (takes 2 slots)
"<bd sd hh>"      # Alternating per cycle
```

## Commands

```bash
mix test          # Run tests (300+ tests)
mix compile       # Compile
```

## Supported Syntax

| Syntax | Description | Example |
|--------|-------------|---------|
| Space | Sequential | `bd sd` |
| `[ ]` | Group | `[bd sd] hh` |
| `*n` | Repeat | `bd*4` |
| `(k,n)` | Euclidean | `bd(3,8)` |
| `?` | Random (50%) | `bd?` |
| `@n` | Elongate | `bd@2` |
| `< >` | Alternate | `<bd sd>` |
| `:n` | Sample variant | `bd:3` |
| `~` | Rest | `bd ~ sd ~` |

## Dependencies

- `nimble_parsec` - Parser combinator

## Integration

uzu_parser can be used with:
- **uzu_pattern** - Pattern transformations (fast, slow, rev, etc.)
- **waveform** - Elixir audio scheduling via PatternScheduler

## Related Projects

- **uzu_pattern** - Pattern transformation library
- **waveform** - SuperCollider OSC client with pattern scheduling
- **harmony** - Music theory library
