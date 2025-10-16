import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_router.dart';
import 'shared/firebase/firebase_init.dart';
import 'shared/firebase/auth_glue.dart';
import 'shared/theme/app_theme.dart';
import 'shared/services/engine_registry_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Run initialization with overall timeout to prevent long waits
    await Future.wait([
      _initializeApp(),
    ]).timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        if (kDebugMode) {
          print('⚠️ App initialization timeout - launching with minimal config');
        }
        throw TimeoutException('App initialization timeout', const Duration(seconds: 8));
      },
    );
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ App initialization failed: $e');
      print('📱 Launching app with minimal configuration');
    }
    // Continue with app launch even if initialization fails
  }

  // 4) Launch app
  runApp(const ProviderScope(child: BrainiaxApp()));
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
  
  // 2) Ensure an anonymous user (depends on Firebase)
  await ensureAnonAuth();

  final initDuration = DateTime.now().difference(initStartTime);
  if (kDebugMode) {
    print('✅ App initialization completed in ${initDuration.inMilliseconds}ms');
  }
}

class BrainiaxApp extends StatelessWidget {
  const BrainiaxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Brainiax Puzzles',
      debugShowCheckedModeBanner: false,

      // add these two lines if you want to use your custom theme
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
        
      routeInformationProvider: appRouter.routeInformationProvider,
      routeInformationParser: appRouter.routeInformationParser,
      routerDelegate: appRouter.routerDelegate,
    );
  }
}
