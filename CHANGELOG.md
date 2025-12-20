# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.0] - 2025-12-20

### Changed
- **Period in sound names** - Period (`.`) is now part of sound names for Strudel compatibility. `bd.sd.hh` is parsed as one sound, not three separate sounds separated by periods.
- **Empty brackets** - `[]` now parses as a rest (empty subdivision)

### Fixed
- Enabled previously pending tests for modifiers on groupers (`[a b]!`, `<a b>!3`, `{a b, c d}?`, etc.)

## [0.5.0] - 2025-12-07

### Changed
- **NimbleParsec rewrite** - Complete parser rewrite using NimbleParsec for better performance and maintainability
- **AST interpreter** - New interpreter module for evaluating parsed AST
- **Module extraction** - Extracted focused modules: Timing, Structure, TokenParser, Euclidean, Collectors
- **Source position tracking** - Events now include source positions for error reporting

### Infrastructure
- CI matrix updated for Elixir 1.17-1.19 with OTP 27-28
- Added lefthook for pre-commit formatting
- Added CLAUDE.md project documentation

## [0.4.0] - 2025-12-01

### Changed
- Internal refactoring and test improvements

## [0.3.0] - 2025-11-25

### Added
- **Random Choice (`|`)** - Randomly select one option per evaluation: `"bd|sd|hh"`
- **Alternation (`<>`)** - Cycle through options sequentially: `"<bd sd hh>"`
- Parser stores options in event params for playback system to resolve
- Comprehensive test suite expanded to 84 tests

### Changed
- Extended Event params to support `random_choice` and `alternate` option lists
- Added angle bracket parsing for alternation syntax

## [0.2.0] - 2025-01-23

### Added
- **Polyphony (`,`)** - Play multiple sounds simultaneously using comma syntax within brackets: `"[bd,sd,hh]"`
- **Random Removal (`?`)** - Probabilistic events with default 50% or custom probability: `"bd?"` or `"bd?0.25"`
- **Elongation (`@`)** - Temporal weight for proportional durations: `"bd@2 sd"` gives bd 2/3 of time
- **Replication (`!`)** - Alternative repetition syntax: `"bd!3"` (functionally equivalent to `bd*3`)
- Sample selection feature: `"bd:0 sd:1"` for choosing specific samples
- Comprehensive test suite expanded to 69 tests

### Fixed
- **Performance optimization** - Changed O(n²) string concatenation to O(n) iolist accumulation in bracket collection
- Improved parser efficiency for nested patterns and long subdivisions

### Changed
- Extended Event structure to support probability in params field
- Reimplemented timing calculation with weighted duration algorithm
- Sound token format extended from 3-tuple to 5-tuple for additional metadata

### Documentation
- Added comprehensive examples for all new features
- Updated README with new syntax sections
- Added ROADMAP with planned Phase 2 and Phase 3 features
- Created performance analysis documentation
- Added session notes and implementation guides

## [0.1.0] - 2025-01-22

### Added
- Initial release
- Basic pattern parsing with mini-notation syntax
- Support for sequences, rests, subdivisions, and repetition
- Event data structure with time, duration, sound, and params
- Comprehensive test suite (23 tests)
- Complete documentation and examples
- Extracted from kino_harmony project (formerly kino_spaetzle) to enable code sharing

### Supported Syntax
- Basic sequences: `"bd sd hh sd"`
- Rests: `"bd ~ sd ~"`
- Subdivisions: `"bd [sd sd] hh"`
- Repetition: `"bd*4"`

[0.6.0]: https://github.com/rpmessner/uzu_parser/releases/tag/v0.6.0
[0.5.0]: https://github.com/rpmessner/uzu_parser/releases/tag/v0.5.0
[0.4.0]: https://github.com/rpmessner/uzu_parser/releases/tag/v0.4.0
[0.3.0]: https://github.com/rpmessner/uzu_parser/releases/tag/v0.3.0
[0.2.0]: https://github.com/rpmessner/uzu_parser/releases/tag/v0.2.0
[0.1.0]: https://github.com/rpmessner/uzu_parser/releases/tag/v0.1.0
