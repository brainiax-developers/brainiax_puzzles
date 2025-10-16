import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tapCount = 0;
  DateTime? _lastTapTime;

  void _onTitleTap() {
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!).inSeconds < 2) {
      _tapCount++;
    } else {
      _tapCount = 1;
    }
    _lastTapTime = now;

    if (_tapCount >= 5) {
      _tapCount = 0;
      context.push('/bench');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _onTitleTap,
          child: const Text('Puzzle Home'),
        ),
      ),
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
