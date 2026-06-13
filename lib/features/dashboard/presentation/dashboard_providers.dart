import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../workouts/data/scheduled_workout_service.dart';
import '../data/dashboard_config_repository.dart';
import '../domain/dashboard_config.dart';

final dashboardConfigRepositoryProvider =
    Provider<DashboardConfigRepository>((ref) {
  return DashboardConfigRepository(ref.watch(sharedPreferencesProvider));
});

/// Editable dashboard layout (§18). Loaded from prefs; mutations persist
/// immediately and re-emit so the dashboard rebuilds live.
class DashboardConfigNotifier extends Notifier<DashboardConfig> {
  @override
  DashboardConfig build() {
    return ref.watch(dashboardConfigRepositoryProvider).load();
  }

  void toggle(DashboardWidgetType type, bool visible) {
    state = state.toggle(type, visible);
    ref.read(dashboardConfigRepositoryProvider).save(state);
  }

  void reorder(int oldIndex, int newIndex) {
    state = state.reorder(oldIndex, newIndex);
    ref.read(dashboardConfigRepositoryProvider).save(state);
  }
}

final dashboardConfigProvider =
    NotifierProvider<DashboardConfigNotifier, DashboardConfig>(
        DashboardConfigNotifier.new);

final scheduledWorkoutServiceProvider =
    Provider<ScheduledWorkoutService>((ref) {
  return ScheduledWorkoutService(
      ref.watch(appDatabaseProvider), ref.watch(clockProvider));
});

/// Today's scheduled workout for the smart launcher (§18). Refreshes when the
/// active workout session changes (so a completed schedule updates).
final todaysScheduledWorkoutProvider =
    FutureProvider<TodaysScheduledWorkout?>((ref) {
  return ref.watch(scheduledWorkoutServiceProvider).todaysWorkout();
});
