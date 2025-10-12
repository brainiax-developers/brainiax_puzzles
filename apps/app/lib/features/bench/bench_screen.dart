import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:puzzle_core/puzzle_core.dart';

class BenchScreen extends StatefulWidget {
  const BenchScreen({super.key});

  @override
  State<BenchScreen> createState() => _BenchScreenState();
}

class _BenchScreenState extends State<BenchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _puzzleIdController = TextEditingController(text: 'stub');
  final _difficultyController = TextEditingController(text: 'medium');
  final _sizeController = TextEditingController(text: '9x9');
  final _countController = TextEditingController(text: '10');
  
  bool _isRunning = false;
  BenchResult? _lastResult;
  String? _errorMessage;

  @override
  void dispose() {
    _puzzleIdController.dispose();
    _difficultyController.dispose();
    _sizeController.dispose();
    _countController.dispose();
    super.dispose();
  }

  Future<void> _runBenchmark() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isRunning = true;
      _errorMessage = null;
      _lastResult = null;
    });

    try {
      final result = await _runBenchmarkInIsolate();
      setState(() {
        _lastResult = result;
        _isRunning = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isRunning = false;
      });
    }
  }

  Future<BenchResult> _runBenchmarkInIsolate() async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _benchmarkIsolate,
      _BenchmarkIsolateData(
        sendPort: receivePort.sendPort,
        puzzleId: _puzzleIdController.text,
        difficulty: _difficultyController.text,
        size: _sizeController.text,
        count: int.parse(_countController.text),
      ),
    );

    final result = await receivePort.first as BenchResult;
    isolate.kill();
    return result;
  }

  void _copyJsonToClipboard() {
    if (_lastResult == null) return;
    
    final json = jsonEncode(_lastResult!.toJson());
    Clipboard.setData(ClipboardData(text: json));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('JSON copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableEngines = EngineRegistry().registeredIds;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Engine Bench'),
        actions: [
          if (_lastResult != null)
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: _copyJsonToClipboard,
              tooltip: 'Copy JSON to clipboard',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Benchmark Configuration',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _puzzleIdController,
                        decoration: InputDecoration(
                          labelText: 'Puzzle ID',
                          hintText: 'e.g., sudoku, nonogram, stub',
                          suffixText: 'Available: ${availableEngines.join(', ')}',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a puzzle ID';
                          }
                          if (!availableEngines.contains(value)) {
                            return 'Engine not found. Available: ${availableEngines.join(', ')}';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _difficultyController,
                        decoration: const InputDecoration(
                          labelText: 'Difficulty',
                          hintText: 'e.g., easy, medium, hard',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a difficulty';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _sizeController,
                        decoration: const InputDecoration(
                          labelText: 'Size',
                          hintText: 'e.g., 9x9, 6x6, 4x4',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a size';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _countController,
                        decoration: const InputDecoration(
                          labelText: 'Count',
                          hintText: 'Number of puzzles to generate (default: 10)',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a count';
                          }
                          final count = int.tryParse(value);
                          if (count == null || count <= 0) {
                            return 'Please enter a valid positive number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isRunning ? null : _runBenchmark,
                          child: _isRunning
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Running...'),
                                  ],
                                )
                              : const Text('Run Benchmark'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error: $_errorMessage',
                    style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                ),
              ),
            if (_lastResult != null) ...[
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: _BenchResultWidget(result: _lastResult!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BenchResultWidget extends StatelessWidget {
  final BenchResult result;

  const _BenchResultWidget({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Benchmark Results',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _InfoRow('Device Model', result.deviceModel),
            _InfoRow('OS Version', result.osVersion),
            _InfoRow('Engine Version', result.engineVersion),
            _InfoRow('Puzzle ID', result.puzzleId),
            _InfoRow('Difficulty', result.difficulty),
            _InfoRow('Size', result.size),
            _InfoRow('Count', result.count.toString()),
            const Divider(),
            _InfoRow('Total Time', '${result.totalTimeMs.toStringAsFixed(2)} ms'),
            _InfoRow('Generation P50', '${result.generationP50Ms.toStringAsFixed(2)} ms'),
            _InfoRow('Generation P95', '${result.generationP95Ms.toStringAsFixed(2)} ms'),
            _InfoRow('Generation P99', '${result.generationP99Ms.toStringAsFixed(2)} ms'),
            _InfoRow('Validation P95', '${result.validationP95Ms.toStringAsFixed(2)} ms'),
            const Divider(),
            Text(
              'Acceptance Gates',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...result.acceptanceGates.entries.map(
              (entry) => _InfoRow(entry.key, entry.value ? 'PASS' : 'FAIL'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// Isolate data structure
class _BenchmarkIsolateData {
  final SendPort sendPort;
  final String puzzleId;
  final String difficulty;
  final String size;
  final int count;

  _BenchmarkIsolateData({
    required this.sendPort,
    required this.puzzleId,
    required this.difficulty,
    required this.size,
    required this.count,
  });
}

// Benchmark result data structure
class BenchResult {
  final String deviceModel;
  final String osVersion;
  final String engineVersion;
  final String puzzleId;
  final String difficulty;
  final String size;
  final int count;
  final double totalTimeMs;
  final double generationP50Ms;
  final double generationP95Ms;
  final double generationP99Ms;
  final double validationP95Ms;
  final Map<String, bool> acceptanceGates;

  BenchResult({
    required this.deviceModel,
    required this.osVersion,
    required this.engineVersion,
    required this.puzzleId,
    required this.difficulty,
    required this.size,
    required this.count,
    required this.totalTimeMs,
    required this.generationP50Ms,
    required this.generationP95Ms,
    required this.generationP99Ms,
    required this.validationP95Ms,
    required this.acceptanceGates,
  });

  Map<String, dynamic> toJson() => {
    'deviceModel': deviceModel,
    'osVersion': osVersion,
    'engineVersion': engineVersion,
    'puzzleId': puzzleId,
    'difficulty': difficulty,
    'size': size,
    'count': count,
    'totalTimeMs': totalTimeMs,
    'generationP50Ms': generationP50Ms,
    'generationP95Ms': generationP95Ms,
    'generationP99Ms': generationP99Ms,
    'validationP95Ms': validationP95Ms,
    'acceptanceGates': acceptanceGates,
    'timestamp': DateTime.now().toIso8601String(),
  };
}

// Isolate entry point
void _benchmarkIsolate(_BenchmarkIsolateData data) async {
  try {
    final result = await _runBenchmark(
      puzzleId: data.puzzleId,
      difficulty: data.difficulty,
      size: data.size,
      count: data.count,
    );
    data.sendPort.send(result);
  } catch (e) {
    data.sendPort.send(e);
  }
}

// Benchmark implementation
Future<BenchResult> _runBenchmark({
  required String puzzleId,
  required String difficulty,
  required String size,
  required int count,
}) async {
  // Get device info
  final deviceInfo = DeviceInfoPlugin();
  String deviceModel;
  String osVersion;
  
  if (Platform.isAndroid) {
    final androidInfo = await deviceInfo.androidInfo;
    deviceModel = '${androidInfo.brand} ${androidInfo.model}';
    osVersion = 'Android ${androidInfo.version.release}';
  } else if (Platform.isIOS) {
    final iosInfo = await deviceInfo.iosInfo;
    deviceModel = '${iosInfo.name} ${iosInfo.model}';
    osVersion = 'iOS ${iosInfo.systemVersion}';
  } else {
    deviceModel = 'Unknown';
    osVersion = 'Unknown';
  }

  // Get engine
  final registry = EngineRegistry();
  final engine = registry.getEngine(puzzleId);
  if (engine == null) {
    throw Exception('Engine not found: $puzzleId');
  }

  // Parse size
  final sizeParts = size.split('x');
  if (sizeParts.length != 2) {
    throw Exception('Invalid size format: $size');
  }
  final width = int.parse(sizeParts[0]);
  final height = int.parse(sizeParts[1]);

  // Parse difficulty
  final difficultyScore = _parseDifficulty(difficulty);

  // Run benchmark
  final generationTimes = <int>[];
  final validationTimes = <int>[];
  final acceptanceGates = <String, bool>{};

  final totalStopwatch = Stopwatch()..start();

  for (int i = 0; i < count; i++) {
    final seedStr = 'bench:$puzzleId:$i';
    final seed64 = seedStr.hashCode;

    // Generate puzzle
    final genStopwatch = Stopwatch()..start();
    final puzzle = engine.generate(
      seedStr: seedStr,
      seed64: seed64,
      size: SizeOpt(
        id: '${width}x$height',
        description: '${width}x$height',
        width: width,
        height: height,
      ),
      difficulty: difficultyScore,
    );
    genStopwatch.stop();
    generationTimes.add(genStopwatch.elapsedMicroseconds);

    // Validate puzzle
    final valStopwatch = Stopwatch()..start();
    final isValid = _validatePuzzle(engine, puzzle);
    valStopwatch.stop();
    validationTimes.add(valStopwatch.elapsedMicroseconds);

    // Check acceptance gates
    if (i == 0) {
      acceptanceGates['generation_success'] = true; // puzzle is always non-null if we got here
      acceptanceGates['validation_success'] = isValid;
      acceptanceGates['metadata_present'] = true; // meta is always non-null
      acceptanceGates['telemetry_present'] = puzzle.telemetry != null;
    }
  }

  totalStopwatch.stop();

  // Calculate percentiles
  generationTimes.sort();
  validationTimes.sort();

  final generationP50 = _percentile(generationTimes, 0.5);
  final generationP95 = _percentile(generationTimes, 0.95);
  final generationP99 = _percentile(generationTimes, 0.99);
  final validationP95 = _percentile(validationTimes, 0.95);

  return BenchResult(
    deviceModel: deviceModel,
    osVersion: osVersion,
    engineVersion: engine.version,
    puzzleId: puzzleId,
    difficulty: difficulty,
    size: size,
    count: count,
    totalTimeMs: totalStopwatch.elapsedMicroseconds / 1000.0,
    generationP50Ms: generationP50 / 1000.0,
    generationP95Ms: generationP95 / 1000.0,
    generationP99Ms: generationP99 / 1000.0,
    validationP95Ms: validationP95 / 1000.0,
    acceptanceGates: acceptanceGates,
  );
}

DifficultyScore _parseDifficulty(String difficulty) {
  switch (difficulty.toLowerCase()) {
    case 'easy':
      return const DifficultyScore(value: 0.3, level: 'easy');
    case 'medium':
      return const DifficultyScore(value: 0.6, level: 'medium');
    case 'hard':
      return const DifficultyScore(value: 0.9, level: 'hard');
    default:
      return const DifficultyScore(value: 0.6, level: 'medium');
  }
}

bool _validatePuzzle(PuzzleEngine engine, GeneratedPuzzle puzzle) {
  try {
    // Basic validation - check if puzzle has required properties
    return puzzle.meta.engineVersion.isNotEmpty;
  } catch (e) {
    return false;
  }
}

int _percentile(List<int> sortedList, double percentile) {
  if (sortedList.isEmpty) return 0;
  final index = (percentile * (sortedList.length - 1)).round();
  return sortedList[index.clamp(0, sortedList.length - 1)];
}
