# Performance Analysis & Optimization Guide

**Last Updated**: 2025-01-23
**Current Version**: v0.1.0
**Performance Budget**: <10ms per pattern parse

## Current Performance Characteristics

### Parser Architecture

UzuParser uses **hand-written recursive pattern matching** rather than a parser generator (yecc/leex).

**Rationale**:
- Patterns are small (10-50 tokens typical)
- Parsing is infrequent (only on user input, not per-frame)
- Simplicity aids development and debugging
- Real bottlenecks are in audio I/O and scheduling, not parsing

### Estimated Performance (v0.1.0)

| Pattern Type | Est. Time | Example |
|-------------|-----------|---------|
| Simple (4 events) | ~5-10μs | `"bd sd hh sd"` |
| Complex (6+ events) | ~15-25μs | `"bd:1*4 [sd:0,hh:2] cp"` |
| Deeply nested | ~500μs+ | `"[bd [sd [hh [cp oh]]]]"` |
| Wide (100 events) | ~100-200μs | `String.duplicate("bd ", 100)` |

**Status**: No benchmarks yet. Estimates based on code analysis.

## Critical Performance Issues

### 🔴 CRITICAL: String Concatenation in Loop

**Location**: `lib/uzu_parser.ex:124` (`collect_until_bracket_close/2`)

**Current code**:
```elixir
defp collect_until_bracket_close(<<char::utf8, rest::binary>>, acc) do
  collect_until_bracket_close(rest, acc <> <<char::utf8>>)
end
```

**Problem**: O(n²) complexity. Each iteration creates a new binary.

**Impact**: Deeply nested patterns (e.g., `"[bd [sd [hh [cp [oh]]]]]"`) will be slow.

**Fix**: Use IO list pattern
```elixir
defp collect_until_bracket_close("]" <> rest, acc),
  do: {IO.iodata_to_binary(Enum.reverse(acc)), rest}

defp collect_until_bracket_close(<<char::utf8, rest::binary>>, acc) do
  collect_until_bracket_close(rest, [<<char::utf8>> | acc])
end
```

**Priority**: HIGH - Fix in v0.2.0

### 🟡 FUTURE: Multiple String Scans Per Token

**Location**: `lib/uzu_parser.ex:134` (`parse_token/1`)

**Current code**:
```elixir
defp parse_token(token) do
  cond do
    String.contains?(token, "*") -> parse_repetition(token)
    String.contains?(token, ":") -> parse_sample_selection(token)
    true -> {:sound, token, nil}
  end
end
```

**Problem**: As we add operators (`?`, `@`, `!`, `|`), each token gets scanned N times.

**Current impact**: LOW (only 2 operators)

**Future impact**: MEDIUM (10+ operators planned)

**Fix**: Single-pass character scanner (see Optimization Roadmap)

**Priority**: MEDIUM - Optimize in v0.3.0 after adding Phase 1 operators

## Optimization Roadmap

### Phase 1: Fix Critical Issues (v0.2.0) ⚠️

**Goals**:
- Fix string concatenation bug
- Establish performance baseline
- Set performance budget

**Tasks**:
- [ ] Replace string concatenation with IO list in `collect_until_bracket_close/2`
- [ ] Add Benchee dependency
- [ ] Create `test/benchmark.exs` with representative patterns
- [ ] Run benchmarks and document baseline
- [ ] Add performance test to CI (fail if >10ms)

**Expected improvement**: 2-5x on deeply nested patterns

### Phase 2: Single-Pass Token Parsing (v0.3.0)

**Goals**:
- Eliminate multiple string scans per token
- Optimize for 10+ operators

**Implementation strategy**:
```elixir
defp parse_token(token) do
  token
  |> String.graphemes()
  |> scan_token_chars([], [])
end

defp scan_token_chars(["*" | rest], sound_acc, mods),
  do: scan_token_chars(rest, sound_acc, [:repeat | mods])

defp scan_token_chars([":" | rest], sound_acc, mods),
  do: scan_token_chars(rest, sound_acc, [:sample | mods])

defp scan_token_chars(["@" | rest], sound_acc, mods),
  do: scan_token_chars(rest, sound_acc, [:elongate | mods])

# ... handle other operators

defp scan_token_chars([char | rest], sound_acc, mods),
  do: scan_token_chars(rest, [char | sound_acc], mods)

defp scan_token_chars([], sound_acc, mods),
  do: build_token(Enum.reverse(sound_acc), mods)
```

**Expected improvement**: 2-3x on complex tokens

### Phase 3: Parser Generator Evaluation (v1.0.0+)

**Consider switching to yecc/leex when**:
- Patterns routinely exceed 100 tokens
- Parsing takes >50ms for typical patterns
- Grammar becomes ambiguous or context-sensitive
- Adding complex features (variables, conditionals, functions)

