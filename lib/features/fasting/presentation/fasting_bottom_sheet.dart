import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../theme/colors.dart';
import '../../../widgets/glass_container.dart';
import '../../../widgets/premium_button.dart';
import '../domain/fasting_plan.dart';
import 'fasting_providers.dart';

class FastingBottomSheet extends ConsumerStatefulWidget {
  const FastingBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FastingBottomSheet(),
    );
  }

  @override
  ConsumerState<FastingBottomSheet> createState() => _FastingBottomSheetState();
}

class _FastingBottomSheetState extends ConsumerState<FastingBottomSheet> {
  FastingPlan _selectedPlan = FastingPlan.h16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeAsync = ref.watch(activeFastingSessionProvider);
    final historyAsync = ref.watch(fastingHistoryProvider);
    final streakAsync = ref.watch(fastingStreakProvider);
    final avgEatingAsync = ref.watch(fastingAverageEatingWindowProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Grabber/Handle
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    activeAsync.when(
                      data: (active) {
                        if (active != null) {
                          return _buildActiveFastView(theme, active);
                        } else {
                          return _buildStartFastView(theme);
                        }
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (err, stack) => Center(child: Text('Error: $err')),
                    ),
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 24),
                    _buildInsightsSection(theme, streakAsync, avgEatingAsync),
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 24),
                    _buildHistorySection(theme, historyAsync),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveFastView(ThemeData theme, dynamic active) {
    final tickerAsync = ref.watch(fastingTimerTickerProvider);
    final elapsed = tickerAsync.valueOrNull ?? Duration.zero;
    final target = Duration(seconds: active.targetSeconds);
    final remaining = target - elapsed;
    final isOverTarget = remaining.isNegative;

    final progress = target.inSeconds > 0 ? (elapsed.inSeconds / target.inSeconds).clamp(0.0, 1.0) : 0.0;

    final format = DateFormat('HH:mm (MMM d)');
    final startedStr = format.format(active.startedAt);
    final targetEndStr = format.format(active.startedAt.add(target));

    String durationString(Duration duration) {
      final hours = duration.inHours.abs().toString().padLeft(2, '0');
      final minutes = (duration.inMinutes.abs() % 60).toString().padLeft(2, '0');
      final seconds = (duration.inSeconds.abs() % 60).toString().padLeft(2, '0');
      return "$hours:$minutes:$seconds";
    }

    return Column(
      children: [
        Text(
          isOverTarget ? "FASTING COMPLETE" : "YOU ARE FASTING",
          style: theme.textTheme.labelLarge?.copyWith(
            color: AppColors.primary,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isOverTarget ? "Target reached! Break your fast when ready." : "Keep up the great work!",
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.secondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 10,
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
                const SizedBox(height: 4),
                Text(
                  isOverTarget ? "ELAPSED" : "REMAINING",
                  style: theme.textTheme.labelSmall?.copyWith(color: AppColors.secondary, letterSpacing: 1.0),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildTimeDetailCard(theme, "STARTED", startedStr, Icons.play_arrow),
            _buildTimeDetailCard(theme, "TARGET END", targetEndStr, Icons.outlined_flag),
          ],
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: PremiumButton(
            text: "END FAST",
            isPrimary: true,
            icon: Icons.stop_circle_outlined,
            onTap: () => _confirmEndFast(context),
          ),
        ),
      ],
    );
  }

  Widget _buildStartFastView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Text(
                "READY TO START FASTING?",
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.primary,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Select a plan aligned with your daily flow.",
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.secondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text("SELECT PLAN", style: theme.textTheme.labelSmall?.copyWith(color: AppColors.secondary, letterSpacing: 1.0)),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: FastingPlan.values.length - 1, // Exclude custom for simplicity for now
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final plan = FastingPlan.values[index];
            final isSelected = _selectedPlan == plan;
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedPlan = plan;
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.hourglass_empty,
                        color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.nameString,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            plan.description,
                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle, color: AppColors.primary, size: 24),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: PremiumButton(
            text: "START FAST NOW",
            isPrimary: true,
            icon: Icons.play_arrow_outlined,
            onTap: () {
              ref.read(fastingRepositoryProvider).startSession(_selectedPlan.targetSeconds);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimeDetailCard(ThemeData theme, String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        color: AppColors.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.labelSmall?.copyWith(fontSize: 9, color: AppColors.secondary)),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightsSection(ThemeData theme, AsyncValue<int> streakAsync, AsyncValue<double> avgEatingAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("FASTING INSIGHTS", style: theme.textTheme.labelSmall?.copyWith(color: AppColors.secondary, letterSpacing: 1.0)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildInsightMetricCard(
                theme,
                "Current Streak",
                streakAsync.when(
                  data: (s) => "$s ${s == 1 ? 'day' : 'days'}",
                  loading: () => "...",
                  error: (e, s) => "0",
                ),
                Icons.local_fire_department,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInsightMetricCard(
                theme,
                "Avg Eating Window",
                avgEatingAsync.when(
                  data: (hrs) => "${hrs.toStringAsFixed(1)} hrs",
                  loading: () => "...",
                  error: (e, s) => "8.0 hrs",
                ),
                Icons.restaurant,
                AppColors.earthBrown,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInsightMetricCard(ThemeData theme, String title, String value, IconData icon, Color accentColor) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary)),
              Icon(icon, size: 18, color: accentColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(ThemeData theme, AsyncValue<dynamic> historyAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("RECENT SESSIONS", style: theme.textTheme.labelSmall?.copyWith(color: AppColors.secondary, letterSpacing: 1.0)),
        const SizedBox(height: 12),
        historyAsync.when(
          data: (history) {
            if (history.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  "No completed fasting sessions yet.",
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.secondary),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length > 5 ? 5 : history.length,
              separatorBuilder: (context, index) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final session = history[index];
                final duration = session.endedAt!.difference(session.startedAt);
                final hours = duration.inHours;
                final minutes = duration.inMinutes % 60;
                final dateStr = DateFormat('E, MMM d').format(session.startedAt);
                final targetHours = session.targetSeconds ~/ 3600;

                return Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: session.completed ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        session.completed ? Icons.check_circle_outline : Icons.close,
                        color: session.completed ? AppColors.primary : AppColors.secondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "$hours hrs $minutes min fast",
                            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "Target: ${targetHours}h • $dateStr",
                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                          ),
                        ],
                      ),
                    ),
                    if (session.completed)
                      Text(
                        "SUCCESS",
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      Text(
                        "INCOMPLETE",
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                  ],
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
        ),
      ],
    );
  }

  void _confirmEndFast(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          title: const Text("End Fast"),
          content: const Text("Are you sure you want to end your current fasting session?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ref.read(fastingRepositoryProvider).endSession(completed: true);
              },
              child: const Text("END FAST", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
