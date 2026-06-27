import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

const packageConfigFiles = {'analysis_options.yaml', 'pubspec.yaml'};

String? resolveDiffRange(
  List<String> args, {
  List<String> environmentKeys = const [],
}) {
  for (final key in environmentKeys) {
    final envValue = Platform.environment[key]?.trim();
    if (envValue != null && envValue.isNotEmpty) {
      return envValue;
    }
  }

  if (args.isNotEmpty) {
    final candidate = args.first.trim();
    if (candidate.isNotEmpty) {
      return candidate;
    }
  }

  final hasMain =
      runGitCommand(['rev-parse', '--verify', 'main']).exitCode == 0;
  if (!hasMain) {
    return null;
  }

  return 'main...HEAD';
}

List<WorkspacePackage> readWorkspacePackages() {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('Workspace pubspec.yaml not found.');
    exit(1);
  }

  final lines = pubspec.readAsLinesSync();
  final packages = <WorkspacePackage>[];
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
        WorkspacePackage(
          name: readPackageName(packagePubspec) ?? p.basename(relativePath),
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

String? readPackageName(File pubspec) {
  for (final line in pubspec.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.startsWith('name:')) {
      return trimmed.substring('name:'.length).trim();
    }
  }

  return null;
}

Set<String> collectChangedFiles({String? diffRange}) {
  final files = <String>{};

  if (diffRange != null) {
    files.addAll(
      runGitCommand([
        'diff',
        '--name-only',
        '--diff-filter=ACMRD',
        diffRange,
      ]).lines,
    );
  }

  files.addAll(
    runGitCommand(['diff', '--name-only', '--diff-filter=ACMRD']).lines,
  );
  files.addAll(
    runGitCommand([
      'diff',
      '--cached',
      '--name-only',
      '--diff-filter=ACMRD',
    ]).lines,
  );
  files.addAll(
    runGitCommand(['ls-files', '--others', '--exclude-standard']).lines,
  );

  return files
      .map((file) => p.posix.normalize(file.trim().replaceAll('\\', '/')))
      .where((file) => file.isNotEmpty)
      .toSet();
}

WorkspacePackage? findOwningPackage(
  String changedFile,
  List<WorkspacePackage> workspacePackages,
) {
  WorkspacePackage? bestMatch;

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

String relativePathWithinPackage(
  WorkspacePackage package,
  String workspacePath,
) {
  return p.posix.relative(workspacePath, from: package.relativePath);
}

bool isDartFile(String path) => path.endsWith('.dart');

bool isTestFile(String path) {
  if (!path.endsWith('.dart')) {
    return false;
  }

  return path.startsWith('test/') || path.startsWith('integration_test/');
}

String basenameStem(String path) => p.posix.basenameWithoutExtension(path);

List<String> listPackageFiles(
  WorkspacePackage package, {
  required String relativeDirectory,
}) {
  final directory = Directory(
    p.join(
      package.absolutePath,
      relativeDirectory.replaceAll('/', p.separator),
    ),
  );
  if (!directory.existsSync()) {
    return const [];
  }

  return directory
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .map((file) => p.relative(file.path, from: package.absolutePath))
      .map((file) => p.posix.normalize(file.replaceAll('\\', '/')))
      .toList();
}

Future<int> runPackageProcess({
  required WorkspacePackage package,
  required List<String> arguments,
}) {
  final executable = package.isFlutter ? 'flutter' : 'dart';
  return runProcess(
    executable: executable,
    arguments: arguments,
    workingDirectory: package.absolutePath,
  );
}

Future<int> runProcess({
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

GitResult runGitCommand(List<String> arguments) {
  final result = Process.runSync(
    'git',
    arguments,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );

  if (result.exitCode != 0) {
    return GitResult(exitCode: result.exitCode, lines: const []);
  }

  final stdoutText = (result.stdout as String).trim();
  if (stdoutText.isEmpty) {
    return GitResult(exitCode: result.exitCode, lines: const []);
  }

  return GitResult(
    exitCode: result.exitCode,
    lines: const LineSplitter().convert(stdoutText),
  );
}

class GitResult {
  const GitResult({required this.exitCode, required this.lines});

  final int exitCode;
  final List<String> lines;
}

class WorkspacePackage {
  const WorkspacePackage({
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