**Estimated yecc/leex performance**:
- Simple: ~2-5μs (2x faster)
- Complex: ~5-10μs (2-3x faster)
- Deeply nested: ~100-200μs (5x faster)

**Trade-offs**:
- ✅ Faster parsing (2-5x)
- ✅ Formally verified grammar
- ✅ Better error messages possible
- ❌ More complex build process
- ❌ Harder to understand/debug
- ❌ Less flexibility for experimental features

## Benchmarking

### Setup

```elixir
# mix.exs
defp deps do
  [
    {:benchee, "~> 1.3", only: :dev}
  ]
end
```

### Benchmark Suite

```elixir
# test/benchmark.exs
patterns = %{
  "simple_4" => "bd sd hh sd",
  "sample_select" => "bd:0 sd:1 hh:2 cp:3",
  "repetition" => "bd*4 sd*2 hh*8",
  "subdivision" => "bd [sd sd] hh [cp cp cp]",
  "complex" => "bd:1*4 [sd:0,hh:2] cp",
  "nested_3" => "[bd [sd [hh]]]",
  "nested_5" => "[bd [sd [hh [cp [oh]]]]]",
  "wide_10" => String.duplicate("bd ", 10) |> String.trim(),
  "wide_100" => String.duplicate("bd ", 100) |> String.trim(),
}

Benchee.run(
  %{
    "parse" => fn pattern -> UzuParser.parse(pattern) end
  },
  inputs: patterns,
  time: 5,
  memory_time: 2
)
```

### Running Benchmarks

```bash
# Run full suite
mix run test/benchmark.exs

# Run with profiling
mix run test/benchmark.exs --profile

# Compare against baseline
mix run test/benchmark.exs --save-baseline
```

### Success Criteria

| Pattern Type | Target | Max Acceptable |
|-------------|--------|----------------|
| Simple (≤10 events) | <10μs | <50μs |
| Complex (≤50 events) | <50μs | <500μs |
| Nested (depth ≤5) | <100μs | <1ms |
| Wide (≤100 events) | <500μs | <5ms |

**Red flag**: Any pattern taking >10ms requires immediate optimization.

## Performance Testing in CI

```yaml
# .github/workflows/performance.yml
name: Performance Tests

on:
  pull_request:
    branches: [ main ]

jobs:
  benchmark:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.18.0'
          otp-version: '27.0'

      - name: Install dependencies
        run: mix deps.get

      - name: Run benchmarks
        run: mix run test/benchmark.exs

      - name: Check performance budget
        run: |
          # Fail if any pattern takes >10ms
          # TODO: Parse benchee output and fail on threshold
```

## Profiling

### CPU Profiling with :fprof

```elixir
# Profile a specific pattern
:fprof.trace([:start])
UzuParser.parse("bd [sd [hh [cp [oh]]]]")
:fprof.trace([:stop])
:fprof.profile()
:fprof.analyse([:totals, {:sort, :acc}])
```

### Memory Profiling with :eprof

```elixir
:eprof.start()
:eprof.start_profiling([self()])
UzuParser.parse("bd [sd [hh [cp [oh]]]]")
:eprof.stop_profiling()
:eprof.analyze()
```

### Flame Graph Generation

```bash
# Install dependencies
mix escript.install hex flame_graph

# Generate flame graph
mix profile.fprof --callers --flame-graph
```

## Optimization Techniques

### 1. IO Lists Instead of String Concatenation

**Bad**:
```elixir
acc <> new_string  # Creates new binary each time
```

**Good**:
```elixir
[new_string | acc]  # Just adds to list
# Later: IO.iodata_to_binary(Enum.reverse(acc))
```

### 2. Binary Pattern Matching

**Bad**:
```elixir
String.slice(str, 0, 1)
```

**Good**:
```elixir
<<first::utf8, rest::binary>> = str
```

### 3. Avoid Repeated String Scans

**Bad**:
```elixir
cond do
  String.contains?(s, "a") -> ...
  String.contains?(s, "b") -> ...  # Scans again!
end
```

**Good**:
```elixir
# Single pass through string
String.graphemes(s) |> scan_chars()
```

### 4. Use Guards for Simple Checks

**Bad**:
```elixir
def parse(x) do
  if is_binary(x), do: ...
end
```

**Good**:
```elixir
def parse(x) when is_binary(x), do: ...
```

## References

- [Elixir Efficiency Guide](https://www.erlang.org/doc/efficiency_guide/)
- [Benchee Documentation](https://hexdocs.pm/benchee/)
- [Erlang Profiling](https://www.erlang.org/doc/apps/tools/fprof_chapter.html)
- [Flame Graphs](http://www.brendangregg.com/flamegraphs.html)

## Changelog

### 2025-01-23 - Initial Analysis
- Identified string concatenation bug in `collect_until_bracket_close/2`
- Identified future performance issue with multiple string scans
- Established optimization roadmap
- Defined performance budget (<10ms per parse)
