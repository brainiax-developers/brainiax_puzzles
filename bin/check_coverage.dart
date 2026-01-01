#!/usr/bin/env dart

import 'dart:io';

void main(List<String> args) {
  final double threshold = args.length > 1 ? double.parse(args[1]) : 0.8;
  final String path = args.isNotEmpty ? args.first : 'coverage/lcov.info';

  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Coverage file not found: $path');
    exit(1);
  }

  final lines = file.readAsLinesSync();
  int totalFound = 0;
  int totalHit = 0;

  for (final line in lines) {
    if (line.startsWith('LF:')) {
      totalFound += int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      totalHit += int.parse(line.substring(3));
    }
  }

  if (totalFound == 0) {
    stderr.writeln('No coverage data found in $path');
    exit(1);
  }

  final coverage = totalHit / totalFound;
  stdout.writeln('Coverage: ${(coverage * 100).toStringAsFixed(2)}%');

  if (coverage < threshold) {
    stderr.writeln('Coverage below threshold (${threshold * 100}%).');
    exit(1);
  }
}
