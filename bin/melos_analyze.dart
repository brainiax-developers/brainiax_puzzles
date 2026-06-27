#!/usr/bin/env dart

import 'dart:io';

import '_workspace_validation.dart';

Future<void> main(List<String> args) async {
  final diffRange = resolveDiffRange(
    args,
    environmentKeys: const ['MELOS_ANALYZE_DIFF'],
  );
  final workspacePackages = readWorkspacePackages();
  final changedFiles = collectChangedFiles(diffRange: diffRange);
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

    arguments.addAll(selection.files);

    stdout.writeln(
      'Analyzing ${selection.package.name} (${selection.files.length} files)...',
    );

    final exitCode = await runProcess(
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

List<_PackageSelection> _buildSelections({
  required Set<String> changedFiles,
  required List<WorkspacePackage> workspacePackages,
}) {
  final selectionsByPackage = <String, _PackageSelection>{};

  for (final file in changedFiles.toList()..sort()) {
    final package = findOwningPackage(file, workspacePackages);
    if (package == null) {
      continue;
    }

    final selection = selectionsByPackage.putIfAbsent(
      package.relativePath,
      () => _PackageSelection(package: package),
    );

    final packageRelativeFile = relativePathWithinPackage(package, file);
    final basename = packageRelativeFile.split('/').last;

    if (packageConfigFiles.contains(basename)) {
      continue;
    }

    if (!isDartFile(packageRelativeFile)) {
      continue;
    }

    final absoluteFilePath =
        '${package.absolutePath}${Platform.pathSeparator}${packageRelativeFile.replaceAll('/', Platform.pathSeparator)}';
    if (!File(absoluteFilePath).existsSync()) {
      continue;
    }

    selection.files.add(
      packageRelativeFile.replaceAll('/', Platform.pathSeparator),
    );
  }

  final selections =
      selectionsByPackage.values
          .where((selection) => selection.files.isNotEmpty)
          .toList()
        ..sort(
          (a, b) => a.package.relativePath.compareTo(b.package.relativePath),
        );

  return selections;
}

class _PackageSelection {
  _PackageSelection({required this.package});

  final WorkspacePackage package;
  final Set<String> files = <String>{};
}
