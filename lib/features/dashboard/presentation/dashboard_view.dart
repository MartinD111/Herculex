import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../theme/colors.dart';
import '../../../widgets/glass_container.dart';
import '../../../data/sync/sync_engine.dart';
import '../../nutrition/domain/daily_totals.dart';
import '../../nutrition/domain/macro_targets.dart';
import '../../nutrition/presentation/nutrition_providers.dart';
import '../../fasting/presentation/fasting_providers.dart';
import '../../fasting/presentation/fasting_bottom_sheet.dart';
import '../../profile/domain/profile.dart';



class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).asData?.value;
    final greeting = _greeting();
    final name = user?.displayName ?? 'there';
    final today = DateFormat('MMM d, yyyy').format(DateTime.now()).toUpperCase();
    final profile = ref.watch(profileProvider).valueOrNull;
    final isFemale = profile?.sex == BiologicalSex.female;
    final syncStatus = ref.watch(syncStatusProvider).valueOrNull ?? SyncStatus.idle;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme, greeting, name, today, syncStatus),
              const SizedBox(height: 32),
              _buildFastingWidget(theme, ref, context),
              const SizedBox(height: 24),
              _LiveMacrosGrid(
                totals: ref.watch(dailyTotalsProvider(_today())).asData?.value ?? DailyTotals.empty,
                targets: ref.watch(macroTargetsProvider),
              ),
              const SizedBox(height: 24),
              _buildImageBanner(theme),
              const SizedBox(height: 24),
              if (isFemale) ...[
                _buildCycleCard(theme),
                const SizedBox(height: 24),
              ],
              _buildTodaysPlan(theme),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildHeader(ThemeData theme, String greeting, String name, String today, SyncStatus syncStatus) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("$greeting, $name", style: theme.textTheme.displayMedium),
              const SizedBox(height: 4),
              Text("Ready to align your day with your goals?", style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              _buildSyncStatusBadge(theme, syncStatus),
            ],
          ),
        ),
        Text(
          today,
          style: theme.textTheme.labelLarge?.copyWith(
            color: AppColors.primary,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSyncStatusBadge(ThemeData theme, SyncStatus status) {
    final IconData icon = switch (status) {
      SyncStatus.syncing => Icons.sync,
      SyncStatus.synced => Icons.check_circle_outline,
      SyncStatus.error => Icons.cloud_off,
      SyncStatus.idle => Icons.cloud_done_outlined,
    };

    final Color color = switch (status) {
      SyncStatus.syncing => Colors.orangeAccent,
      SyncStatus.synced => Colors.green,
      SyncStatus.error => Colors.redAccent,
      SyncStatus.idle => AppColors.primary.withValues(alpha: 0.6),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFastingWidget(ThemeData theme, WidgetRef ref, BuildContext context) {
    final activeAsync = ref.watch(activeFastingSessionProvider);

    return activeAsync.when(
      data: (active) {
        if (active != null) {
          final tickerAsync = ref.watch(fastingTimerTickerProvider);
          final elapsed = tickerAsync.valueOrNull ?? Duration.zero;
          final target = Duration(seconds: active.targetSeconds);
          final remaining = target - elapsed;
          final isOverTarget = remaining.isNegative;

          final progress = target.inSeconds > 0 ? (elapsed.inSeconds / target.inSeconds).clamp(0.0, 1.0) : 0.0;

          final format = DateFormat('HH:mm');
          final startedStr = format.format(active.startedAt);
          final targetEndStr = format.format(active.startedAt.add(target));

          String durationString(Duration duration) {
            final hours = duration.inHours.abs().toString().padLeft(2, '0');
            final minutes = (duration.inMinutes.abs() % 60).toString().padLeft(2, '0');
            final seconds = (duration.inSeconds.abs() % 60).toString().padLeft(2, '0');
            return "$hours:$minutes:$seconds";
          }

          return InkWell(
            onTap: () => FastingBottomSheet.show(context),
            borderRadius: BorderRadius.circular(28),
            child: GlassContainer(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timelapse, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        isOverTarget ? "FASTING COMPLETE" : "INTERMITTENT FASTING",
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.primary,
                          letterSpacing: 1.2,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 8,
                          backgroundColor: AppColors.surfaceVariant,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            durationString(isOverTarget ? elapsed : remaining),
                            style: theme.textTheme.displayLarge?.copyWith(fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            isOverTarget ? "ELAPSED" : "REMAINING",
                            style: theme.textTheme.labelSmall?.copyWith(color: AppColors.secondary, letterSpacing: 1.0),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("STARTED", style: theme.textTheme.labelSmall?.copyWith(color: AppColors.secondary, fontSize: 10)),
                          Text(startedStr, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("TARGET END", style: theme.textTheme.labelSmall?.copyWith(color: AppColors.secondary, fontSize: 10)),
                          Text(targetEndStr, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        } else {
          return InkWell(
            onTap: () => FastingBottomSheet.show(context),
            borderRadius: BorderRadius.circular(28),
            child: GlassContainer(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timelapse, color: AppColors.secondary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "INTERMITTENT FASTING",
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.secondary,
                          letterSpacing: 1.2,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "No Active Fast",
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Track your fasting windows to align nutrition, metabolic health, and muscle recovery.",
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.secondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "START FASTING",
                      style: theme.textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
      loading: () => const GlassContainer(
        padding: EdgeInsets.all(32),
        child: SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (err, stack) => GlassContainer(
        padding: const EdgeInsets.all(32),
        child: SizedBox(
          height: 160,
          child: Center(child: Text("Error: $err")),
        ),
      ),
    );
  }

  DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  // ignore: unused_element
  Widget _legacyMacroCard(String title, IconData icon, String current, String total, double progress, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: theme.textTheme.labelSmall?.copyWith(color: AppColors.secondary, letterSpacing: 1.0)),
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
                  Text(current, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Text(total, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary)),
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

  Widget _buildImageBanner(ThemeData theme) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
        color: AppColors.surfaceContainer,
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "NEW PROGRAM",
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                ),
                const SizedBox(height: 8),
                const Text("Core & Flow", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const Text("15 min mobility routine", style: TextStyle(color: Colors.white70)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCycleCard(ThemeData theme) {
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
                Text("Luteal Phase Focus", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  "Your energy naturally dips this week. Prioritize steady-state cardio and complex carbs over high-intensity intervals.",
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysPlan(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Today's Plan", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Icon(Icons.add, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 24),
          _buildTaskItem("Morning Hydration", "500ml water + electrolytes", "07:00", true, false, theme),
          const Divider(height: 32),
          _buildTaskItem("Break Fast", "High protein, moderate fat", "12:00", false, true, theme),
          const Divider(height: 32),
          _buildTaskItem("Lower Body Strength", "45 min • Medium Intensity", "17:30", false, false, theme),
          const Divider(height: 32),
          _buildTaskItem("Collagen & Wind Down", "Herculex Collagen blend", "21:00", false, false, theme),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF121212),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {},
              child: const Text("VIEW FULL WEEK", style: TextStyle(letterSpacing: 2.0)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTaskItem(String title, String subtitle, String time, bool isCompleted, bool isActive, ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isCompleted ? AppColors.primary : Colors.transparent,
            border: Border.all(
              color: isCompleted ? AppColors.primary : (isActive ? AppColors.primary : AppColors.outline),
              width: isActive ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: isCompleted ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  color: isCompleted ? AppColors.secondary : AppColors.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
        Text(
          time,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? AppColors.primary : AppColors.secondary,
          ),
        ),
      ],
    );
  }
}

class _LiveMacrosGrid extends StatelessWidget {
  final DailyTotals totals;
  final MacroTargets? targets;
  const _LiveMacrosGrid({required this.totals, required this.targets});

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
        _card(theme, 'CALORIES', Icons.local_fire_department,
            current: totals.kcal.round().toString(),
            total: t == null ? '' : '/ ${t.kcal}',
            progress: t == null ? null : (totals.kcal / t.kcal).clamp(0.0, 1.0),
            color: AppColors.primary),
        _card(theme, 'PROTEIN', Icons.egg_alt,
            current: '${totals.proteinG.round()}g',
            total: t == null ? '' : '/ ${t.proteinG}g',
            progress: t == null ? null : (totals.proteinG / t.proteinG).clamp(0.0, 1.0),
            color: AppColors.earthBrown),
        _card(theme, 'CARBS', Icons.bakery_dining,
            current: '${totals.carbsG.round()}g',
            total: t == null ? '' : '/ ${t.carbsG}g',
            progress: t == null ? null : (totals.carbsG / t.carbsG).clamp(0.0, 1.0),
            color: AppColors.outline),
        _card(theme, 'FATS', Icons.water_drop,
            current: '${totals.fatG.round()}g',
            total: t == null ? '' : '/ ${t.fatG}g',
            progress: t == null ? null : (totals.fatG / t.fatG).clamp(0.0, 1.0),
            color: AppColors.tertiary),
      ],
    );
  }

  Widget _card(
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
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: theme.textTheme.labelSmall?.copyWith(color: AppColors.secondary, letterSpacing: 1.0)),
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
                  Text(current, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Text(total, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary)),
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
