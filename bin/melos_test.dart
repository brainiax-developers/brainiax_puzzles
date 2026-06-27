#!/usr/bin/env dart

import 'dart:io';

import '_workspace_validation.dart';

Future<void> main(List<String> args) async {
  final diffRange = resolveDiffRange(
    args,
    environmentKeys: const ['MELOS_TEST_DIFF', 'MELOS_ANALYZE_DIFF'],
  );
  final workspacePackages = readWorkspacePackages();
  final changedFiles = collectChangedFiles(diffRange: diffRange);
  final selections = _buildSelections(
    changedFiles: changedFiles,
    workspacePackages: workspacePackages,
  );

  if (selections.isEmpty) {
    stdout.writeln(
      'No changed workspace tests detected; skipping test execution.',
    );
    return;
  }

  var hasFailures = false;

  for (final selection in selections) {
    final arguments = <String>[
      'test',
      if (selection.package.isFlutter) '--no-pub',
      ...selection.files,
    ];

    stdout.writeln(
      'Testing ${selection.package.name} (${selection.files.length} files)...',
    );

    final exitCode = await runPackageProcess(
      package: selection.package,
      arguments: arguments,
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
    final relativePath = relativePathWithinPackage(package, file);

    if (!isDartFile(relativePath)) {
      continue;
    }

    final absolutePath =
        '${package.absolutePath}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}';
    if (!File(absolutePath).existsSync()) {
      continue;
    }

    if (isTestFile(relativePath) && _looksLikeRunnableTest(relativePath)) {
      selection.files.add(relativePath.replaceAll('/', Platform.pathSeparator));
      continue;
    }

    if (relativePath.startsWith('test/') ||
        relativePath.startsWith('integration_test/')) {
      selection.helperDirectories.add(_normalizedDirectory(relativePath));
      continue;
    }

    selection.sourceStems.add(basenameStem(relativePath));
  }

  for (final selection in selectionsByPackage.values) {
    final availableTests = _listRunnableTests(selection.package);
    if (availableTests.isEmpty) {
      continue;
    }

    for (final helperDirectory in selection.helperDirectories) {
      for (final testFile in availableTests) {
        if (testFile.startsWith(helperDirectory)) {
          selection.files.add(testFile.replaceAll('/', Platform.pathSeparator));
        }
      }
    }

    for (final sourceStem in selection.sourceStems) {
      for (final testFile in availableTests) {
        final testStem = basenameStem(testFile);
        if (testStem == '${sourceStem}_test' ||
            testStem.startsWith('${sourceStem}_') ||
            testStem == sourceStem) {
          selection.files.add(testFile.replaceAll('/', Platform.pathSeparator));
        }
      }
    }
  }

  return selectionsByPackage.values
      .where((selection) => selection.files.isNotEmpty)
      .toList()
    ..sort((a, b) => a.package.relativePath.compareTo(b.package.relativePath));
}

List<String> _listRunnableTests(WorkspacePackage package) {
  final files = <String>[
    ...listPackageFiles(package, relativeDirectory: 'test'),
    ...listPackageFiles(package, relativeDirectory: 'integration_test'),
  ];

  return files.where(_looksLikeRunnableTest).toList()..sort();
}

bool _looksLikeRunnableTest(String relativePath) {
  return isTestFile(relativePath) && relativePath.endsWith('_test.dart');
}

String _normalizedDirectory(String path) {
  final directory = path.replaceAll('\\', '/');
  final slashIndex = directory.lastIndexOf('/');
  if (slashIndex == -1) {
    return '';
  }

  return directory.substring(0, slashIndex + 1);
}

class _PackageSelection {
  _PackageSelection({required this.package});

  final WorkspacePackage package;
  final Set<String> files = <String>{};
  final Set<String> helperDirectories = <String>{};
  final Set<String> sourceStems = <String>{};
}
