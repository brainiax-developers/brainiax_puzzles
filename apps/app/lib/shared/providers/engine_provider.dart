import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart';

/// Provider for accessing puzzle engines by ID.
final engineProvider = Provider.family<PuzzleEngine?, String>((ref, engineId) {
  final registry = EngineRegistry();
  return registry.getEngine(engineId);
});

/// Provider for getting all available engine IDs.
final availableEnginesProvider = Provider<List<String>>((ref) {
  final registry = EngineRegistry();
  return registry.registeredIds;
});

/// Provider for checking if an engine is available.
final isEngineAvailableProvider = Provider.family<bool, String>((ref, engineId) {
  final registry = EngineRegistry();
  return registry.hasEngine(engineId);
});

/// Provider for getting engine count.
final engineCountProvider = Provider<int>((ref) {
  final registry = EngineRegistry();
  return registry.engineCount;
});

/// Provider for getting all engines.
final allEnginesProvider = Provider<List<PuzzleEngine>>((ref) {
  final registry = EngineRegistry();
  return registry.allEngines;
});

/// Provider for getting engine info by ID.
final engineInfoProvider = Provider.family<EngineInfo?, String>((ref, engineId) {
  final engine = ref.watch(engineProvider(engineId));
  if (engine == null) return null;
  
  return EngineInfo(
    id: engine.id,
    name: engine.name,
    version: engine.version,
  );
});

/// Provider for getting all engine info.
final allEngineInfoProvider = Provider<List<EngineInfo>>((ref) {
  final engines = ref.watch(allEnginesProvider);
  return engines.map((engine) => EngineInfo(
    id: engine.id,
    name: engine.name,
    version: engine.version,
  )).toList();
});

/// Information about a puzzle engine.
class EngineInfo {
  final String id;
  final String name;
  final String version;

  const EngineInfo({
    required this.id,
    required this.name,
    required this.version,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EngineInfo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          version == other.version;

  @override
  int get hashCode => Object.hash(id, name, version);

  @override
  String toString() => 'EngineInfo(id: $id, name: $name, version: $version)';
}
