import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_router.dart';
import 'shared/firebase/firebase_init.dart';
import 'shared/firebase/auth_glue.dart';
import 'shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Initialize Firebase
  await initFirebase();

  // 2) Ensure an anonymous user
  await ensureAnonAuth();

  // 3) Launch app
  runApp(const ProviderScope(child: BrainiaxApp()));
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
