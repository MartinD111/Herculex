import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/nutrition/presentation/nutrition_providers.dart';
import '../features/workouts/presentation/workouts_providers.dart';
import '../services/workout_notification_service.dart';
import '../theme/app_theme.dart';
import 'router.dart';

class HerculexApp extends ConsumerStatefulWidget {
  const HerculexApp({super.key});

  @override
  ConsumerState<HerculexApp> createState() => _HerculexAppState();
}

class _HerculexAppState extends ConsumerState<HerculexApp> {
  late final AppLifecycleListener _lifecycleListener;
  bool _inBackground = false;

  @override
  void initState() {
    super.initState();
    WorkoutNotificationService.instance.init();

    _lifecycleListener = AppLifecycleListener(
      onHide: _onBackground,
      onPause: _onBackground,
      onInactive: _onBackground,
      onResume: _onForeground,
      onShow: _onForeground,
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    WorkoutNotificationService.instance.cancel();
    super.dispose();
  }

  void _onBackground() {
    _inBackground = true;
    _syncNotification();
  }

  void _onForeground() {
    _inBackground = false;
    WorkoutNotificationService.instance.cancel();
  }

  void _syncNotification() {
    if (!_inBackground) return;
    final sessionAsync = ref.read(activeSessionProvider);
    final session = sessionAsync.asData?.value;
    if (session == null) {
      WorkoutNotificationService.instance.cancel();
      return;
    }
    // Resolve first exercise name for the notification subtitle.
    final exercises =
        ref.read(sessionExercisesProvider(session.id)).asData?.value ?? [];
    String exerciseName = 'Workout in progress';
    if (exercises.isNotEmpty) {
      final catalog =
          ref.read(exerciseCatalogProvider(null)).asData?.value ?? [];
      final match = catalog
          .where((e) => e.id == exercises.first.exerciseId)
          .firstOrNull;
      if (match != null) exerciseName = match.name;
    }
    WorkoutNotificationService.instance.showOrUpdate(
      startedAt: session.startedAt,
      exerciseName: exerciseName,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Initialize wear sync listening.
    ref.watch(wearSyncControllerProvider);

    // When backgrounded, keep notification in sync if session starts/ends.
    ref.listen(activeSessionProvider, (_, next) {
      if (_inBackground) _syncNotification();
    });

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
