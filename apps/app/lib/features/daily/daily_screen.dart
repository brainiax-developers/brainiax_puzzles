import 'package:flutter/material.dart';

int dailySeedFor(String type, DateTime date) {
  final d = DateTime.utc(date.year, date.month, date.day);
  return Object.hash(type, d.millisecondsSinceEpoch);
}

class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final type = 'sudoku'; // simple placeholder
    final seed = dailySeedFor(type, today);
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Challenge')),
      body: Center(child: Text('Type=$type • ${today.toIso8601String().substring(0,10)} • seed=$seed')),
    );
  }
}
