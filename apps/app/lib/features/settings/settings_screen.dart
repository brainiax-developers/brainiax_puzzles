// apps/app/lib/features/settings/settings_screen.dart
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: const [
          _ContrastTile(),
          // TODO: add toggles bound to feature flags if desired
        ],
      ),
    );
  }
}

class _ContrastTile extends StatefulWidget {
  const _ContrastTile();

  @override
  State<_ContrastTile> createState() => _ContrastTileState();
}

class _ContrastTileState extends State<_ContrastTile> {
  bool high = false;
  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('High contrast'),
      value: high,
      onChanged: (v) => setState(() => high = v),
    );
  }
}
