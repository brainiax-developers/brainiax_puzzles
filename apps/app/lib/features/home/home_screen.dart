import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Puzzle Home')),
      body: ListView(
        children: [
          ListTile(title: const Text('Daily Challenge'), onTap: () => context.go('/daily')),
          ListTile(title: const Text('Puzzles'), onTap: () => context.go('/puzzles')),
          ListTile(title: const Text('Profile/Stats'), onTap: () => context.go('/profile')),
          ListTile(title: const Text('Settings'), onTap: () => context.go('/settings')),
        ],
      ),
    );
  }
}
