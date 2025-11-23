# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- Extracted from kino_spaetzle project to enable code sharing

### Supported Syntax
- Basic sequences: `"bd sd hh sd"`
- Rests: `"bd ~ sd ~"`
- Subdivisions: `"bd [sd sd] hh"`
- Repetition: `"bd*4"`

[0.2.0]: https://github.com/rpmessner/uzu_parser/releases/tag/v0.2.0
[0.1.0]: https://github.com/rpmessner/uzu_parser/releases/tag/v0.1.0
