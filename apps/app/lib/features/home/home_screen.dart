import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/widgets.dart';

const String _appFlavor = String.fromEnvironment('APP_FLAVOR', defaultValue: 'prod');
bool get _isProdFlavor => _appFlavor == 'prod';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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

    if (_tapCount >= 5 && !_isProdFlavor) {
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
        padding: const EdgeInsets.all(16),
        children: [
          // Daily Challenge Surface
          const DailySurface(),
          const SizedBox(height: 24),
          
          // Menu Items
          _buildMenuSection(),
        ],
      ),
    );
  }

  Widget _buildMenuSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Menu',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        _buildMenuTile(
          icon: Icons.extension,
          title: 'Puzzles',
          subtitle: 'Browse all puzzle types',
          onTap: () => context.push('/puzzles'),
        ),
        _buildMenuTile(
          icon: Icons.person,
          title: 'Profile/Stats',
          subtitle: 'Coming soon',
          onTap: null,
          isDisabled: true,
        ),
        _buildMenuTile(
          icon: Icons.settings,
          title: 'Settings',
          subtitle: 'App preferences',
          onTap: () => context.push('/settings'),
        ),
      ],
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool isDisabled = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDisabled
              ? colorScheme.onSurface.withOpacity(0.4)
              : colorScheme.primary,
        ),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: isDisabled
                ? colorScheme.onSurface.withOpacity(0.6)
                : null,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDisabled
                ? colorScheme.onSurface.withOpacity(0.5)
                : colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: colorScheme.onSurface.withOpacity(
            isDisabled ? 0.2 : 0.5,
          ),
        ),
        onTap: isDisabled ? null : onTap,
      ),
    );
  }
}
