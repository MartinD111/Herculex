import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/colors.dart';
import '../../analytics/presentation/analytics_providers.dart';
import '../../gyms/presentation/gym_picker_sheet.dart';
import '../../nutrition/domain/daily_totals.dart';
import '../../nutrition/domain/macro_targets.dart';
import '../../workouts/presentation/workouts_providers.dart';
import 'dashboard_providers.dart';

Widget _card({required Widget child}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: child,
    );

Widget _title(BuildContext context, String text) => Text(text,
    style: Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.bold));

/// Smart workout launcher (§18): reads the day's scheduled workout and offers
/// to start it pre-populated. "Start Leg Day?" → Yes starts a real session.
class SmartWorkoutLauncherCard extends ConsumerWidget {
  const SmartWorkoutLauncherCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = ref.watch(todaysScheduledWorkoutProvider);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(context, "Today's Plan"),
          const SizedBox(height: 12),
          today.when(
            data: (workout) {
              if (workout == null) {
                return Text('No workout scheduled today.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.secondary));
              }
              if (workout.isDone) {
                return Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text('${workout.programDay.name} complete',
                        style: theme.textTheme.titleSmall),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(workout.programDay.name,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text('${workout.exerciseCount} exercises planned',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.secondary)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: Text('Start ${workout.programDay.name}?'),
                      onPressed: () async {
                        final gym =
                            await GymPickerSheet.resolve(context, ref);
                        if (gym.cancelled) return;
                        await ref
                            .read(scheduledWorkoutServiceProvider)
                            .startScheduledWorkout(workout, gymId: gym.gymId);
                        ref.invalidate(todaysScheduledWorkoutProvider);
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

/// Compact recovery overview (§18) reusing the Phase-3 19-group engine: shows
/// the most-fatigued groups.
class RecoverySummaryCard extends ConsumerWidget {
  const RecoverySummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recovery = ref.watch(recoveryV3Provider);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(context, 'Recovery'),
          const SizedBox(height: 12),
          recovery.when(
            data: (groups) {
              final sorted = [...groups]
                ..sort((a, b) => a.recoveryScore.compareTo(b.recoveryScore));
              final worst = sorted.take(4).toList();
              return Column(
                children: [
                  for (final g in worst)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          SizedBox(
                              width: 92,
                              child: Text(g.muscle,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600))),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: g.recoveryScore / 100,
                                minHeight: 8,
                                backgroundColor: AppColors.outlineVariant
                                    .withValues(alpha: 0.2),
                                valueColor: AlwaysStoppedAnimation(
                                  g.recoveryScore >= 70
                                      ? Colors.green
                                      : g.recoveryScore >= 30
                                          ? Colors.amber
                                          : Colors.red,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                              width: 36,
                              child: Text('${g.recoveryScore}',
                                  textAlign: TextAlign.end,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.secondary))),
                        ],
                      ),
                    ),
                ],
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

/// CNS readiness mini-card (§18).
class CnsLoadMiniCard extends ConsumerWidget {
  const CnsLoadMiniCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cns = ref.watch(cnsTrendsProvider);
    return _card(
      child: Row(
        children: [
          Expanded(child: _title(context, 'CNS Load')),
          cns.when(
            data: (t) {
              final color = switch (t.status) {
                'FRESH' => Colors.green,
                'MODERATE' => Colors.amber,
                _ => Colors.red,
              };
              return Row(
                children: [
                  Text('${(t.readiness * 100).round()}%',
                      style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(t.status,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color)),
                  ),
                ],
              );
            },
            loading: () => const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => const Icon(Icons.error_outline, size: 18),
          ),
        ],
      ),
    );
  }
}

/// This week's total tonnage (§18).
class WeeklyVolumeMiniCard extends ConsumerWidget {
  const WeeklyVolumeMiniCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tonnage = ref.watch(weeklyTonnageProvider);
    return _card(
      child: Row(
        children: [
          Expanded(child: _title(context, 'This Week')),
          tonnage.when(
            data: (weeks) {
              final latest = weeks.isEmpty ? 0.0 : weeks.last.tonnageKg;
              return Text('${(latest / 1000).toStringAsFixed(1)} t',
                  style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold, color: AppColors.primary));
            },
            loading: () => const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => const Icon(Icons.error_outline, size: 18),
          ),
        ],
      ),
    );
  }
}

/// Latest estimated 1RM PRs (§18).
class LatestPrsCard extends ConsumerWidget {
  const LatestPrsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prs = ref.watch(topOneRmsProvider);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(context, 'Latest PRs'),
          const SizedBox(height: 12),
          prs.when(
            data: (list) => list.isEmpty
                ? Text('No PRs yet',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.secondary))
                : Column(
                    children: [
                      for (final p in list.take(3))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                  child: Text(p.exerciseName,
                                      style: theme.textTheme.bodyMedium,
                                      overflow: TextOverflow.ellipsis)),
                              Text('${p.estimatedOneRmKg.toStringAsFixed(0)} kg',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary)),
                            ],
                          ),
                        ),
                    ],
                  ),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

