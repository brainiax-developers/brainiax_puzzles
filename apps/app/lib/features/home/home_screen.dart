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
          ListTile(title: const Text('Daily Challenge'), onTap: () => context.push('/daily')),
          ListTile(title: const Text('Puzzles'), onTap: () => context.push('/puzzles')),
          ListTile(title: const Text('Profile/Stats'), onTap: () => context.push('/profile')),
          ListTile(title: const Text('Settings'), onTap: () => context.push('/settings')),
        ],
      ),
    );
  }
}
