# Waveform Integration Design

**Last Updated**: 2025-01-23
**Waveform Version**: v0.3.0
**UzuParser Version**: v0.1.0

## Overview

UzuParser is designed to integrate seamlessly with [Waveform](https://github.com/rpmessner/waveform), an Elixir OSC transport layer for SuperCollider/SuperDirt.

UzuParser was **extracted from KinoSpaetzle** to be a standalone, reusable parser. This separation allows:
- **UzuParser**: Focus on parsing mini-notation → structured events
- **KinoSpaetzle**: Focus on Livebook UI, pattern management, visualization
- **Waveform**: Focus on audio scheduling, OSC transport, SuperDirt integration

**Integration Flow**:
```
Mini-notation → UzuParser → Events → PatternScheduler → SuperDirt → Audio
     ↑
KinoSpaetzle uses UzuParser for parsing
```

**Architecture**:
```
┌──────────────────────────────────────┐
│  KinoSpaetzle (Livebook UI)          │
│  - Pattern editor                    │
│  - Visualization                     │
│  - Pattern management                │
└──────────┬───────────────────────────┘
           │
           │ uses
           ↓
┌──────────────────────────────────────┐
│  UzuParser (This Library)            │
│  - Parse mini-notation               │
│  - Generate Event structs            │
│  - Convert to PatternScheduler format│
└──────────┬───────────────────────────┘
           │
           │ {cycle_position, params}
           ↓
┌──────────────────────────────────────┐
│  Waveform.PatternScheduler           │
│  - High-precision scheduling         │
│  - Look-ahead timing                 │
│  - Hot-swappable patterns            │
└──────────┬───────────────────────────┘
           │
           │ SuperDirt.play(params)
           ↓
┌──────────────────────────────────────┐
│  Waveform.SuperDirt                  │
│  - OSC bundles with timestamps       │
│  - Parameter formatting              │
└──────────┬───────────────────────────┘
           │
           │ OSC → port 57120
           ↓
┌──────────────────────────────────────┐
│  SuperDirt (SuperCollider)           │
│  - Sample playback                   │
│  - Effects processing                │
│  - Audio output                      │
└──────────────────────────────────────┘
```

## Waveform Architecture

### PatternScheduler

The `Waveform.PatternScheduler` is the orchestration layer that:
- Manages continuous pattern playback with cycle-based timing
- Schedules events with high-precision look-ahead
- Supports hot-swapping patterns while playing
- Handles tempo changes on the fly

**Expected Event Format**:
```elixir
[
  {cycle_position, params},  # tuple of {float, keyword_list}
  ...
]
```

Where:
- `cycle_position` - Float from 0.0 to 1.0 (position within one cycle)
- `params` - Keyword list for SuperDirt (e.g., `[s: "bd", n: 0, gain: 0.8]`)

### SuperDirt Parameters

SuperDirt receives OSC messages with parameters:

**Required (automatically added by Waveform)**:
- `cps` - Cycles per second (tempo)
- `cycle` - Event position since startup
- `delta` - Event duration in seconds
- `orbit` - Orbit/track number (0-11)

**Sound Selection**:
- `s` - Sample/sound name (e.g., "bd", "cp", "sn") **[MAPS TO Event.sound]**
- `n` - Sample variant number (default: 0) **[MAPS TO Event.sample]**

**Sound Parameters**:
- `speed` - Playback speed (default: 1.0)
- `gain` - Volume (default: 1.0)
- `pan` - Stereo position (-1.0 to 1.0)
- `begin` - Sample start position (0.0 to 1.0)
- `end` - Sample end position (0.0 to 1.0)

**Effects Parameters**:
- `room` - Reverb amount
- `size` - Reverb size
- `delay` - Delay amount
- `delaytime` - Delay time
- `delayfeedback` - Delay feedback
- `cutoff` - Filter cutoff frequency
- `resonance` - Filter resonance

## UzuParser Event Structure

### Current Design (v0.1.0)

```elixir
defmodule UzuParser.Event do
  defstruct sound: "",        # Maps to SuperDirt 's' parameter
            sample: nil,      # Maps to SuperDirt 'n' parameter
            time: 0.0,        # Maps to PatternScheduler cycle_position
            duration: 1.0,    # Can map to 'delta' or be used for legato
            params: %{}       # Maps to additional SuperDirt parameters
end
```

### Design Validation ✅

The current Event structure is **perfectly designed** for Waveform integration:

| Event Field | SuperDirt Parameter | PatternScheduler Use |
|-------------|---------------------|----------------------|
| `sound` | `s` | Required sound name |
| `sample` | `n` | Sample variant (0, 1, 2, ...) |
| `time` | - | `cycle_position` in tuple |
| `duration` | `delta` or custom | Event length |
| `params` | All others | Effects, modulation, etc. |

**Example mapping**:
```elixir
# UzuParser output
event = %Event{
  sound: "bd",
  sample: 1,
  time: 0.25,
  duration: 0.25,
  params: %{gain: 0.8, pan: 0.5}
}

# Converts to PatternScheduler format
{0.25, [s: "bd", n: 1, gain: 0.8, pan: 0.5]}
```

## Integration Helpers

### Converting Events to PatternScheduler Format

Add to `UzuParser` module:

```elixir
@doc """
Convert parsed events to Waveform.PatternScheduler format.

Returns a list of {cycle_position, params} tuples ready for scheduling.

## Examples

    iex> events = UzuParser.parse("bd:1 sd:0 hh:2")
    iex> UzuParser.to_pattern(events)
    [
      {0.0, [s: "bd", n: 1]},
      {0.333, [s: "sd", n: 0]},
      {0.666, [s: "hh", n: 2]}
    ]

"""
def to_pattern(events) when is_list(events) do
  Enum.map(events, &event_to_tuple/1)
end

defp event_to_tuple(%Event{sound: sound, sample: sample, time: time, params: params}) do
  # Build base params
  base_params = [s: sound]

  # Add sample number if specified
  base_params = if sample, do: base_params ++ [n: sample], else: base_params

  # Add custom params
  custom_params = Enum.map(params, fn {k, v} -> {k, v} end)

  {time, base_params ++ custom_params}
end
```

### Helper for Direct Waveform Usage

```elixir
@doc """
Parse mini-notation and schedule it on Waveform.PatternScheduler.

## Examples

    iex> UzuParser.schedule("bd sd hh sd", :drums)
    :ok

    iex> UzuParser.schedule("bd:1*4", :kick, cps: 0.75)
    :ok

"""
def schedule(pattern_string, pattern_id, opts \\ []) do
  events =
    pattern_string
    |> parse()
    |> to_pattern()

  Waveform.PatternScheduler.schedule_pattern(pattern_id, events)

  # Set CPS if provided
  if cps = opts[:cps] do
    Waveform.PatternScheduler.set_cps(cps)
  end

  :ok
end
```

## Parameter Design Strategy

### Phase 1: Current Parameters (v0.1.0) ✅

Already implemented:
- Sound selection: `s` via `sound` field
- Sample selection: `n` via `sample` field
- Custom params: Any params via `params` map

### Phase 2: Basic Sound Parameters (v0.2.0-v0.3.0)

When implementing parameters (Phase 4 in ROADMAP.md), map to SuperDirt:

**Syntax**: `"bd|gain:0.8|speed:2"`

```elixir
# Parse result
%Event{
  sound: "bd",
  sample: nil,
  time: 0.0,
  duration: 0.25,
  params: %{gain: 0.8, speed: 2.0}
}

# Converts to
{0.0, [s: "bd", gain: 0.8, speed: 2.0]}
```

**Recommended parameter mappings**:
- `gain` → SuperDirt `gain` (volume control)
- `speed` → SuperDirt `speed` (playback speed/pitch)
- `pan` → SuperDirt `pan` (stereo position)
- `cutoff` → SuperDirt `cutoff` (filter cutoff)
- `resonance` → SuperDirt `resonance` (filter resonance)
- `room` → SuperDirt `room` (reverb amount)
- `size` → SuperDirt `size` (reverb size)
- `delay` → SuperDirt `delay` (delay amount)

### Phase 3: Advanced Parameters (v0.5.0+)

**Envelope control**:
- `attack`, `decay`, `sustain`, `release` → SuperDirt envelope params

**Temporal control**:
- `begin`, `end` → SuperDirt sample slice params
- `loop` → SuperDirt loop param

**Modulation**:
- `vowel` → SuperDirt vowel formant
- `cutoffegint` → Filter envelope intensity
- And many more from SuperDirt documentation

## Usage Examples

### Example 1: Simple Drum Pattern

```elixir
# Parse pattern
events = UzuParser.parse("bd sd hh sd")

# Convert to pattern format
pattern = UzuParser.to_pattern(events)
# => [
#   {0.0, [s: "bd"]},
#   {0.25, [s: "sd"]},
#   {0.5, [s: "hh"]},
#   {0.75, [s: "sd"]}
# ]

# Schedule on Waveform
Waveform.PatternScheduler.schedule_pattern(:drums, pattern)
```

### Example 2: Sample Selection

```elixir
# Different kick drum samples
events = UzuParser.parse("bd:0 bd:1 bd:2 bd:3")
pattern = UzuParser.to_pattern(events)

# => [
#   {0.0, [s: "bd", n: 0]},
#   {0.25, [s: "bd", n: 1]},
#   {0.5, [s: "bd", n: 2]},
#   {0.75, [s: "bd", n: 3]}
# ]

Waveform.PatternScheduler.schedule_pattern(:kick_variants, pattern)
```

### Example 3: With Parameters (Future)

```elixir
# When parameter syntax is implemented
events = UzuParser.parse("bd|gain:1.2 sd|pan:-0.5 hh|speed:2")
pattern = UzuParser.to_pattern(events)

# => [
#   {0.0, [s: "bd", gain: 1.2]},
#   {0.333, [s: "sd", pan: -0.5]},
#   {0.666, [s: "hh", speed: 2.0]}
# ]

Waveform.PatternScheduler.schedule_pattern(:drums, pattern)
```

### Example 4: Live Coding in Livebook

```elixir
# Cell 1: Setup
Mix.install([
  {:waveform, "~> 0.3.0"},
  {:uzu_parser, "~> 0.1.0"}
])

alias Waveform.{PatternScheduler, SuperDirt}
alias UzuParser

# Start SuperDirt
Waveform.Lang.send_command("SuperDirt.start;")

# Cell 2: Define pattern
pattern = """
bd*4 ~ [sd sd] ~
"""

events = UzuParser.parse(pattern)
UzuParser.to_pattern(events)
|> then(&PatternScheduler.schedule_pattern(:drums, &1))

# Cell 3: Change pattern (hot-swap)
new_pattern = "bd:1 bd:2 sd:0 cp"

UzuParser.parse(new_pattern)
|> UzuParser.to_pattern()
|> then(&PatternScheduler.update_pattern(:drums, &1))

# Cell 4: Add hi-hats
hats = "[hh hh hh hh] [hh hh hh hh]"

UzuParser.parse(hats)
|> UzuParser.to_pattern()
|> then(&PatternScheduler.schedule_pattern(:hats, &1))
```

## Design Decisions

### 1. Why `params` is a Map

**Decision**: Event.params is a `map()` not a keyword list

**Rationale**:
- More flexible for internal use
- Easy to merge/update
- Convert to keyword list at integration boundary
- Allows duplicate keys if needed in future

### 2. Why `sample: nil` vs `sample: 0`

**Decision**: nil means "use default", 0 means "explicitly use sample 0"

**Rationale**:
- Allows downstream to distinguish intent
- Most patterns don't specify sample number
- `nil` is more idiomatic Elixir than magic number `-1`

**Impact on Waveform integration**:
```elixir
# nil → omit 'n' parameter (SuperDirt default)
{0.0, [s: "bd"]}

# 0 → explicit n: 0
{0.0, [s: "bd", n: 0]}
```

### 3. Duration Field Usage

**Decision**: Keep `duration` field even though SuperDirt doesn't directly use it

**Rationale**:
- Useful for visualizations (Livebook charts, etc.)
- Could map to `delta` parameter for some synths
- Future: legato vs staccato playback
- Minimal cost to include

### 4. Time Normalization (0.0 to 1.0)

**Decision**: Keep cycle-relative timing (not absolute seconds)

**Rationale**:
- Matches PatternScheduler's cycle-based model
- Tempo-independent patterns
- Easy to reason about (quarter of cycle = 0.25)
- Aligns with TidalCycles/Strudel conventions

## Integration Testing

### Test Compatibility

```elixir
# test/integration/waveform_integration_test.exs
defmodule UzuParser.WaveformIntegrationTest do
  use ExUnit.Case

  describe "to_pattern/1" do
    test "converts simple pattern to Waveform format" do
      events = UzuParser.parse("bd sd hh")
      pattern = UzuParser.to_pattern(events)

      assert [
        {0.0, [s: "bd"]},
        {_, [s: "sd"]},
        {_, [s: "hh"]}
      ] = pattern
    end

    test "includes sample numbers when specified" do
      events = UzuParser.parse("bd:1 sd:0")
      [{_, params1}, {_, params2}] = UzuParser.to_pattern(events)

      assert params1[:s] == "bd"
      assert params1[:n] == 1
      assert params2[:s] == "sd"
      assert params2[:n] == 0
    end

    test "omits sample number when nil" do
      events = UzuParser.parse("bd sd")
      [{_, params1}, {_, params2}] = UzuParser.to_pattern(events)

      assert params1[:s] == "bd"
      refute Keyword.has_key?(params1, :n)
    end
  end
end
```

## Future Enhancements

### 1. Direct Waveform Dependency (Optional)

Consider making Waveform an optional dependency:

```elixir
# mix.exs
{:waveform, "~> 0.3.0", optional: true}
```

Then provide helpers only when Waveform is available:

```elixir
if Code.ensure_loaded?(Waveform.PatternScheduler) do
  def schedule(pattern_string, pattern_id, opts \\ []) do
    # ... implementation
  end
end
```

### 2. KinoSpaetzle Integration

[KinoSpaetzle](https://github.com/rpmessner/kino_spaetzle) is a Livebook live coding environment that uses both UzuParser and Waveform.

**Current architecture** (speculated):
```
KinoSpaetzle
    ↓ (has own parser)
Waveform.PatternScheduler
    ↓
SuperDirt
```

**Future architecture** (recommended):
```
KinoSpaetzle
    ↓ (uses UzuParser)
UzuParser
    ↓ (to_pattern helper)
Waveform.PatternScheduler
    ↓
SuperDirt
```

**Benefits**:
- Shared parser logic
- Consistent mini-notation across tools
- Easier maintenance
- Better testing coverage

### 3. Streaming API

For very large or infinite patterns:

```elixir
def stream_pattern(pattern_string) do
  Stream.resource(
    fn -> parse(pattern_string) end,
    fn events -> {events, events} end,  # Infinite loop
    fn _ -> :ok end
  )
end
```

## References

- **Waveform**: https://github.com/rpmessner/waveform
- **SuperDirt**: https://github.com/musikinformatik/SuperDirt
- **TidalCycles**: https://tidalcycles.org/
- **KinoSpaetzle**: https://github.com/rpmessner/kino_spaetzle
