import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import 'router.dart';

import '../features/nutrition/presentation/nutrition_providers.dart';

class HerculexApp extends ConsumerWidget {
  const HerculexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize wear sync listening
    ref.watch(wearSyncControllerProvider);
    
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Herculex',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
