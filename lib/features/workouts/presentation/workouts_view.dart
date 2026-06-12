import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/local/database.dart';
import '../../../theme/colors.dart';
import '../../../widgets/premium_button.dart';
import 'active_workout_view.dart';
import 'templates_view.dart';
import 'workouts_providers.dart';

class WorkoutsView extends ConsumerWidget {
  const WorkoutsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeSessionProvider);
    return active.when(
      data: (session) => session != null
          ? ActiveWorkoutView(session: session)
          : const _WorkoutsLanding(),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _WorkoutsLanding extends ConsumerStatefulWidget {
  const _WorkoutsLanding();

  @override
  ConsumerState<_WorkoutsLanding> createState() => _WorkoutsLandingState();
}

class _WorkoutsLandingState extends ConsumerState<_WorkoutsLanding>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Workout', style: theme.textTheme.displayMedium),
                const SizedBox(height: 8),
                Text(
                  'Log sets, supersets, and RPE. Rest timer starts when you check a set.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                PremiumButton(
                  text: 'Start Empty Workout',
                  icon: Icons.play_arrow,
                  onTap: () async {
                    await ref.read(workoutsRepositoryProvider).startSession();
                  },
                ),
                const SizedBox(height: 20),
                TabBar(
                  controller: _tabs,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.onSurfaceVariant,
                  indicatorColor: AppColors.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Recent'),
                    Tab(text: 'Templates'),
                  ],
                ),
                const Divider(height: 1),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _RecentTab(),
                const TemplatesView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recent = ref.watch(recentSessionsProvider);

    return recent.when(
      data: (sessions) => sessions.isEmpty
          ? Center(
              child: Text(
                'No completed workouts yet',
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.secondary),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
              itemCount: sessions.length,
              itemBuilder: (_, i) => _SessionTile(session: sessions[i]),
            ),
      error: (e, _) => Center(child: Text('Error: $e')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _SessionTile extends ConsumerWidget {
  final WorkoutSessionData session;
  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('EEE, MMM d').format(session.startedAt);
    final duration = session.endedAt?.difference(session.startedAt);
    final durationStr = duration == null
        ? ''
        : duration.inHours > 0
            ? '${duration.inHours}h ${duration.inMinutes.remainder(60)}m'
            : '${duration.inMinutes}m';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        onTap: () => context.push('/workout-history/${session.id}'),
        title: Text(dateStr, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text(
          [
            DateFormat('HH:mm').format(session.startedAt),
            if (durationStr.isNotEmpty) durationStr,
            if (session.sessionRpe != null) 'RPE ${session.sessionRpe}',
          ].join(' • '),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
