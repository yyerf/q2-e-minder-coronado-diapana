import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/app_providers.dart';
// import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (commented out for now)
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );
  
  // Initialize Hive for local storage
  await Hive.initFlutter();
  
  // Initialize app configuration
  await AppConfig.initialize();
  
  runApp(
    const ProviderScope(
      child: IoTEWasteApp(),
    ),
  );
}

class IoTEWasteApp extends ConsumerWidget {
  const IoTEWasteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'IoT E-Waste Monitor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
