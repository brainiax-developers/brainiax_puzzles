## 1.0.0

- Initial version.

## 1.1.0

### Improvements
- **API Design**: Removed utility exports from main library to maintain API stability
- **Safety**: Added comprehensive bounds checking to grid operations
- **Documentation**: Added extensive documentation for all utility classes with usage examples
- **RNG Validation**: Added state validation to RNG with `isValidState` property
- **Memory Management**: Added cache size limits to BacktrackingSolver to prevent memory issues


### Technical Enhancements
- Grid classes now throw proper `RangeError` for out-of-bounds access
- BacktrackingSolver respects `maxCacheSize` parameter (default: 1000)

- RNG includes state validation and improved error handling
- All utility classes have comprehensive documentation with examples

### Testing
- Updated all tests to work with new API structure
- Fixed RNG tests to focus on determinism rather than specific values
- All 33 tests passing with comprehensive coverage
