import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_router.dart';
import 'shared/auth/auth_providers.dart';
import 'shared/firebase/firebase_init.dart';
import 'shared/theme/app_theme.dart';
import 'shared/services/engine_registry_service.dart';
import 'shared/providers/simple_theme_provider.dart';
import 'shared/services/snack_bar_service.dart';
// Preloading disabled: puzzles will be generated on demand only

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Run initialization with overall timeout to prevent long waits
    await Future.wait([_initializeApp()]).timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        if (kDebugMode) {
          print(
            '⚠️ App initialization timeout - launching with minimal config',
          );
        }
        throw TimeoutException(
          'App initialization timeout',
          const Duration(seconds: 8),
        );
      },
    );
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ App initialization failed: $e');
      print('📱 Launching app with minimal configuration');
    }
    // Continue with app launch even if initialization fails
  }

  final container = ProviderContainer();
  unawaited(
    container
        .read(authBootstrapControllerProvider.notifier)
        .bootstrapAnonymousSignIn(),
  );

  // 4) Launch app
  runApp(
    UncontrolledProviderScope(container: container, child: const BrainiaxApp()),
  );
}

Future<void> _initializeApp() async {
  // Run initialization steps in parallel for faster startup
  final initStartTime = DateTime.now();

  // 1) Initialize Firebase and engines in parallel
  final futures = <Future>[
    initFirebase(),
    EngineRegistryService().initialize(),
  ];

  await Future.wait(futures);

  final initDuration = DateTime.now().difference(initStartTime);
  if (kDebugMode) {
    print('✅ App initialization completed in ${initDuration.inMilliseconds}ms');
  }
}

class BrainiaxApp extends ConsumerStatefulWidget {
  const BrainiaxApp({super.key});

  @override
  ConsumerState<BrainiaxApp> createState() => _BrainiaxAppState();
}

class _BrainiaxAppState extends ConsumerState<BrainiaxApp> {
  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(currentThemeProvider);
    final themeStateAsync = ref.watch(themeStateProvider);
    final snackBar = ref.watch(snackBarServiceProvider);

    return MaterialApp.router(
      title: 'Brainiax Puzzles',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: snackBar.scaffoldMessengerKey,

      // Use dynamic theme from provider
      theme: themeStateAsync.when(
        data: (state) => state.effectiveMode == AppThemeMode.light
            ? currentTheme
            : AppTheme.light(),
        loading: () => AppTheme.light(),
        error: (error, stackTrace) => AppTheme.light(),
      ),
      darkTheme: themeStateAsync.when(
        data: (state) => state.effectiveMode == AppThemeMode.dark
            ? currentTheme
            : AppTheme.dark(),
        loading: () => AppTheme.dark(),
        error: (error, stackTrace) => AppTheme.dark(),
      ),
      themeMode: themeStateAsync.when(
        data: (state) => state.mode == AppThemeMode.system
            ? ThemeMode.system
            : (state.effectiveMode == AppThemeMode.dark
                  ? ThemeMode.dark
                  : ThemeMode.light),
        loading: () => ThemeMode.system,
        error: (error, stackTrace) => ThemeMode.system,
      ),

      routeInformationProvider: appRouter.routeInformationProvider,
      routeInformationParser: appRouter.routeInformationParser,
      routerDelegate: appRouter.routerDelegate,
    );
  }
}
