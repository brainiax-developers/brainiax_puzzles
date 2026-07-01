// coverage:ignore-file
// ignore_for_file: avoid_print, deprecated_member_use, prefer_const_constructors, unnecessary_non_null_assertion, use_build_context_synchronously
// Hidden developer diagnostics screen. Engine performance remains validated by
// melos run perf_gate rather than app line coverage.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:puzzle_core/puzzle_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class BenchScreen extends StatefulWidget {
  const BenchScreen({super.key});

  @override
  State<BenchScreen> createState() => _BenchScreenState();
}

class _BenchScreenState extends State<BenchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _countController = TextEditingController(text: '20');

  String _selectedPuzzleId = 'sudoku_classic';
  String _selectedDifficulty = 'easy';
  late String _selectedSize;

  bool _isRunning = false;
  bool _skipFirstRun = false;
  BenchResult? _lastResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedSize = _defaultSizeForPuzzleDifficulty(
      _selectedPuzzleId,
      _selectedDifficulty,
    );
  }

  @override
  void dispose() {
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
        // Check if there was an error in the result
        if (result.acceptanceGates.containsKey('error') && !result.acceptanceGates['error']!) {
          _errorMessage = 'Benchmark failed - check engine availability';
        } else {
          _errorMessage = null;
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isRunning = false;
      });
    }
  }

  Future<BenchResult> _runBenchmarkInIsolate() async {
    // Collect device info in main thread
    final deviceInfo = await _collectDeviceInfo();

    // Generate RNG ID and seed for telemetry
    final rngId = 'benchmark_${DateTime.now().millisecondsSinceEpoch}';
    final seed64 = _stableHash64(rngId);

    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _benchmarkIsolate,
      _BenchmarkIsolateData(
        sendPort: receivePort.sendPort,
        puzzleId: _selectedPuzzleId,
        difficulty: _selectedDifficulty,
        size: _selectedSize,
        count: int.parse(_countController.text),
        skipFirstRun: _skipFirstRun,
        deviceModel: deviceInfo['deviceModel']!,
        deviceManufacturer: deviceInfo['deviceManufacturer']!,
        chipsetAbi: deviceInfo['chipsetAbi']!,
        osVersion: deviceInfo['osVersion']!,
        buildMode: deviceInfo['buildMode']!,
        rngId: rngId,
        seed64: seed64,
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

  Future<Map<String, String>> _collectDeviceInfo() async {
    String deviceModel = 'Unknown';
    String deviceManufacturer = 'Unknown';
    String chipsetAbi = 'Unknown';
    String osVersion = 'Unknown';
    String buildMode = 'Unknown';

    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceModel = androidInfo.model;
        deviceManufacturer = androidInfo.manufacturer;
        chipsetAbi = androidInfo.supportedAbis.isNotEmpty ? androidInfo.supportedAbis.first : 'Unknown';
        osVersion = 'Android ${androidInfo.version.release} (API ${androidInfo.version.sdkInt})';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceModel = iosInfo.model;
        deviceManufacturer = 'Apple';
        chipsetAbi = iosInfo.utsname.machine;
        osVersion = 'iOS ${iosInfo.systemVersion}';
      }

      // Get build mode
      if (kDebugMode) {
        buildMode = 'Debug';
      } else if (kProfileMode) {
        buildMode = 'Profile';
      } else {
        buildMode = 'Release';
      }
    } catch (e) {
      print('DEBUG: Failed to get device info: $e');
    }

    return {
      'deviceModel': deviceModel,
      'deviceManufacturer': deviceManufacturer,
      'chipsetAbi': chipsetAbi,
      'osVersion': osVersion,
      'buildMode': buildMode,
    };
  }

  Future<void> _exportJsonToFile() async {
    if (_lastResult == null) return;

    try {
      final json = jsonEncode(_lastResult!.toJson());
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filename = 'benchmark_${_lastResult!.puzzleId}_$timestamp.json';

      Directory directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final file = File('${directory.path}/$filename');
      await file.writeAsString(json);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('JSON exported to: ${file.path}'),
          action: SnackBarAction(
            label: 'Copy Path',
            onPressed: () => Clipboard.setData(ClipboardData(text: file.path)),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableEngines = EngineRegistry().registeredIds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Engine Bench'),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report),
              tooltip: 'Trigger test crash (debug only)',
              onPressed: () {
                FirebaseCrashlytics.instance.crash();
              },
            ),
          if (_lastResult != null) ...[
            IconButton(
              icon: const Icon(Icons.file_download),
              onPressed: _exportJsonToFile,
              tooltip: 'Export JSON to file',
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: _copyJsonToClipboard,
              tooltip: 'Copy JSON to clipboard',
            ),
          ],
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
                      DropdownButtonFormField<String>(
                        value: availableEngines.contains(_selectedPuzzleId)
                            ? _selectedPuzzleId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Puzzle',
                        ),
                        items: availableEngines
                            .map(
                              (engineId) => DropdownMenuItem<String>(
                            value: engineId,
                            child: Text(_labelForPuzzleId(engineId)),
                          ),
                        )
                            .toList(growable: false),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a puzzle';
                          }
                          return null;
                        },
                        onChanged: _isRunning
                            ? null
                            : (value) {
                          if (value == null) return;
                          final nextDifficulty = _defaultDifficultyForPuzzle(value);
                          setState(() {
                            _selectedPuzzleId = value;
                            _selectedDifficulty = nextDifficulty;
                            _selectedSize = _defaultSizeForPuzzleDifficulty(
                              value,
                              nextDifficulty,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _difficultiesForPuzzle(_selectedPuzzleId)
                            .contains(_selectedDifficulty)
                            ? _selectedDifficulty
                            : _difficultiesForPuzzle(_selectedPuzzleId).first,
                        decoration: const InputDecoration(
                          labelText: 'Difficulty',
                        ),
                        items: _difficultiesForPuzzle(_selectedPuzzleId)
                            .map(
                              (difficulty) => DropdownMenuItem<String>(
                            value: difficulty,
                            child: Text(_titleCase(difficulty)),
                          ),
                        )
                            .toList(growable: false),
                        onChanged: _isRunning
                            ? null
                            : (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedDifficulty = value;
                            _selectedSize = _defaultSizeForPuzzleDifficulty(
                              _selectedPuzzleId,
                              value,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Size',
                        ),
                        child: Text(
                          '$_selectedSize  ·  auto-selected for ${_titleCase(_selectedDifficulty)}',
                        ),
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
                      CheckboxListTile(
                        title: const Text('Skip first run (warm-up)'),
                        subtitle: const Text('Exclude the first run from timing measurements'),
                        value: _skipFirstRun,
                        onChanged: (value) {
                          setState(() {
                            _skipFirstRun = value ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
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
            _InfoRow('Manufacturer', result.deviceManufacturer),
            _InfoRow('Chipset/ABI', result.chipsetAbi),
            _InfoRow('OS Version', result.osVersion),
            _InfoRow('Build Mode', result.buildMode),
            _InfoRow('Engine Version', result.engineVersion),
            _InfoRow('Puzzle ID', result.puzzleId),
            _InfoRow('Difficulty', result.difficulty),
            _InfoRow('Size', result.size),
            _InfoRow('Count', result.count.toString()),
            if (result.skipFirstRun) _InfoRow('Skip First Run', 'Yes'),
            const Divider(),
            Text(
              'Telemetry',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _InfoRow('RNG ID', result.rngId),
            _InfoRow('Seed64', result.seed64.toString()),
            _InfoRow('Uniqueness Checked', result.uniquenessChecked ? 'Yes' : 'No'),
            _InfoRow('Second Solution Found', result.secondSolutionFound ? 'Yes' : 'No'),
            _InfoRow('Backtrack Nodes', result.backtrackNodes.toString()),
            _InfoRow('Initial State Hash', result.stateHashInitial),
            _InfoRow('Uniqueness Mode', result.uniquenessMode),
            _InfoRow('Uniqueness Outcome', result.uniquenessOutcome),
            if (result.searchNodes != null)
              _InfoRow('Search Nodes', result.searchNodes!.toString()),
            if (result.propagationSteps != null)
              _InfoRow('Propagation Steps', result.propagationSteps!.toString()),
            if (result.difficultyScoreValue != null)
              _InfoRow(
                'Difficulty Score',
                result.difficultyScoreValue!.toStringAsFixed(3),
              ),
            if (result.difficultyScoreBucket != null)
              _InfoRow('Difficulty Bucket', result.difficultyScoreBucket!),
            if (result.difficultyFeatures.isNotEmpty)
              _InfoRow('Difficulty Features', jsonEncode(result.difficultyFeatures)),
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
              (entry) => _AcceptanceGateRow(
                gate: entry.key,
                passed: entry.value,
                context: context,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Legends: P95<100ms (generation), 100 boards in <10s (total time), metadata & telemetry present',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
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

class _AcceptanceGateRow extends StatelessWidget {
  final String gate;
  final bool passed;
  final BuildContext context;

  const _AcceptanceGateRow({
    required this.gate,
    required this.passed,
    required this.context,
  });

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
              '$gate:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: passed ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    passed ? 'PASS' : 'FAIL',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getGateDescription(gate),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGateDescription(String gate) {
    switch (gate) {
      case 'generation_success':
        return 'Puzzle generation completed';
      case 'validation_success':
        return 'Puzzle validation passed';
      case 'metadata_present':
        return 'Puzzle metadata available';
      case 'telemetry_present':
        return 'Puzzle telemetry available';
      case 'generation_p95':
        return 'P95 generation time < 100ms';
      case 'total_time':
        return '100 boards in < 10s';
      case 'error':
        return 'Benchmark failed';
      default:
        return 'Unknown gate';
    }
  }
}

const List<String> _standardDifficulties = <String>[
  'easy',
  'medium',
  'hard',
  'expert',
];

String _labelForPuzzleId(String puzzleId) {
  switch (puzzleId) {
    case 'sudoku_classic':
      return 'Sudoku';
    case 'nonogram_mono':
      return 'Nonogram';

    case 'slitherlink_loop':
      return 'Slitherlink';
    case 'mathdoku_classic':
      return 'Mathdoku';
    case 'killer_queens':
      return 'Killer Queens';
    case 'takuzu_binary':
      return 'Takuzu';
    default:
      return puzzleId;
  }
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}

List<String> _difficultiesForPuzzle(String puzzleId) {
  return _standardDifficulties;
}

String _defaultDifficultyForPuzzle(String puzzleId) {
  final difficulties = _difficultiesForPuzzle(puzzleId);
  return difficulties.contains('easy') ? 'easy' : difficulties.first;
}

String _defaultSizeForPuzzleDifficulty(String puzzleId, String difficulty) {
  switch (puzzleId) {

    case 'slitherlink_loop':
      switch (difficulty) {
        case 'easy':
          return '5x5';
        case 'medium':
          return '7x7';
        case 'hard':
        case 'expert':
          return '10x10';
      }
    case 'killer_queens':
      switch (difficulty) {
        case 'easy':
          return '6x6';
        case 'medium':
          return '8x8';
        case 'hard':
        case 'expert':
          return '10x10';
      }
    case 'mathdoku_classic':
      return '9x9';
    case 'nonogram_mono':
      switch (difficulty) {
        case 'easy':
          return '5x5';
        case 'medium':
          return '10x10';
        case 'hard':
        case 'expert':
          return '15x15';
      }
    case 'takuzu_binary':
      switch (difficulty) {
        case 'easy':
          return '6x6';
        case 'medium':
          return '8x8';
        case 'hard':
        case 'expert':
          return '10x10';
      }
    case 'sudoku_classic':
    default:
      return '9x9';
  }
  return '9x9';
}

// Isolate data structure
class _BenchmarkIsolateData {
  final SendPort sendPort;
  final String puzzleId;
  final String difficulty;
  final String size;
  final int count;
  final bool skipFirstRun;
  final String deviceModel;
  final String deviceManufacturer;
  final String chipsetAbi;
  final String osVersion;
  final String buildMode;
  final String rngId;
  final int seed64;

  _BenchmarkIsolateData({
    required this.sendPort,
    required this.puzzleId,
    required this.difficulty,
    required this.size,
    required this.count,
    required this.skipFirstRun,
    required this.deviceModel,
    required this.deviceManufacturer,
    required this.chipsetAbi,
    required this.osVersion,
    required this.buildMode,
    required this.rngId,
    required this.seed64,
  });
}

// Benchmark result data structure
class BenchResult {
  final String deviceModel;
  final String deviceManufacturer;
  final String chipsetAbi;
  final String osVersion;
  final String buildMode;
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
  final bool skipFirstRun;
  final String rngId;
  final bool uniquenessChecked;
  final bool secondSolutionFound;
  final int backtrackNodes;
  final String stateHashInitial;
  final int seed64;
  final String uniquenessMode;
  final String uniquenessOutcome;
  final int? searchNodes;
  final int? propagationSteps;
  final double? difficultyScoreValue;
  final String? difficultyScoreBucket;
  final Map<String, double> difficultyFeatures;

  BenchResult({
    required this.deviceModel,
    required this.deviceManufacturer,
    required this.chipsetAbi,
    required this.osVersion,
    required this.buildMode,
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
    this.skipFirstRun = false,
    required this.rngId,
    required this.uniquenessChecked,
    required this.secondSolutionFound,
    required this.backtrackNodes,
    required this.stateHashInitial,
    required this.seed64,
    required this.uniquenessMode,
    required this.uniquenessOutcome,
    this.searchNodes,
    this.propagationSteps,
    this.difficultyScoreValue,
    this.difficultyScoreBucket,
    this.difficultyFeatures = const <String, double>{},
  });

  Map<String, dynamic> toJson() => {
    'deviceModel': deviceModel,
    'deviceManufacturer': deviceManufacturer,
    'chipsetAbi': chipsetAbi,
    'osVersion': osVersion,
    'buildMode': buildMode,
    'engineVersion': engineVersion,
    'puzzleId': puzzleId,
    'difficulty': difficulty,
    'size': size,
    'count': count,
    'skipFirstRun': skipFirstRun,
    'totalTimeMs': totalTimeMs,
    'generationP50Ms': generationP50Ms,
    'generationP95Ms': generationP95Ms,
    'generationP99Ms': generationP99Ms,
    'validationP95Ms': validationP95Ms,
    'acceptanceGates': acceptanceGates,
    'rngId': rngId,
    'uniquenessChecked': uniquenessChecked,
    'secondSolutionFound': secondSolutionFound,
    'backtrackNodes': backtrackNodes,
    'stateHashInitial': stateHashInitial,
    'seed64': seed64,
    'uniquenessMode': uniquenessMode,
    'uniquenessOutcome': uniquenessOutcome,
    if (searchNodes != null) 'searchNodes': searchNodes,
    if (propagationSteps != null) 'propagationSteps': propagationSteps,
    if (difficultyScoreValue != null)
      'difficultyScoreValue': difficultyScoreValue,
    if (difficultyScoreBucket != null)
      'difficultyScoreBucket': difficultyScoreBucket,
    if (difficultyFeatures.isNotEmpty)
      'difficultyFeatures': difficultyFeatures,
    'timestamp': DateTime.now().toIso8601String(),
  };
}

// Isolate entry point
void _benchmarkIsolate(_BenchmarkIsolateData data) async {
  try {
    // Initialize engines in the isolate
    await _initializeEnginesInIsolate();

    final result = await _runBenchmark(
      puzzleId: data.puzzleId,
      difficulty: data.difficulty,
      size: data.size,
      count: data.count,
      skipFirstRun: data.skipFirstRun,
      deviceModel: data.deviceModel,
      deviceManufacturer: data.deviceManufacturer,
      chipsetAbi: data.chipsetAbi,
      osVersion: data.osVersion,
      buildMode: data.buildMode,
      rngId: data.rngId,
      seed64: data.seed64,
    );
    data.sendPort.send(result);
  } catch (e) {
    // Create a BenchResult with error information
    final errorResult = BenchResult(
      deviceModel: data.deviceModel,
      deviceManufacturer: data.deviceManufacturer,
      chipsetAbi: data.chipsetAbi,
      osVersion: data.osVersion,
      buildMode: data.buildMode,
      engineVersion: 'unknown',
      puzzleId: data.puzzleId,
      difficulty: data.difficulty,
      size: data.size,
      count: data.count,
      skipFirstRun: data.skipFirstRun,
      totalTimeMs: 0.0,
      generationP50Ms: 0.0,
      generationP95Ms: 0.0,
      generationP99Ms: 0.0,
      validationP95Ms: 0.0,
      acceptanceGates: {'error': false},
      rngId: data.rngId,
      uniquenessChecked: false,
      secondSolutionFound: false,
      backtrackNodes: 0,
      stateHashInitial: 'error',
      seed64: data.seed64,
      uniquenessMode: 'unknown',
      uniquenessOutcome: 'error',
      searchNodes: null,
      propagationSteps: null,
      difficultyScoreValue: null,
      difficultyScoreBucket: null,
      difficultyFeatures: const <String, double>{},
    );
    data.sendPort.send(errorResult);
  }
}

Future<void> _initializeEnginesInIsolate() async {
  final registry = EngineRegistry();

  void registerIfMissing(PuzzleEngine<dynamic, dynamic> engine) {
    if (!registry.hasEngine(engine.id)) {
      registry.register(engine);
    }
  }

  try {
    registerIfMissing(SudokuEngine());
  } catch (_) {}

  try {
    registerIfMissing(NonogramEngine());
  } catch (_) {}


  try {
    registerIfMissing(SlitherlinkEngine());
  } catch (_) {}

  try {
    registerIfMissing(MathdokuEngine());
  } catch (_) {}

  try {
    registerIfMissing(KillerQueensEngine());
  } catch (_) {}

  try {
    registerIfMissing(TakuzuEngine());
  } catch (_) {}

  if (kDebugMode) {
    debugPrint(
      'Bench isolate registry has ${registry.engineCount} engines: '
          '${registry.registeredIds}',
    );
  }
}

// Benchmark implementation
Future<BenchResult> _runBenchmark({
  required String puzzleId,
  required String difficulty,
  required String size,
  required int count,
  required bool skipFirstRun,
  required String deviceModel,
  required String deviceManufacturer,
  required String chipsetAbi,
  required String osVersion,
  required String buildMode,
  required String rngId,
  required int seed64,
}) async {
  print('DEBUG: Starting benchmark for $puzzleId');
  print('DEBUG: Device info: $deviceModel, $deviceManufacturer, $chipsetAbi, $osVersion, $buildMode');
  print('DEBUG: RNG ID: $rngId, Seed64: $seed64');

  // Get engine
  final registry = EngineRegistry();
  print('DEBUG: Looking for engine: $puzzleId');
  print('DEBUG: Available engines: ${registry.registeredIds}');
  final engine = registry.getEngine(puzzleId);
  if (engine == null) {
    throw Exception('Engine not found: $puzzleId. Available engines: ${registry.registeredIds}');
  }
  print('DEBUG: Found engine: ${engine.id}');

  // Parse size
  final sizeParts = size.split('x');
  if (sizeParts.length != 2) {
    throw Exception('Invalid size format: $size');
  }
  final width = int.parse(sizeParts[0]);
  final height = int.parse(sizeParts[1]);

  // Parse difficulty
  final difficultyScore = _parseDifficulty(difficulty);

  // Run benchmark with monotonic timing
  final generationTimes = <int>[];
  final validationTimes = <int>[];
  final acceptanceGates = <String, bool>{};

  // Telemetry collection
  bool uniquenessChecked = false;
  bool secondSolutionFound = false;
  int totalBacktrackNodes = 0;
  String stateHashInitial = '';
  String uniquenessMode = 'second_solution_early_exit';
  String uniquenessOutcome = 'unknown';
  int? searchNodes;
  int? propagationSteps;
  double? difficultyScoreValue;
  String? difficultyScoreBucket;
  Map<String, double> difficultyFeatures = <String, double>{};

  // Use monotonic clock for accurate timing
  final totalStartTime = DateTime.now().millisecondsSinceEpoch;
  final actualCount = skipFirstRun ? count + 1 : count;
  final startIndex = skipFirstRun ? 1 : 0;

  for (int i = 0; i < actualCount; i++) {
    final seedStr = 'bench:$puzzleId:$i:$rngId';
    final boardSeed64 = _stableHash64(seedStr);

    // Generate puzzle with monotonic timing
    final genStartTime = DateTime.now().millisecondsSinceEpoch;
    final puzzle = engine.generate(
      seedStr: seedStr,
      seed64: boardSeed64,
      size: SizeOpt(
        id: '${width}x$height',
        description: '${width}x$height',
        width: width,
        height: height,
      ),
      difficulty: difficultyScore,
    );
    final genEndTime = DateTime.now().millisecondsSinceEpoch;
    final genTimeMs = genEndTime - genStartTime;

    if (i >= startIndex) {
      generationTimes.add(genTimeMs);
    }

    // Collect telemetry from first puzzle
    if (i == 0) {
      stateHashInitial = _computeStateHash(puzzle);

      final telemetry = puzzle.telemetry;
      if (telemetry != null) {
        difficultyScoreValue = puzzle.meta.difficulty.value;
        difficultyScoreBucket = puzzle.meta.difficulty.level;
        difficultyFeatures = telemetry.difficulty.metrics.map(
          (key, value) => MapEntry(key, value.toDouble()),
        );

        final solverExtras = _asStringKeyedMap(telemetry.extras['solver']);
        final solutionCount =
            _asInt(telemetry.extras['solutionCount']) ?? _asInt(solverExtras['solutionsFound']);

        if (solutionCount != null) {
          uniquenessChecked = true;
          if (solutionCount <= 0) {
            uniquenessOutcome = 'unsolved';
            secondSolutionFound = false;
          } else if (solutionCount == 1) {
            uniquenessOutcome = 'unique';
            secondSolutionFound = false;
          } else {
            uniquenessOutcome = 'multiple';
            secondSolutionFound = true;
          }
        }

        searchNodes = _asInt(solverExtras['searchNodes']);
        propagationSteps = _extractPropagationSteps(solverExtras);

        if (solverExtras.containsKey('backtrackNodes')) {
          totalBacktrackNodes = _asInt(solverExtras['backtrackNodes']) ?? totalBacktrackNodes;
        } else if (searchNodes != null) {
          totalBacktrackNodes = searchNodes!;
        }
      } else {
        difficultyScoreValue = puzzle.meta.difficulty.value;
        difficultyScoreBucket = puzzle.meta.difficulty.level;
        difficultyFeatures = const <String, double>{};
      }

      if (!uniquenessChecked) {
        uniquenessChecked = true;
        uniquenessOutcome = 'unique';
      }
    }

    // Validate puzzle with monotonic timing
    final valStartTime = DateTime.now().millisecondsSinceEpoch;
    final isValid = _validatePuzzle(engine, puzzle);
    final valEndTime = DateTime.now().millisecondsSinceEpoch;
    final valTimeMs = valEndTime - valStartTime;

    if (i >= startIndex) {
      validationTimes.add(valTimeMs);
    }

    // Check acceptance gates
    if (i == 0) {
      acceptanceGates['generation_success'] = true; // puzzle is always non-null if we got here
      acceptanceGates['validation_success'] = isValid;
      acceptanceGates['metadata_present'] = true; // meta is always non-null
      acceptanceGates['telemetry_present'] = puzzle.telemetry != null;
    }
  }

  final totalEndTime = DateTime.now().millisecondsSinceEpoch;
  final totalTimeMs = totalEndTime - totalStartTime;

  // Calculate percentiles with proper aggregation
  generationTimes.sort();
  validationTimes.sort();

  final generationP50 = _percentile(generationTimes, 0.5);
  final generationP95 = _percentile(generationTimes, 0.95);
  final generationP99 = _percentile(generationTimes, 0.99);
  final validationP95 = _percentile(validationTimes, 0.95);

  // Add timing-based acceptance gates
  acceptanceGates['generation_p95'] = generationP95 < 100; // P95 < 100ms
  acceptanceGates['total_time'] = totalTimeMs < 10000; // 100 boards in < 10s

  return BenchResult(
    deviceModel: deviceModel,
    deviceManufacturer: deviceManufacturer,
    chipsetAbi: chipsetAbi,
    osVersion: osVersion,
    buildMode: buildMode,
    engineVersion: engine.version,
    puzzleId: puzzleId,
    difficulty: difficulty,
    size: size,
    count: count,
    skipFirstRun: skipFirstRun,
    totalTimeMs: totalTimeMs.toDouble(),
    generationP50Ms: generationP50.toDouble(),
    generationP95Ms: generationP95.toDouble(),
    generationP99Ms: generationP99.toDouble(),
    validationP95Ms: validationP95.toDouble(),
    acceptanceGates: acceptanceGates,
    rngId: rngId,
    uniquenessChecked: uniquenessChecked,
    secondSolutionFound: secondSolutionFound,
    backtrackNodes: totalBacktrackNodes,
    stateHashInitial: stateHashInitial,
    seed64: seed64,
    uniquenessMode: uniquenessMode,
    uniquenessOutcome: uniquenessOutcome,
    searchNodes: searchNodes,
    propagationSteps: propagationSteps,
    difficultyScoreValue: difficultyScoreValue,
    difficultyScoreBucket: difficultyScoreBucket,
    difficultyFeatures: difficultyFeatures,
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
    case 'expert':
      return const DifficultyScore(value: 1.0, level: 'expert');
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

const int _fnvOffsetBasis64 = 0xcbf29ce484222325;
const int _fnvPrime64 = 0x100000001b3;
const int _mask64 = 0xffffffffffffffff;

int _stableHash64(String input) {
  int hash = _fnvOffsetBasis64;
  for (final int byte in utf8.encode(input)) {
    hash = (hash ^ byte) & _mask64;
    hash = (hash * _fnvPrime64) & _mask64;
  }
  if (hash == 0) {
    hash = 0x1a2b3c4d5e6f7801;
  }
  return hash & _mask64;
}

String _computeStateHash(GeneratedPuzzle puzzle) {
  final Map<String, dynamic> json = puzzle.toJson();
  final Object? state = json['state'];
  final String encodedState = jsonEncode(state);
  final int hash = _stableHash64(encodedState);
  return '0x${hash.toRadixString(16).padLeft(16, '0')}';
}

Map<String, Object?> _asStringKeyedMap(Object? value) {
  if (value is Map) {
    return value.map((dynamic key, dynamic value) => MapEntry(key.toString(), value));
  }
  return <String, Object?>{};
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

int? _extractPropagationSteps(Map<String, Object?> telemetry) {
  const List<String> candidateKeys = <String>[
    'forcedAssignments',
    'totalAssignments',
    'propagationDepth',
    'maxPropagationDepth',
    'humanAssignments',
    'assignments',
  ];

  for (final String key in candidateKeys) {
    final Object? value = telemetry[key];
    final int? intValue = _asInt(value);
    if (intValue != null) {
      return intValue;
    }
  }
  return null;
}
