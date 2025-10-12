/// Puzzle Core - On-device deterministic puzzle generation system.
/// 
/// This package provides a stable API for puzzle engines with deterministic
/// generation, registry management, and metadata tracking.
/// 
/// Key features:
/// - On-device deterministic generation (no network, no wall-clock timings)
/// - 64-bit integer arithmetic for RNG (SplitMix64 seeding + xoroshiro128 core)
/// - Complete metadata tracking for reproducible puzzles
/// - Engine registry for pluggable puzzle types
/// - Daily and random seed formats
library puzzle_core;

// Core API types - the stable public interface
export 'src/api_types.dart';

// Registry implementation
export 'src/registry.dart';

// Stub engines for testing and validation
export 'src/stub/stub_engine.dart';

// Legacy exports for backward compatibility (if needed)
export 'src/puzzle_core_base.dart';
export 'src/puzzle_type.dart';

// Note: Utility classes are intentionally not exported to maintain API stability.
// Engines should import utilities directly from their internal implementations.
