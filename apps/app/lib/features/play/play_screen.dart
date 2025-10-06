import 'dart:math';
import 'package:flutter/material.dart';

class PlayScreen extends StatelessWidget {
  final String type;
  const PlayScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final seed = Random().nextInt(1 << 31);
    return Scaffold(
      appBar: AppBar(title: Text('Play: $type')),
      body: Center(child: Text('Placeholder board • seed=$seed')),
    );
  }
}
