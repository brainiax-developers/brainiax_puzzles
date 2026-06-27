#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

const _packageConfigFiles = {'analysis_options.yaml', 'pubspec.yaml'};

Future<void> main(List<String> args) async {
  final diffRange = _resolveDiffRange(args);
  final workspacePackages = _readWorkspacePackages();
  final changedFiles = _collectChangedFiles(diffRange: diffRange);
  final selections = _buildSelections(
    changedFiles: changedFiles,
    workspacePackages: workspacePackages,
  );

  if (selections.isEmpty) {
    stdout.writeln('No changed workspace files detected; skipping analysis.');
    return;
  }

  var hasFailures = false;

  for (final selection in selections) {
    final command = selection.package.isFlutter ? 'flutter' : 'dart';
    final arguments = <String>['analyze'];

    if (!selection.analyzeWholePackage) {
      arguments.addAll(selection.files);
    }

    stdout.writeln(
      'Analyzing ${selection.package.name}'
      '${selection.analyzeWholePackage ? " (full package)" : ""}...',
    );

    final exitCode = await _runProcess(
      executable: command,
      arguments: arguments,
      workingDirectory: selection.package.absolutePath,
    );

    if (exitCode != 0) {
      hasFailures = true;
    }
  }

  if (hasFailures) {
    exit(1);
  }
}

String? _resolveDiffRange(List<String> args) {
  final envValue = Platform.environment['MELOS_ANALYZE_DIFF']?.trim();
  if (envValue != null && envValue.isNotEmpty) {
    return envValue;
  }

  if (args.isNotEmpty) {
    return args.first.trim().isEmpty ? null : args.first.trim();
  }

  final hasMain =
      _runGitCommand(['rev-parse', '--verify', 'main']).exitCode == 0;
  if (!hasMain) {
    return null;
  }

  return 'main...HEAD';
}

List<_PackageInfo> _readWorkspacePackages() {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('Workspace pubspec.yaml not found.');
    exit(1);
  }

  final lines = pubspec.readAsLinesSync();
  final packages = <_PackageInfo>[];
  var inWorkspace = false;

  for (final rawLine in lines) {
    final line = rawLine.trimRight();

    if (!inWorkspace) {
      if (line.trim() == 'workspace:') {
        inWorkspace = true;
      }
      continue;
    }

    final trimmed = line.trimLeft();
    if (trimmed.startsWith('- ')) {
      final relativePath = trimmed.substring(2).trim();
      final absolutePath = p.normalize(
        p.join(Directory.current.path, relativePath),
      );
      final packagePubspec = File(p.join(absolutePath, 'pubspec.yaml'));
      if (!packagePubspec.existsSync()) {
        continue;
      }

      packages.add(
        _PackageInfo(
          name: _readPackageName(packagePubspec) ?? p.basename(relativePath),
          relativePath: p.posix.normalize(relativePath.replaceAll('\\', '/')),
          absolutePath: absolutePath,
          isFlutter: packagePubspec.readAsStringSync().contains('sdk: flutter'),
        ),
      );
      continue;
    }

    if (trimmed.isEmpty || rawLine.startsWith('  ')) {
      continue;
    }

    break;
  }

  return packages;
}

String? _readPackageName(File pubspec) {
  for (final line in pubspec.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.startsWith('name:')) {
      return trimmed.substring('name:'.length).trim();
    }
  }

  return null;
}

Set<String> _collectChangedFiles({String? diffRange}) {
  final files = <String>{};

  if (diffRange != null) {
    files.addAll(
      _runGitCommand([
        'diff',
        '--name-only',
        '--diff-filter=ACMRD',
        diffRange,
      ]).lines,
    );
  }

  files.addAll(
    _runGitCommand(['diff', '--name-only', '--diff-filter=ACMRD']).lines,
  );
  files.addAll(
    _runGitCommand([
      'diff',
      '--cached',
      '--name-only',
      '--diff-filter=ACMRD',
    ]).lines,
  );
  files.addAll(
    _runGitCommand(['ls-files', '--others', '--exclude-standard']).lines,
  );

  return files
      .map((file) => p.posix.normalize(file.trim().replaceAll('\\', '/')))
      .where((file) => file.isNotEmpty)
      .toSet();
}

List<_PackageSelection> _buildSelections({
  required Set<String> changedFiles,
  required List<_PackageInfo> workspacePackages,
}) {
  final selectionsByPackage = <String, _PackageSelection>{};

  for (final file in changedFiles.toList()..sort()) {
    final package = _findOwningPackage(file, workspacePackages);
    if (package == null) {
      continue;
    }

    final selection = selectionsByPackage.putIfAbsent(
      package.relativePath,
      () => _PackageSelection(package: package),
    );

    final packageRelativePath = p.posix.relative(
      file,
      from: package.relativePath,
    );
    final basename = p.posix.basename(packageRelativePath);

    if (_packageConfigFiles.contains(basename)) {
      selection.analyzeWholePackage = true;
      continue;
    }

    if (!packageRelativePath.endsWith('.dart')) {
      continue;
    }

    final absoluteFilePath = p.join(
      package.absolutePath,
      packageRelativePath.replaceAll('/', p.separator),
    );
    if (!File(absoluteFilePath).existsSync()) {
      continue;
    }

    selection.files.add(packageRelativePath.replaceAll('/', p.separator));
  }

  final selections =
      selectionsByPackage.values
          .where(
            (selection) =>
                selection.analyzeWholePackage || selection.files.isNotEmpty,
          )
          .toList()
        ..sort(
          (a, b) => a.package.relativePath.compareTo(b.package.relativePath),
        );

  return selections;
}

_PackageInfo? _findOwningPackage(
  String changedFile,
  List<_PackageInfo> workspacePackages,
) {
  _PackageInfo? bestMatch;

  for (final package in workspacePackages) {
    if (changedFile == package.relativePath ||
        changedFile.startsWith('${package.relativePath}/')) {
      if (bestMatch == null ||
          package.relativePath.length > bestMatch.relativePath.length) {
        bestMatch = package;
      }
    }
  }

  return bestMatch;
}

Future<int> _runProcess({
  required String executable,
  required List<String> arguments,
  required String workingDirectory,
}) async {
  final resolvedExecutable = Platform.isWindows
      ? executable == 'flutter'
            ? 'flutter.bat'
            : executable == 'dart'
            ? 'dart.bat'
            : executable
      : executable;
  final process = await Process.start(
    resolvedExecutable,
    arguments,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.inheritStdio,
  );

  return process.exitCode;
}

_GitResult _runGitCommand(List<String> arguments) {
  final result = Process.runSync(
    'git',
    arguments,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );

  if (result.exitCode != 0) {
    return _GitResult(exitCode: result.exitCode, lines: const []);
  }

  final stdoutText = (result.stdout as String).trim();
  if (stdoutText.isEmpty) {
    return _GitResult(exitCode: result.exitCode, lines: const []);
  }

  return _GitResult(
    exitCode: result.exitCode,
    lines: const LineSplitter().convert(stdoutText),
  );
}

class _GitResult {
  const _GitResult({required this.exitCode, required this.lines});

  final int exitCode;
  final List<String> lines;
}

class _PackageInfo {
  const _PackageInfo({
    required this.name,
    required this.relativePath,
    required this.absolutePath,
    required this.isFlutter,
  });

  final String name;
  final String relativePath;
  final String absolutePath;
  final bool isFlutter;
}

class _PackageSelection {
  _PackageSelection({required this.package});

  final _PackageInfo package;
  final Set<String> files = <String>{};
  bool analyzeWholePackage = false;
}
