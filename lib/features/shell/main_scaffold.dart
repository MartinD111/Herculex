import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/floating_nav_bar.dart';
import '../../widgets/live_workout_banner.dart';
import '../dashboard/presentation/dashboard_view.dart';
import '../nutrition/presentation/nutrition_view.dart';
import '../programs/presentation/training_blocks_view.dart';
import '../workouts/presentation/workouts_providers.dart';
import '../workouts/presentation/workouts_view.dart';

/// The four-tab home shell. Bottom-nav index drives which feature view shows.
/// Profile lives off the nav bar — it's reachable via the avatar in the
/// Dashboard header (route `/profile`). Insights is reachable from Profile.
class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _index = 0;

  static const _tabs = <Widget>[
    DashboardView(),
    NutritionView(),
    WorkoutsView(),
    TrainingBlocksView(),
  ];

  @override
  Widget build(BuildContext context) {
    final hasActiveSession =
        ref.watch(activeSessionProvider).asData?.value != null;
    final showBanner = hasActiveSession && _index != 2;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _index, children: _tabs),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showBanner)
                  LiveWorkoutBanner(
                    onResume: () => setState(() => _index = 2),
                  ),
                FloatingNavBar(
                  currentIndex: _index,
                  onTap: (i) => setState(() => _index = i),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
