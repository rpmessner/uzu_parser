# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.0]: https://github.com/rpmessner/uzu_parser/releases/tag/v0.1.0
