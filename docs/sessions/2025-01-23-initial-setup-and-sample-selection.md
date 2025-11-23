# Session: Initial Setup & Sample Selection Feature

**Date**: 2025-01-23
**Status**: ✅ Complete
**Version**: Moving from v0.1.0 → v0.2.0 prep

## Session Summary

This session established the project infrastructure and implemented the first new feature (sample selection) for UzuParser, an Elixir-based pattern mini-notation parser for live coding music.

**Project Context**: UzuParser was **extracted from KinoHarmony** (formerly KinoSpaetzle) to be a standalone, reusable library. This allows:
- **UzuParser** (this project): Focus purely on parsing mini-notation
- **KinoHarmony**: Use UzuParser for parsing while focusing on UI, visualization, and jazz harmony
- **Waveform**: Handle audio scheduling and SuperDirt integration

The design was validated against Waveform's `PatternScheduler` and `SuperDirt` modules to ensure seamless integration with KinoHarmony.

## Context & Motivation

**UzuParser** was extracted from [KinoHarmony](https://github.com/rpmessner/kino_harmony) (formerly KinoSpaetzle), a TidalCycles-inspired live coding environment for Livebook with advanced jazz harmony.

**Extraction Rationale**:
- **Separation of concerns**: Parser logic separate from UI/visualization
- **Reusability**: Other projects (discord_uzu, future tools) can use the parser
- **Maintainability**: Easier to test, develop, and document
- **Integration**: Works seamlessly with [Waveform](https://github.com/rpmessner/waveform) for audio scheduling

**Ecosystem**:
```
KinoHarmony (Livebook UI) ─┐
                           ├─→ UzuParser ─→ Waveform ─→ SuperDirt ─→ Audio
discord_uzu (Discord bot) ─┘
```

## Accomplishments

### 1. Infrastructure Setup ✅

#### GitHub Actions CI
- Created `.github/workflows/ci.yml`
- Runs on push/PR to main branch
- Tests: mix test, format check, compile with warnings-as-errors, docs generation
- Uses Elixir 1.18.0 + OTP 27.0
- Includes dependency caching for faster builds

#### License Change
- Changed from Apache 2.0 → MIT License
- Updated in: `LICENSE`, `mix.exs:45`, `README.md:133`
- **Rationale**: MIT is more appropriate for a small parser library
- **Legal consideration**: UzuParser is inspired by TidalCycles/Strudel notation but is an independent implementation, not a derivative work of their code

### 2. Sample Selection Feature ✅

Implemented `bd:N` syntax for selecting different samples/variations of sounds.

#### Changes Made

**Event Structure** (`lib/uzu_parser/event.ex`)
- Added `sample: non_neg_integer() | nil` field to Event struct
- Updated Event.new/3 to accept `:sample` option
- Updated all documentation and examples

**Parser Logic** (`lib/uzu_parser.ex`)
- Changed sound token from `{:sound, name}` → `{:sound, name, sample}`
- Added `parse_sample_selection/1` function for `"bd:0"` syntax
- Updated `parse_repetition/1` to handle `"bd:1*4"` combinations
- Modified `calculate_timings/1` to pass sample to Event.new
- Updated `flatten_token/1` pattern matching for 3-tuple format

**Testing** (`test/uzu_parser_test.exs`)
- Added 7 new tests in "sample selection" describe block
- Tests cover: basic selection, mixed patterns, repetition, subdivisions, invalid input
- All 30 tests passing (23 original + 7 new)

**Documentation**
- Updated module docs in `lib/uzu_parser.ex`
- Added sample selection section to `README.md`
- Moved sample selection from "Future Features" to "Supported Syntax"
- Updated all code examples to show `sample` field

#### Syntax Examples

```elixir
# Basic sample selection
UzuParser.parse("bd:0")
# => [%Event{sound: "bd", sample: 0, ...}]

# Different samples
UzuParser.parse("bd:1 bd:2")
# => [%Event{sample: 1, ...}, %Event{sample: 2, ...}]

# With repetition
UzuParser.parse("bd:0*4")
# => Four events with sample: 0

# In subdivisions
UzuParser.parse("[bd:0 sd:1]")
# => Works as expected

# Invalid samples treated as literal sound names
UzuParser.parse("bd:abc")
# => [%Event{sound: "bd:abc", sample: nil, ...}]
```

### 3. Feature Research & Roadmap ✅

Created comprehensive `ROADMAP.md` based on:
- [TidalCycles mini-notation](https://tidalcycles.org/docs/reference/mini_notation/)
- [Strudel mini-notation](https://strudel.cc/learn/mini-notation/)

Identified 15+ features organized into 5 phases.

### 4. Waveform Integration Analysis ✅

Analyzed [Waveform](https://github.com/rpmessner/waveform) (v0.3.0) to ensure UzuParser design is compatible with the downstream orchestration layer.

**Key Findings**:
- **PatternScheduler** expects: `[{cycle_position, params}, ...]` tuples
- **SuperDirt parameters** map perfectly to Event struct design
- **Event.sound** → SuperDirt `s:` parameter (sample name)
- **Event.sample** → SuperDirt `n:` parameter (sample number)
- **Event.time** → PatternScheduler cycle_position (0.0-1.0)
- **Event.params** → Additional SuperDirt params (gain, speed, pan, effects)

**Design Validation**: The Event struct created in this session is **perfectly designed** for Waveform integration. No changes needed!

Created `docs/WAVEFORM_INTEGRATION.md` with:
- Complete integration guide
- Helper functions for conversion
- Usage examples with Livebook
- Parameter mapping reference

## Current Project State

### File Structure
```
uzu_parser/
├── .github/
│   └── workflows/
│       └── ci.yml                 # GitHub Actions CI
├── docs/
│   ├── sessions/
│   │   └── 2025-01-23-*.md        # This file (full session notes)
│   ├── NEXT_STEPS.md              # Quick reference for next session
│   └── PERFORMANCE.md             # Performance analysis & optimization guide
├── lib/
│   ├── uzu_parser.ex              # Main parser module
│   └── uzu_parser/
│       └── event.ex               # Event struct
├── test/
│   ├── test_helper.exs
│   └── uzu_parser_test.exs        # 30 tests
├── CHANGELOG.md
├── LICENSE                         # MIT
├── README.md
├── ROADMAP.md                      # Feature roadmap (5 phases, 15+ features)
└── mix.exs                         # Package config
```

### Test Coverage
- 30 tests, 0 failures
- Coverage: basic sequences, rests, subdivisions, repetition, sample selection, complex patterns

### Package Status
- Ready for Hex.pm publishing
- All required files present
- Documentation generates cleanly
- Tests passing
- Code formatted

## Key Decisions & Context

### 1. Token Format Change

**Decision**: Changed internal token representation from 2-tuple to 3-tuple
- Before: `{:sound, "bd"}`
- After: `{:sound, "bd", nil}` or `{:sound, "bd", 0}`

**Rationale**: Simpler than using keyword lists or nested structures for sample data

**Impact**: All pattern matching in parser updated to handle 3-tuple format

### 2. Sample Number Validation

**Decision**: Invalid sample numbers (negative, non-integer) treated as literal sound names
- `"bd:-1"` → `sound: "bd:-1", sample: nil`
- `"bd:abc"` → `sound: "bd:abc", sample: nil`

**Rationale**: Graceful degradation, no parser errors for invalid input

### 3. Sample Field Default

**Decision**: `sample: nil` means "use default sample" (not sample 0)
- `nil` = unspecified/default
- `0`, `1`, `2`, ... = explicit sample selection

**Rationale**: Allows downstream consumers to distinguish between explicit sample:0 and no sample specified

## Next Steps Recommendations

### Immediate (v0.2.0)

Based on ROADMAP.md priority matrix, implement **Phase 1: Essential Operators**

**Recommended order**:

1. **Polyphony `,`** (HIGHEST PRIORITY)
   - Syntax: `"[bd,sd,hh]"` plays sounds simultaneously
   - Impact: HIGH (enables chords, layering)
   - Complexity: MEDIUM
   - Implementation notes:
     - Return multiple events at same `time` value
     - Need to handle `[bd,sd]` → two events both at same timestamp
     - Works with subdivisions: `"bd [sd,hh]"`

2. **Random Removal `?`**
   - Syntax: `"bd?"` (50%) or `"bd?0.25"` (25% probability)
   - Impact: HIGH (variation, humanization)
   - Complexity: MEDIUM
   - Implementation notes:
     - Parse `?` and optional decimal `?0.N`
     - Store probability in event params or as separate field
     - Execution happens at playback time (parser just stores probability)

3. **Elongation `@`**
   - Syntax: `"bd@2 sd"` (bd twice as long)
   - Impact: HIGH (rhythm shaping)
   - Complexity: LOW
   - Implementation notes:
     - Parse `@N` suffix
     - Use weight to calculate relative durations
     - `[bd@2 sd]` → bd gets 2/3 of time, sd gets 1/3

4. **Replication `!`**
   - Syntax: `"bd!3"` (three separate steps)
   - Impact: MEDIUM
   - Complexity: LOW
   - Implementation notes:
     - Similar to `*` but different timing semantics
     - `bd*3` = faster, `bd!3` = same speed, more steps

### Technical Debt / Improvements

1. **Add ExDoc examples that run as tests**
   - Use `@doc` examples as doctests
   - Currently examples are shown but not verified

2. **Property-based testing**
   - Add StreamData for parser fuzzing
   - Generate random patterns, ensure no crashes
   - Verify roundtrip properties

3. **Benchmark suite**
   - Measure parser performance
   - Identify optimization opportunities
   - Track performance regressions

4. **Pattern validation/linting**
   - Helpful error messages for malformed patterns
   - Suggest corrections for common mistakes

## Implementation Guide for Next Feature: Polyphony

### Parser Changes Needed

**Current token model**:
```elixir
{:sound, "bd", nil}  # single sound
```

**New token needed**:
```elixir
{:chord, [{:sound, "bd", nil}, {:sound, "sd", 1}]}  # polyphony
```

**Where to add parsing**:
1. `parse_token/1` - detect `,` within current token context
2. Handle in `parse_subdivision/1` since `[bd,sd]` uses brackets
3. Split on `,` and create multiple sound tokens
4. In `calculate_timings/1`, chord token → multiple events at same time

**Example parsing**:
```elixir
"[bd,sd]"
→ tokenize → [{:subdivision, [{:chord, [{:sound, "bd", nil}, {:sound, "sd", nil}]}]}]
→ flatten → [{:chord, [...]}]
→ calculate_timings → [
  %Event{sound: "bd", time: 0.0, ...},
  %Event{sound: "sd", time: 0.0, ...}
]
```

**Edge cases to handle**:
- `"bd,sd,hh"` - chord at top level (no brackets)
- `"[bd:0,sd:1]"` - chord with sample selection
- `"[bd,sd]*2"` - chord repetition
- `"[bd,sd]?"` - probabilistic chord (all or nothing)
- `"bd [sd,hh] cp"` - chord in middle of sequence

### Test Cases to Add

```elixir
describe "polyphony" do
  test "parses simple chord" do
    events = UzuParser.parse("[bd,sd]")
    assert length(events) == 2
    assert Enum.at(events, 0).time == Enum.at(events, 1).time
  end

  test "parses chord with sample selection" do
    events = UzuParser.parse("[bd:0,sd:1,hh:2]")
    assert length(events) == 3
    assert Enum.all?(events, &(&1.time == 0.0))
    assert Enum.at(events, 0).sample == 0
    assert Enum.at(events, 1).sample == 1
    assert Enum.at(events, 2).sample == 2
  end

  test "parses chord in sequence" do
    events = UzuParser.parse("bd [sd,hh] cp")
    assert length(events) == 4
    # bd at 0.0, sd+hh at 0.333, cp at 0.666
  end

  test "parses chord with repetition" do
    events = UzuParser.parse("[bd,sd]*2")
    assert length(events) == 4  # 2 chords = 4 events
  end
end
```

## Important Notes

### Parser Architecture

The parser uses a multi-stage approach:

1. **Tokenize** (`tokenize_recursive/3`) - String → tokens with structure
2. **Flatten** (`flatten_structure/1`) - Nested tokens → flat list
3. **Calculate Timings** (`calculate_timings/1`) - Assign time/duration values

**Key insight**: Most features are handled in tokenize, some in calculate_timings

### Timing Model

All times are normalized to 0.0–1.0 representing one "cycle":
- Events scheduled by downstream consumer (KinoSpaetzle, discord_uzu, etc.)
- Parser only responsible for relative timing within cycle

### Pattern Parsing Order

Order matters for features with multiple special characters:
```elixir
# Current precedence (in parse_token/1):
1. Check for `*` (repetition)
2. Check for `:` (sample selection)
3. Treat as simple sound

# Future: will need to extend this for @, !, ?, etc.
```

## Questions for Future Consideration

1. **Polyphony syntax**: Should `"bd,sd"` (no brackets) work, or require `"[bd,sd]"`?
   - TidalCycles uses brackets `[]` or `stack`
   - Decision: Probably require brackets for clarity

2. **Event ordering**: When multiple events have same time, does order matter?
   - Currently: Returned in parse order
   - May need to specify if this is guaranteed behavior

3. **Nested polyphony**: Should `"[bd,[sd,hh]]"` work?
   - Probably yes, naturally falls out of recursive parsing
   - Test this edge case

4. **Performance**: At what pattern complexity should we warn/error?
   - Currently: No limits
   - Future: Maybe add configurable max depth/events?

## Resources & References

- **Project repos**:
  - This repo: https://github.com/rpmessner/uzu_parser
  - KinoHarmony: https://github.com/rpmessner/kino_harmony
  - discord_uzu: https://github.com/rpmessner/discord_uzu

- **Inspiration**:
  - TidalCycles: https://tidalcycles.org/
  - Strudel: https://strudel.cc/
  - Uzu catalog: https://uzu.lurk.org/

- **Docs**:
  - TidalCycles mini-notation: https://tidalcycles.org/docs/reference/mini_notation/
  - Strudel mini-notation: https://strudel.cc/learn/mini-notation/

## Files Modified This Session

```
.github/workflows/ci.yml                                    # Created - CI pipeline
LICENSE                                                     # Modified - Apache → MIT
mix.exs                                                     # Modified - License updated
README.md                                                   # Modified - License, sample selection docs
lib/uzu_parser.ex                                           # Modified - Sample selection parsing
lib/uzu_parser/event.ex                                     # Modified - Added sample field
test/uzu_parser_test.exs                                    # Modified - Added sample selection tests
ROADMAP.md                                                  # Created - Feature roadmap (5 phases)
docs/sessions/2025-01-23-initial-setup-and-sample-selection.md  # Created - This document
docs/NEXT_STEPS.md                                          # Created - Quick reference guide
docs/PERFORMANCE.md                                         # Created - Performance analysis
docs/WAVEFORM_INTEGRATION.md                                # Created - Waveform integration guide
```

## Quick Start for Next Session

**📖 Read first**: `docs/NEXT_STEPS.md` (quick reference guide)

```bash
# Verify everything works
mix deps.get
mix test
mix format --check-formatted
mix compile --warnings-as-errors
mix docs

# All should pass ✅

# Review session context
cat docs/sessions/2025-01-23-*.md          # Full session details
cat docs/NEXT_STEPS.md                      # Action items
cat docs/PERFORMANCE.md                     # Performance guide
cat ROADMAP.md                              # Feature roadmap

# Start implementing polyphony
# 1. Read ROADMAP.md Phase 1
# 2. Add tests in test/uzu_parser_test.exs (describe "polyphony")
# 3. Update parser in lib/uzu_parser.ex
# 4. Run tests iteratively
# 5. Update docs when complete
```

## Performance Analysis & Optimization Strategy

### Current Parser Architecture Performance

The parser uses **recursive pattern matching** on strings rather than a compiled parser generator (yecc/leex).

#### Current Approach (Pattern Matching)

**How it works:**
```elixir
# lib/uzu_parser.ex:134
defp parse_token(token) do
  cond do
    String.contains?(token, "*") -> parse_repetition(token)
    String.contains?(token, ":") -> parse_sample_selection(token)
    true -> {:sound, token, nil}
  end
end
```

**Performance characteristics:**
- Each `String.contains?` scans the entire token
- Multiple passes for tokens with multiple operators
- `String.split` creates new strings on every operation
- Character-by-character recursion in `tokenize_recursive/3`

#### Yecc/Leex Approach (Alternative)

**How it would work:**
```erlang
% Leex lexer (single-pass tokenization)
{sound, "bd"} {colon, ":"} {number, 1} {mult, "*"} {number, 4}

% Yecc grammar (table-driven parsing)
sound_with_sample -> sound colon number : {sound, '$1', '$3'}.
```

**Performance characteristics:**
- Single-pass tokenization
- Compiled state machine (efficient VM bytecode)
- Table-driven LALR parsing
- Zero backtracking for deterministic grammars

#### Benchmarking Estimates

| Pattern | Current (est.) | Yecc (est.) | Speedup |
|---------|---------------|-------------|---------|
| `"bd sd hh"` (simple) | ~5-10μs | ~2-5μs | 2x |
| `"bd:1*4 [sd,hh]"` (complex) | ~15-25μs | ~5-10μs | 2-3x |
| 100-event pattern | ~100-200μs | ~50-100μs | 2x |
| Deeply nested | ~500μs+ | ~100-200μs | 5x+ |

**Real-world impact**: For live coding (parsing 1-10 patterns/second), even worst case (<1ms) is imperceptible to users.

### Critical Performance Issues Identified

#### 🔴 Issue #1: String Concatenation in Loop (lib/uzu_parser.ex:124)

```elixir
# CURRENT - O(n²) behavior!
defp collect_until_bracket_close(<<char::utf8, rest::binary>>, acc) do
  collect_until_bracket_close(rest, acc <> <<char::utf8>>)
end
```

**Problem**: Each iteration creates a new string. For deeply nested patterns, this is quadratic.

**Fix**: Use IO list accumulator pattern:
```elixir
# FIXED - O(n) behavior
defp collect_until_bracket_close("]" <> rest, acc),
  do: {IO.iodata_to_binary(Enum.reverse(acc)), rest}

defp collect_until_bracket_close(<<char::utf8, rest::binary>>, acc) do
  collect_until_bracket_close(rest, [<<char::utf8>> | acc])
end
```

#### 🟡 Issue #2: Multiple String Scans Per Token

As we add more operators (`?`, `@`, `!`, `|`, `<>`, etc.), the `cond` chain grows:

```elixir
cond do
  String.contains?(token, "*") -> ...  # Scan 1
  String.contains?(token, ":") -> ...  # Scan 2
  String.contains?(token, "@") -> ...  # Scan 3
  String.contains?(token, "!") -> ...  # Scan 4
  String.contains?(token, "?") -> ...  # Scan 5
  String.contains?(token, "|") -> ...  # Scan 6
  # 10+ scans per token for full feature set!
end
```

**Problem**: O(n·m) where n = token length, m = number of operators

**Fix**: Single-pass character scanning:
```elixir
defp parse_token(token) do
  token
  |> String.graphemes()
  |> parse_token_chars([], [])
end

defp parse_token_chars([char | rest], sound_acc, modifiers) do
  case char do
    "*" -> parse_token_chars(rest, sound_acc, [:repeat | modifiers])
    ":" -> parse_token_chars(rest, sound_acc, [:sample | modifiers])
    "@" -> parse_token_chars(rest, sound_acc, [:elongate | modifiers])
    "!" -> parse_token_chars(rest, sound_acc, [:replicate | modifiers])
    "?" -> parse_token_chars(rest, sound_acc, [:random | modifiers])
    c -> parse_token_chars(rest, [c | sound_acc], modifiers)
  end
end

defp parse_token_chars([], sound_acc, modifiers) do
  build_token(Enum.reverse(sound_acc), modifiers)
end
```

This scans **once** instead of N times.

### Optimization Roadmap

#### Phase 1: Fix Critical Issues (v0.2.0) ⚠️ HIGH PRIORITY

- **Fix string concatenation** in `collect_until_bracket_close/2` (use IO list)
- **Add benchmark suite** to establish baseline
- **Set performance SLA**: No pattern should take >10ms to parse

#### Phase 2: Optimize Token Parsing (v0.3.0)

- **Single-pass token scanning** instead of multiple `String.contains?` calls
- **Profile with :fprof** to identify other bottlenecks
- **Measure improvement**: Should see 2-3x speedup on complex patterns

#### Phase 3: Consider Yecc/Leex (v1.0.0+)

**Switch to parser generator when:**
- Patterns routinely exceed 100 tokens
- Users report parsing lag (>50ms)
- Adding complex features (conditional logic, variables, functions)
- Grammar becomes ambiguous/context-sensitive

**Current assessment**: Not needed yet. Patterns are small (10-50 tokens), parsing is infrequent (only on user input).

### Benchmarking Plan

```elixir
# test/benchmark.exs (to be created)
Benchee.run(%{
  "simple" => fn -> UzuParser.parse("bd sd hh sd") end,
  "complex" => fn -> UzuParser.parse("bd:1*4 [sd:0,hh:2] cp") end,
  "nested" => fn -> UzuParser.parse("[bd [sd [hh [cp oh]]]]") end,
  "wide" => fn -> UzuParser.parse(String.duplicate("bd ", 100)) end,
})
```

**Success criteria**:
- Simple: <10μs
- Complex: <50μs
- Nested: <100μs
- Wide (100 events): <500μs

**If exceeded**: Implement Phase 2 optimizations.

### Why Not Yecc Now?

**Current approach is appropriate because:**

1. **Patterns are small** - 10-50 tokens typical in live coding
2. **Parsing is infrequent** - Only when user types/changes pattern (not per-frame)
3. **Simplicity matters** - Easy to understand, easy to extend, easy to debug
4. **Real bottleneck is elsewhere** - Audio I/O, sample loading, scheduling are the hot paths

**Premature optimization threshold**: Only optimize when parsing takes >10ms.

### Action Items

- [ ] Fix string concatenation bug (Issue #1)
- [ ] Add `test/benchmark.exs` with Benchee
- [ ] Run benchmarks to establish baseline
- [ ] Document performance budget in README
- [ ] Add CI step to detect performance regressions
- [ ] Re-evaluate after implementing Phase 1 operators (`,`, `@`, `!`, `?`)

### References

- Elixir Efficiency Guide: https://www.erlang.org/doc/efficiency_guide/
- Benchee: https://github.com/bencheeorg/benchee
- Yecc: https://www.erlang.org/doc/man/yecc.html
- Leex: https://www.erlang.org/doc/man/leex.html

---

## Session Metrics

- **Duration**: ~2.5 hours
- **Files created**: 6 (CI workflow, ROADMAP, 4 docs)
- **Files modified**: 6 (LICENSE, mix.exs, README, parser, event, tests)
- **Tests added**: 7
- **Tests total**: 30
- **Lines of code added**: ~200
- **Lines of documentation added**: ~1400
- **Features completed**: 2 (CI + sample selection)
- **Features researched & planned**: 15+
- **Performance issues identified**: 2 (1 critical, 1 future)
- **Integration validation**: Waveform compatibility confirmed
- **Documentation artifacts created**:
  - Session notes (this file)
  - Quick reference guide (NEXT_STEPS.md)
  - Performance analysis (PERFORMANCE.md)
  - Feature roadmap (ROADMAP.md)
  - Waveform integration guide (WAVEFORM_INTEGRATION.md)
