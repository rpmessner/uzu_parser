# Next Steps - Quick Reference

**Last Updated**: 2025-11-25
**Current Version**: v0.3.0
**Next Version**: v0.4.0

## 🎯 Immediate Priorities (v0.4.0 - Advanced Rhythms)

### 1. Euclidean Rhythms `()` - HIGH PRIORITY

**Syntax**: `"bd(3,8)"` - 3 hits distributed over 8 steps

```elixir
"bd(3,8)"        # 3 hits distributed over 8 steps
"bd(3,8,2)"      # 3 hits over 8 steps, offset by 2
"bd(5,12)"       # complex polyrhythm
```

**Implementation approach**:
1. Parse `(k,n)` or `(k,n,offset)` syntax after sound token
2. Use Bjorklund's algorithm to distribute k hits over n steps
3. Return `{:euclidean, sound, k, n, offset}` token
4. In `flatten_token/1`, expand to individual events

**Use case**: World music rhythms, polyrhythms, generative patterns

**Estimated effort**: 3-4 hours

### 2. Division `/` - MEDIUM PRIORITY

**Syntax**: `"bd/2"` - play every other cycle

```elixir
"bd/2"           # play every other cycle
"[bd sd]/4"      # pattern over 4 cycles
```

**Implementation approach**:
1. Parse `/n` after sound/subdivision
2. Store division factor in event params
3. Playback system uses cycle number to decide if event plays

**Use case**: Slow-evolving patterns, ambient textures

**Estimated effort**: 2 hours

### 3. Polymetric Sequences `{}` - LOWER PRIORITY

**Syntax**: `"{bd sd hh, cp}"` - different step counts

```elixir
"{bd sd hh, cp}"  # 3 steps vs 1 step
"{bd sd, hh cp oh}" # 2 steps vs 3 steps
```

**Implementation approach**:
1. Parse curly braces with comma-separated groups
2. Each group has independent step count
3. Store as `{:polymetric, [groups]}` with separate timing

**Use case**: Polyrhythms, complex time signatures

**Estimated effort**: 4-5 hours

## 📋 Phase 5: Pattern Transformations (v0.5.0)

Priority: **HIGH** - Core pattern manipulation for kino_harmony integration

### Temporal Transformations
```elixir
UzuParser.fast(events, 2.0)    # Speed up by factor (compress time)
UzuParser.slow(events, 2.0)    # Slow down by factor (expand time)
UzuParser.rev(events)          # Reverse pattern order and timing
```

### Pattern Combinators
```elixir
UzuParser.stack([pattern1, pattern2])  # Play simultaneously (merge events)
UzuParser.cat([pattern1, pattern2])    # Play sequentially (offset timing)
```

### Conditional Transformations
```elixir
UzuParser.every(events, 3, &UzuParser.rev/1)  # Apply every N cycles
```

### Parameterized Transformations
```elixir
UzuParser.jux(events, &UzuParser.rev/1)   # Left: original, Right: transformed
UzuParser.degrade_by(events, 0.5)         # Randomly remove ~50% of events
```

## 🗂️ Documentation to Update

When implementing each feature:

1. **lib/uzu_parser.ex** - Module docs with examples
2. **README.md** - Syntax section with examples
3. **ROADMAP.md** - Move from "Phase N" to "Implemented"
4. **CHANGELOG.md** - Add entry for version
5. **test/uzu_parser_test.exs** - Comprehensive test coverage

## 🚀 Quick Start Commands

```bash
# Verify current state
mix test                           # 84 tests should pass
mix format --check-formatted       # Should pass
mix compile --warnings-as-errors   # Should pass
mix docs                          # Should generate

# Start new feature
git checkout -b feature/euclidean-rhythms

# After implementing
mix test                          # All tests pass
mix format                        # Format code
git add .
git commit -m "Add euclidean rhythm support"
```

## 📚 Key Documentation

- **ROADMAP.md** - Full feature roadmap
- **docs/PERFORMANCE.md** - Performance analysis and optimization guide
- **README.md** - User-facing documentation

## 🎓 Implementation Tips

### Parser Architecture (3-stage process)

1. **Tokenize** (`tokenize_recursive/3`)
   - String → structured tokens
   - Handle brackets, angle brackets, and special syntax

2. **Flatten** (`flatten_structure/1`)
   - Nested tokens → flat list
   - Handle subdivisions, repetitions, euclidean expansion

3. **Calculate Timings** (`calculate_timings/1`)
   - Assign time/duration values
   - Returns Event structs

### Adding a New Operator

1. Parse in `parse_token/1` or `tokenize_recursive/3`
2. Create new token type if needed
3. Handle in `flatten_token/1` if structural
4. Handle in `calculate_weighted_timings/1` if timing-related
5. Add comprehensive tests
6. Update documentation

## 📊 Success Metrics

After implementing v0.4.0 features:

- [ ] All tests passing (expect 95+ tests)
- [ ] No compilation warnings
- [ ] Code formatted
- [ ] Documentation updated
- [ ] Euclidean rhythms working correctly

## 🎯 Vision

**v0.1.0**: Basic sequences, rests, subdivisions, repetition, sample selection

**v0.2.0**: + polyphony, random removal, elongation, replication, performance fixes

**v0.3.0** (Current): + random choice, alternation

**v0.4.0** (Next): + Euclidean rhythms, division, polymetric sequences

**v0.5.0**: + pattern transformations (fast, slow, rev, stack, cat, every, jux)

**v0.6.0**: + sound parameters (gain, speed, pan, etc.)

**v1.0.0**: Complete feature parity with TidalCycles mini-notation
