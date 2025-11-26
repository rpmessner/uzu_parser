# UzuParser Feature Roadmap

This roadmap is based on features from [TidalCycles](https://tidalcycles.org/docs/reference/mini_notation/) and [Strudel](https://strudel.cc/learn/mini-notation/).

---

## Architectural Role

**UzuParser is the "pattern brain" of the Elixir music ecosystem.**

```
┌─────────────────────────────────────────────────────────────────┐
│                        Client Applications                       │
│  kino_harmony (Livebook) │ harmony.nvim (Neovim) │ discord_uzu  │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
              ┌─────────────────────────┐
              │     HarmonyServer       │
              │    (API Gateway)        │
              │  - RPC for non-Elixir   │
              │  - Scheduling           │
              │  - delegates to ↓       │
              └───────────┬─────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  UzuParser   │  │   harmony    │  │   waveform   │
│  (patterns)  │  │   (theory)   │  │   (audio)    │
│              │  │              │  │              │
│ • parse      │  │ • chords     │  │ • OSC        │
│ • fast/slow  │  │ • scales     │  │ • SuperDirt  │
│ • stack/cat  │  │ • voicings   │  │ • MIDI       │
│ • every/when │  │ • intervals  │  │ • scheduling │
│ • rev/jux    │  │              │  │              │
└──────────────┘  └──────────────┘  └──────────────┘
```

**Responsibilities:**
- **Parsing**: Convert mini-notation strings → `[%Event{}]` lists
- **Transformations**: `fast`, `slow`, `rev`, `stack`, `cat`, `every`, `when`, `jux`, `degrade_by`
- **Pattern algebra**: Combining, sequencing, layering patterns

**NOT responsible for:**
- Scheduling/timing (→ waveform)
- Audio output (→ waveform)
- Music theory (→ harmony)
- RPC/remote access (→ HarmonyServer)

**Why transformations live here:**
- Transformations are pure functions on event lists
- No scheduling, timing, or audio concerns
- Reusable by any Elixir project without HarmonyServer
- Follows Tidal/Strudel model where Pattern type owns transformations

---

## ✅ Implemented

### v0.1.0
- **Basic sequences** - Space-separated sounds: `"bd sd hh sd"`
- **Rests** - Silence with `~`: `"bd ~ sd ~"`
- **Subdivisions** - Brackets for faster divisions: `"bd [sd sd] hh"`
- **Repetition** - Multiply with `*`: `"bd*4"`
- **Sample selection** - Choose samples with `:`: `"bd:0 sd:1"`

### v0.2.0 ✅ Complete
- **Performance fix** - O(n²) → O(n) bracket collection
- **Polyphony `,`** - Play multiple sounds simultaneously: `"[bd,sd,hh]"`
- **Random Removal `?`** - Probabilistic events: `"bd?"` or `"bd?0.25"`
- **Elongation `@`** - Temporal weight: `"bd@2 sd"` (proportional durations)
- **Replication `!`** - Repeat events: `"bd!3"` (alternative to `*`)

### v0.3.0 ✅ Complete
- **Random Choice `|`** - Randomly select one option: `"bd|sd|hh"`
- **Alternation `<>`** - Cycle through options: `"<bd sd hh>"`

## 🎯 Phase 1 & 2: Complete! 🎊

## 🎼 Phase 3: Advanced Rhythms (v0.4.0)

Priority: Medium - Generative and complex rhythms

### Euclidean Rhythms `()`
Generate rhythms using Euclidean distribution.
```elixir
"bd(3,8)"        # 3 hits distributed over 8 steps
"bd(3,8,2)"      # 3 hits over 8 steps, offset by 2
"bd(5,12)"       # complex polyrhythm
```
**Use case**: World music rhythms, polyrhythms, generative patterns

### Division `/`
Slow down patterns over multiple cycles.
```elixir
"bd/2"           # play every other cycle
"[bd sd]/4"      # pattern over 4 cycles
```
**Use case**: Slow-evolving patterns, ambient textures

### Polymetric Sequences `{}`
Create patterns with different step counts.
```elixir
"{bd sd hh, cp}"  # 3 steps vs 1 step
"{bd sd, hh cp oh}" # 2 steps vs 3 steps
```
**Use case**: Polyrhythms, complex time signatures

## 🎚️ Phase 4: Parameters (v0.5.0)

Priority: Medium - Sound manipulation and control

### Parameter Syntax `|param:value`
Add parameters to sounds for manipulation.
```elixir
"bd|gain:0.8"           # volume control
"bd|speed:2|pan:0.5"    # multiple params
"bd:0|gain:1.2"         # sample + params
```
**Parameters to support**:
- `gain` - Volume (0.0 to 1.0+)
- `speed` - Playback speed/pitch
- `pan` - Stereo position (-1.0 to 1.0)
- `cutoff` - Filter cutoff
- `resonance` - Filter resonance
- `delay` - Delay amount
- `room` - Reverb size

**Use case**: Sound design, dynamics, mixing

## 🔄 Phase 5: Pattern Transformations (v0.5.0)

Priority: **HIGH** - Core pattern manipulation for kino_harmony integration

### Temporal Transformations
```elixir
UzuParser.fast(events, 2.0)    # Speed up by factor (compress time)
UzuParser.slow(events, 2.0)    # Slow down by factor (expand time)
UzuParser.rev(events)          # Reverse pattern order and timing
```
**Implementation**: Transform `time` field of `%Event{}` structs

### Pattern Combinators
```elixir
UzuParser.stack([pattern1, pattern2])  # Play simultaneously (merge events)
UzuParser.cat([pattern1, pattern2])    # Play sequentially (offset timing)
```
**Implementation**: Combine event lists with appropriate timing adjustments

### Conditional Transformations
```elixir
UzuParser.every(events, 3, &UzuParser.rev/1)  # Apply every N cycles
UzuParser.when_(events, fn cycle -> rem(cycle, 2) == 0 end, &fast(&1, 2))
```
**Note**: `when_` because `when` is reserved in Elixir

### Parameterized Transformations
```elixir
UzuParser.jux(events, &UzuParser.rev/1)   # Left: original, Right: transformed
UzuParser.degrade_by(events, 0.5)         # Randomly remove ~50% of events
UzuParser.degrade_by(events, 0.5, seed: 42)  # Deterministic for testing
```

### Implementation Notes
- All transformations operate on `[%UzuParser.Event{}]` lists
- Transform `time` field (0.0-1.0 cycle position)
- Preserve all event params during transformation
- Pure functions - no side effects, no scheduling

### Testing Strategy
- Unit tests for each transformation
- Property-based tests with StreamData
- Edge cases: empty lists, single events, boundary conditions

---

## 🔮 Phase 6: Advanced Features (v0.6.0+)

Priority: Low - Nice-to-have enhancements

### Pattern Elongation `_`
Extend event duration across multiple steps.
```elixir
"bd _ sd _"      # bd and sd hold for 2 steps each
```

### Ratio Notation `%`
Specify ratios for complex timing.
```elixir
"bd%3"           # ratio-based timing
```

### Shorthand Separator `.`
Alternative grouping syntax.
```elixir
"bd . sd . hh"   # shorthand for grouping
```

### Nested Combinations
Complex pattern nesting and combinations.
```elixir
"[bd [sd,hh]*2]?0.5"     # all features combined
"<bd|cp [sd hh]>@2/3"    # complex selection + timing
```

## 🛠️ Infrastructure Improvements

### Testing
- Property-based testing with StreamData
- Benchmarking suite
- Fuzzing for parser robustness

### Documentation
- Interactive examples in docs
- Audio playback examples (if possible)
- Migration guide for each version

### Performance
- Parser optimization
- Caching for repeated patterns
- Streaming API for large patterns

## 📊 Priority Matrix

| Feature | Complexity | Impact | Priority |
|---------|-----------|--------|----------|
| Polyphony `,` | Medium | High | Phase 1 |
| Elongation `@` | Low | High | Phase 1 |
| Replication `!` | Low | Medium | Phase 1 |
| Random Removal `?` | Medium | High | Phase 1 |
| Random Choice `\|` | Medium | High | Phase 2 |
| Alternation `<>` | Medium | High | Phase 2 |
| Euclidean `()` | High | High | Phase 3 |
| Division `/` | Low | Medium | Phase 3 |
| Polymetric `{}` | High | Medium | Phase 3 |
| Parameters `\|param` | High | High | Phase 4 |
| Elongation `_` | Low | Low | Phase 5 |
| Ratio `%` | Medium | Low | Phase 5 |

## 🎯 Recommended Next Steps

Based on impact and complexity:

1. **Start with Phase 1** - Essential operators that significantly expand pattern capability
2. **Polyphony `,`** - Most requested feature, enables chords and layering
3. **Random Removal `?`** - Adds life and variation to patterns
4. **Elongation `@`** - Simple but powerful for rhythm shaping
5. **Replication `!`** - Completes the repetition feature set

## References

- [TidalCycles Mini-Notation Reference](https://tidalcycles.org/docs/reference/mini_notation/)
- [Strudel Mini-Notation Guide](https://strudel.cc/learn/mini-notation/)
- [Uzu Language Catalog](https://uzu.lurk.org/)