/// Latest bodyweight reading (§18).
class BodyweightMiniCard extends ConsumerWidget {
  const BodyweightMiniCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bw = ref.watch(latestBodyweightProvider);
    return _card(
      child: Row(
        children: [
          Expanded(child: _title(context, 'Bodyweight')),
          bw.when(
            data: (kg) => Text(
                kg == null ? '—' : '${kg.toStringAsFixed(1)} kg',
                style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold, color: AppColors.primary)),
            loading: () => const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => const Icon(Icons.error_outline, size: 18),
          ),
        ],
      ),
    );
  }
}

/// Live calorie/macro grid (§18). Pure presentation — totals & targets are
/// resolved by the caller (effective target for the day).
class LiveMacrosGrid extends StatelessWidget {
  final DailyTotals totals;
  final MacroTargets? targets;
  const LiveMacrosGrid({super.key, required this.totals, required this.targets});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = targets;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _macroCard(theme, 'CALORIES', Icons.local_fire_department,
            current: totals.kcal.round().toString(),
            total: t == null ? '' : '/ ${t.kcal}',
            progress: t == null ? null : (totals.kcal / t.kcal).clamp(0.0, 1.0),
            color: AppColors.primary),
        _macroCard(theme, 'PROTEIN', Icons.egg_alt,
            current: '${totals.proteinG.round()}g',
            total: t == null ? '' : '/ ${t.proteinG}g',
            progress: t == null
                ? null
                : (totals.proteinG / t.proteinG).clamp(0.0, 1.0),
            color: AppColors.earthBrown),
        _macroCard(theme, 'CARBS', Icons.bakery_dining,
            current: '${totals.carbsG.round()}g',
            total: t == null ? '' : '/ ${t.carbsG}g',
            progress: t == null
                ? null
                : (totals.carbsG / t.carbsG).clamp(0.0, 1.0),
            color: AppColors.outline),
        _macroCard(theme, 'FATS', Icons.water_drop,
            current: '${totals.fatG.round()}g',
            total: t == null ? '' : '/ ${t.fatG}g',
            progress:
                t == null ? null : (totals.fatG / t.fatG).clamp(0.0, 1.0),
            color: AppColors.tertiary),
      ],
    );
  }

  Widget _macroCard(
    ThemeData theme,
    String title,
    IconData icon, {
    required String current,
    required String total,
    required double? progress,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.secondary, letterSpacing: 1.0)),
              Icon(icon, size: 16, color: AppColors.primary),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(current,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Text(total,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.secondary)),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                borderRadius: BorderRadius.circular(4),
                minHeight: 4,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Cycle-phase focus card (§18). Content is still the Phase-7 placeholder
/// (luteal focus); shown only for female profiles.
class CycleFocusCard extends StatelessWidget {
  const CycleFocusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primaryContainer),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.monitor_heart, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Luteal Phase Focus",
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  "Your energy naturally dips this week. Prioritize steady-state cardio and complex carbs over high-intensity intervals.",
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Edit-mode sheet (§18): toggle widget visibility and drag to reorder.
class DashboardCustomizeSheet extends ConsumerWidget {
  const DashboardCustomizeSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final config = ref.watch(dashboardConfigProvider);
    final notifier = ref.read(dashboardConfigProvider.notifier);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: theme.bottomSheetTheme.backgroundColor ??
              AppColors.surfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Customize Dashboard',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Drag to reorder · toggle to show/hide',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.secondary)),
            const SizedBox(height: 12),
            Expanded(
              child: ReorderableListView(
                scrollController: controller,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                onReorder: notifier.reorder,
                children: [
                  for (final w in config.widgets)
                    Padding(
                      key: ValueKey(w.type.id),
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.drag_handle),
                          title: Text(w.type.label),
                          trailing: Switch.adaptive(
                            value: w.visible,
                            onChanged: (v) => notifier.toggle(w.type, v),
                            activeThumbColor: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
