# Next Steps - Quick Reference

**Last Updated**: 2025-01-23
**Current Version**: v0.1.0
**Next Version**: v0.2.0

## 🎯 Immediate Priorities (v0.2.0)

### 1. Fix Critical Performance Bug ⚠️ HIGH PRIORITY

**Issue**: String concatenation in `collect_until_bracket_close/2` (lib/uzu_parser.ex:124)

**Fix**:
```elixir
# Replace this:
defp collect_until_bracket_close(<<char::utf8, rest::binary>>, acc) do
  collect_until_bracket_close(rest, acc <> <<char::utf8>>)
end

# With this:
defp collect_until_bracket_close("]" <> rest, acc),
  do: {IO.iodata_to_binary(Enum.reverse(acc)), rest}

defp collect_until_bracket_close(<<char::utf8, rest::binary>>, acc) do
  collect_until_bracket_close(rest, [<<char::utf8>> | acc])
end

# Update initial call to pass empty list instead of empty string
```

**Why**: Current code has O(n²) complexity for nested patterns.

**Estimated effort**: 30 minutes

### 2. Add Benchmarking Suite

**Add to mix.exs**:
```elixir
{:benchee, "~> 1.3", only: :dev}
```

**Create test/benchmark.exs** (see docs/PERFORMANCE.md for full code)

**Run**:
```bash
mix deps.get
mix run test/benchmark.exs
```

**Estimated effort**: 1 hour

### 3. Implement Polyphony `,` (Phase 1 - Highest Impact Feature)

**Syntax**: `"[bd,sd,hh]"` - play multiple sounds at same time

**Implementation guide**: See docs/sessions/2025-01-23-*.md section "Implementation Guide for Next Feature: Polyphony"

**Key changes needed**:
- Add `{:chord, [...]}` token type
- Parse `,` within subdivisions
- In `calculate_timings/1`, chord → multiple events at same time
- Handle edge cases: `"bd,sd"` (no brackets?), `"[bd:0,sd:1]"`, `"[bd,sd]*2"`

**Tests to add**: ~6 test cases (see session docs)

**Estimated effort**: 3-4 hours

## 📋 Phase 1 Features (v0.2.0)

After polyphony, implement in order:

1. **Random Removal `?`** - `"bd?"` (50% probability)
   - Effort: 2-3 hours
   - Impact: HIGH (adds variation)

2. **Elongation `@`** - `"bd@2 sd"` (relative duration)
   - Effort: 2 hours
   - Impact: HIGH (rhythm shaping)

3. **Replication `!`** - `"bd!3"` (repeat without acceleration)
   - Effort: 1-2 hours
   - Impact: MEDIUM

## 🗂️ Documentation to Update

When implementing each feature:

1. **lib/uzu_parser.ex** - Module docs with examples
2. **README.md** - Syntax section with examples
3. **ROADMAP.md** - Move from "Phase N" to "Implemented"
4. **CHANGELOG.md** - Add entry for version
5. **test/uzu_parser_test.exs** - Comprehensive test coverage
6. **docs/sessions/** - Create new session doc when complete

## 🚀 Quick Start Commands

```bash
# Verify current state
mix test                           # 30 tests should pass
mix format --check-formatted       # Should pass
mix compile --warnings-as-errors   # Should pass
mix docs                          # Should generate

# Start new feature
git checkout -b feature/polyphony

# After implementing
mix test                          # All tests pass
mix format                        # Format code
git add .
git commit -m "Add polyphony support"

# Optional: benchmark
mix run test/benchmark.exs
```

## 📚 Key Documentation

- **ROADMAP.md** - Full feature roadmap (5 phases)
- **docs/PERFORMANCE.md** - Performance analysis and optimization guide
- **docs/sessions/2025-01-23-*.md** - This session's detailed notes
- **README.md** - User-facing documentation

## 🤔 Open Questions

1. **Polyphony without brackets**: Should `"bd,sd"` work or require `"[bd,sd]"`?
   - Recommendation: Require brackets for clarity
   - Matches TidalCycles behavior

2. **Nested polyphony**: Should `"[bd,[sd,hh]]"` work?
   - Recommendation: Yes, naturally falls out of recursive parsing
   - Add test case for this

3. **Event ordering**: When multiple events have same time, is order guaranteed?
   - Current: Events returned in parse order
   - Recommendation: Document this as guaranteed behavior

## 🎓 Learning Resources

If you're new to the codebase:

1. Read **README.md** - Understand the syntax
2. Read **test/uzu_parser_test.exs** - See examples
3. Read **lib/uzu_parser.ex** - Understand parser flow
4. Read **docs/sessions/2025-01-23-*.md** - Full context

## 💡 Implementation Tips

### Parser Architecture (3-stage process)

1. **Tokenize** (`tokenize_recursive/3`)
   - String → structured tokens
   - Most features handled here

2. **Flatten** (`flatten_structure/1`)
   - Nested tokens → flat list
   - Handles subdivisions, repetitions

3. **Calculate Timings** (`calculate_timings/1`)
   - Assign time/duration values
   - Returns Event structs

### Adding a New Operator

1. Parse in `parse_token/1` or `tokenize_recursive/3`
2. Create new token type if needed
3. Handle in `flatten_token/1` if structural
4. Handle in `calculate_timings/1` if timing-related
5. Add comprehensive tests
6. Update documentation

### Testing Strategy

- **Unit tests** - Each operator in isolation
- **Integration tests** - Operators combined
- **Edge cases** - Invalid input, extreme values
- **Regression tests** - Don't break existing features

## 🐛 Known Issues

1. **String concatenation bug** (HIGH PRIORITY)
   - Location: lib/uzu_parser.ex:124
   - Status: Identified, fix ready
   - ETA: Fix in v0.2.0

2. **No performance benchmarks** (MEDIUM PRIORITY)
   - Status: Benchmark suite designed
   - ETA: Add in v0.2.0

## 📊 Success Metrics

After implementing v0.2.0 features:

- [ ] All tests passing (expect 40+ tests)
- [ ] No compilation warnings
- [ ] Code formatted
- [ ] Documentation updated
- [ ] Benchmarks show <10ms for typical patterns
- [ ] Performance bug fixed (nested patterns fast)

## 🎯 Vision

**v0.1.0** (Current): Basic sequences, rests, subdivisions, repetition, sample selection

**v0.2.0** (Next): + polyphony, random removal, elongation, replication, performance fixes

**v0.3.0**: + random choice, alternation, pattern selection

**v0.4.0**: + Euclidean rhythms, division, polymetric sequences

**v0.5.0**: + sound parameters (gain, speed, pan, etc.)

**v1.0.0**: Complete feature parity with TidalCycles mini-notation
