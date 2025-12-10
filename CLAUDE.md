# CLAUDE.md - UzuParser

## Project Overview

**uzu_parser** is a NimbleParsec-based parser for pattern mini-notation used in live coding. It converts text patterns into an Abstract Syntax Tree (AST).

**Purpose:** Parse Strudel/TidalCycles-style pattern strings into AST for interpretation by uzu_pattern.

**Version:** 0.5.0

**Status:** Stable - parsing only (interpretation moved to uzu_pattern)

## Architecture

```
Pattern String → Grammar (NimbleParsec) → AST
    "bd sd"    →       parse/1          → {:sequence, [%{type: :atom, value: "bd"}, ...]}
```

**Note:** uzu_parser returns AST only. Event generation and timing are handled by `uzu_pattern`.

## Key Modules

| Module | Purpose |
|--------|---------|
| `UzuParser` | Main public API (thin wrapper) |
| `UzuParser.Grammar` | NimbleParsec grammar definition (700 lines) |

## What Moved to uzu_pattern

After the dependency refactor, these modules now live in `uzu_pattern`:

| Old Location | New Location | Purpose |
|--------------|--------------|---------|
| `UzuParser.Interpreter` | `UzuPattern.Interpreter` | AST → Pattern conversion |
| `UzuParser.Event` | `UzuPattern.Event` | Event struct |
| `UzuParser.Euclidean` | `UzuPattern.Euclidean` | Rhythm generation |

## Quick Reference

```elixir
# Parse a pattern - returns AST, not events
{:ok, ast} = UzuParser.parse("bd sd hh")
# => {:ok, {:sequence, [
#      %{type: :atom, value: "bd", source_start: 0, source_end: 2},
#      %{type: :atom, value: "sd", source_start: 3, source_end: 5},
#      %{type: :atom, value: "hh", source_start: 6, source_end: 8}
#    ]}}

# For events, use uzu_pattern:
events = UzuPattern.parse("bd sd hh") |> UzuPattern.Pattern.query(0)
```

## Commands

```bash
mix test          # Run tests
mix compile       # Compile
```

## Supported Syntax

| Syntax | Description | Example |
|--------|-------------|---------|
| Space | Sequential | `bd sd` |
| `[ ]` | Subdivision | `[bd sd] hh` |
| `*n` | Repeat | `bd*4` |
| `/n` | Division (slow) | `[bd sd]/2` |
| `(k,n)` | Euclidean | `bd(3,8)` |
| `?` | Probability | `bd?` or `bd?0.25` |
| `@n` | Weight | `bd@2` |
| `_` | Elongation | `bd _ sd` |
| `< >` | Alternation | `<bd sd>` |
| `{ }` | Polymetric | `{bd sd, hh hh hh}` |
| `:n` | Sample variant | `bd:3` |
| `~` | Rest | `bd ~ sd ~` |
| `,` | Polyphony | `[bd,sd]` |
| `\|` | Random choice | `bd\|sd` |
| `\|param:val` | Parameters | `bd\|gain:0.8` |

### Jazz/Harmony Extensions

| Syntax | Description | Example |
|--------|-------------|---------|
| `^n` | Scale degree | `^1 ^3 ^5` |
| `^b7` | Flat degree | `^b7` |
| `^#11` | Sharp degree | `^#11` |
| `@Chord` | Chord symbol | `@Dm7 @G7` |
| `@Roman` | Roman numeral | `@ii @V @I` |

## Dependencies

- `nimble_parsec` - Parser combinator

## Related Projects

- **uzu_pattern** - Pattern interpretation and transformations (depends on uzu_parser)
- **waveform** - SuperCollider OSC client with pattern scheduling
- **harmony** - Music theory library
