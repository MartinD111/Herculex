import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/floating_nav_bar.dart';
import '../dashboard/presentation/dashboard_view.dart';
import '../nutrition/presentation/nutrition_view.dart';
import '../profile/presentation/profile_view.dart';
import '../programs/presentation/training_blocks_view.dart';
import '../workouts/presentation/workouts_view.dart';

/// The five-tab home shell. Bottom-nav index drives which feature view shows.
/// Insights moved off the nav bar (it overflowed at six items) and is now
/// reachable from the Profile tab.
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
    ProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _index, children: _tabs),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingNavBar(
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
            ),
          ),
        ],
      ),
    );
  }
}
