# UzuParser Feature Roadmap

This roadmap is based on features from [TidalCycles](https://tidalcycles.org/docs/reference/mini_notation/) and [Strudel](https://strudel.cc/learn/mini-notation/).

---

## Architectural Role

**UzuParser handles parsing of mini-notation into event lists.**

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   UzuParser     │────▶│   UzuPattern    │────▶│    Waveform     │
│   (parsing)     │     │  (transforms)   │     │    (audio)      │
│                 │     │                 │     │                 │
│ • parse/1       │     │ • fast/slow/rev │     │ • OSC           │
│ • mini-notation │     │ • stack/cat     │     │ • SuperDirt     │
│ • [%Event{}]    │     │ • every/when    │     │ • MIDI          │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

**Responsibilities:**
- **Parsing**: Convert mini-notation strings → `[%Event{}]` lists
- Focus on syntax parsing only

**NOT responsible for:**
- Pattern transformations (→ UzuPattern)
- Scheduling/timing (→ Waveform)
- Audio output (→ Waveform)

**For pattern transformations** (`fast`, `slow`, `rev`, `stack`, `cat`, `every`, `jux`, etc.), see [UzuPattern](https://github.com/rpmessner/uzu_pattern).

---

## ✅ Implemented

### v0.1.0
- **Basic sequences** - Space-separated sounds: `"bd sd hh sd"`
- **Rests** - Silence with `~`: `"bd ~ sd ~"`
- **Subdivisions** - Brackets for faster divisions: `"bd [sd sd] hh"`
- **Repetition** - Multiply with `*`: `"bd*4"`
- **Sample selection** - Choose samples with `:`: `"bd:0 sd:1"`

### v0.2.0
- **Performance fix** - O(n²) → O(n) bracket collection
- **Polyphony `,`** - Play multiple sounds simultaneously: `"[bd,sd,hh]"`
- **Random Removal `?`** - Probabilistic events: `"bd?"` or `"bd?0.25"`
- **Elongation `@`** - Temporal weight: `"bd@2 sd"` (proportional durations)
- **Replication `!`** - Repeat events: `"bd!3"` (alternative to `*`)

### v0.3.0
- **Random Choice `|`** - Randomly select one option: `"bd|sd|hh"`
- **Alternation `<>`** - Cycle through options: `"<bd sd hh>"`

### v0.4.0 (Phase 3: Advanced Rhythms)
- **Euclidean Rhythms `()`** - Generate rhythms using Euclidean distribution:
  - `"bd(3,8)"` - 3 hits distributed over 8 steps
  - `"bd(3,8,2)"` - 3 hits over 8 steps, offset by 2
  - `"bd(5,12)"` - complex polyrhythm
- **Division `/`** - Slow down patterns over multiple cycles:
  - `"bd/2"` - play every other cycle
  - `"[bd sd]/4"` - pattern over 4 cycles
- **Polymetric Sequences `{}`** - Patterns with different step counts:
  - `"{bd sd hh, cp}"` - 3 steps vs 1 step
  - `"{bd sd, hh cp oh}"` - 2 steps vs 3 steps
  - `"{bd sd hh}%8"` - fit pattern into 8 subdivisions

### v0.5.0 (Phase 4: Parameters)
- **Sound Parameters `|param:value`** - Add parameters to sounds:
  - `"bd|gain:0.8"` - volume control
  - `"bd|speed:2|pan:0.5"` - multiple params
  - `"bd:0|gain:1.2"` - sample + params
  - Supported: gain, speed, pan, cutoff, resonance, delay, room

### v0.6.0 (Phase 5: Advanced Features)
- **Pattern Elongation `_`** - Extend event duration:
  - `"bd _ sd _"` - bd and sd hold for 2 steps each
  - `"bd _ _ sd"` - bd holds for 3 steps
- **Ratio/Speed `%`** - Specify how many cycles pattern spans:
  - `"bd%2"` - spans 2 cycles (speed: 0.5)
  - `"[bd sd]%3"` - pattern spans 3 cycles
- **Shorthand Separator `.`** - Alternative grouping:
  - `"bd . sd . hh"` - visual separation in patterns
- **Jazz Notation** - Music theory tokens:
  - Scale degrees: `"^1"`, `"^3"`, `"^b7"`, `"^#5"`
  - Chord symbols: `"@Dm7"`, `"@G7"`, `"@Cmaj7"`
  - Roman numerals: `"@ii"`, `"@V"`, `"@I"`, `"@bVII"`

---

## 🎊 All Core Phases Complete!

The parser now supports all major mini-notation features from TidalCycles/Strudel plus jazz notation extensions.

---

## 🛠️ Infrastructure & Quality

### Architecture (Completed)
- **Modular design** - Separated into focused modules:
  - `UzuParser` - Main entry point and tokenizer
  - `UzuParser.TokenParser` - Individual token parsing
  - `UzuParser.Timing` - Time/duration calculations
  - `UzuParser.Structure` - Subdivisions, alternations, polymetrics
  - `UzuParser.Collectors` - Bracket/content collection
  - `UzuParser.Euclidean` - Bjorklund's algorithm
  - `UzuParser.Event` - Event struct definition
- **Source position tracking** - Byte offsets for syntax highlighting
- **79% code reduction** - Refactored from 1869 to 393 lines in main module

### Testing (305 tests passing)
- Unit tests for all modules
- Integration tests for jazz notation
- Euclidean rhythm tests including world music patterns
- Structure and timing calculation tests

### Future Improvements
- Property-based testing with StreamData
- Benchmarking suite
- Fuzzing for parser robustness
- Streaming API for large patterns
- Caching for repeated patterns

---

## 📊 Feature Matrix

| Feature | Syntax | Status |
|---------|--------|--------|
| Basic sequences | `bd sd hh` | ✅ Done |
| Rests | `~` | ✅ Done |
| Subdivisions | `[bd sd]` | ✅ Done |
| Repetition | `bd*4` | ✅ Done |
| Sample selection | `bd:0` | ✅ Done |
| Polyphony/Chords | `[bd,sd,hh]` | ✅ Done |
| Random Removal | `bd?`, `bd?0.25` | ✅ Done |
| Elongation (weight) | `bd@2` | ✅ Done |
| Replication | `bd!3` | ✅ Done |
| Random Choice | `bd\|sd\|hh` | ✅ Done |
| Alternation | `<bd sd hh>` | ✅ Done |
| Euclidean Rhythms | `bd(3,8)`, `bd(3,8,2)` | ✅ Done |
| Division | `bd/2` | ✅ Done |
| Polymetric | `{bd sd, hh}` | ✅ Done |
| Polymetric Steps | `{bd sd}%8` | ✅ Done |
| Sound Parameters | `bd\|gain:0.8` | ✅ Done |
| Pattern Elongation | `bd _ sd _` | ✅ Done |
| Ratio/Speed | `bd%2` | ✅ Done |
| Shorthand Separator | `bd . sd` | ✅ Done |
| Jazz Scale Degrees | `^1`, `^b7`, `^#5` | ✅ Done |
| Jazz Chord Symbols | `@Dm7`, `@G7` | ✅ Done |
| Jazz Roman Numerals | `@ii`, `@V`, `@I` | ✅ Done |

---

## References

- [TidalCycles Mini-Notation Reference](https://tidalcycles.org/docs/reference/mini_notation/)
- [Strudel Mini-Notation Guide](https://strudel.cc/learn/mini-notation/)
- [Uzu Language Catalog](https://uzu.lurk.org/)
