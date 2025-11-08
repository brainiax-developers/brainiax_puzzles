import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PuzzlesListScreen extends StatelessWidget {
  const PuzzlesListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final types = [
      'sudoku','nonogram','mathdoku','killerQueens','slitherlink','kakuro','takuzu',
      'crosswordMini','wordSearch','anagram','cryptogram','wordLadder'
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Puzzles')),
      body: ListView.builder(
        itemCount: types.length,
        itemBuilder: (_, i) => ListTile(
          title: Text(types[i]),
          onTap: () => context.push('/play/${types[i]}'),
        ),
      ),
    );
  }
}
