import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/workouts/presentation/workouts_providers.dart';
import '../theme/colors.dart';
import '../theme/haptics.dart';

class LiveWorkoutBanner extends ConsumerStatefulWidget {
  final VoidCallback onResume;

  const LiveWorkoutBanner({super.key, required this.onResume});

  @override
  ConsumerState<LiveWorkoutBanner> createState() => _LiveWorkoutBannerState();
}

class _LiveWorkoutBannerState extends ConsumerState<LiveWorkoutBanner> {
  late Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  String _formatElapsed(DateTime startedAt) {
    final d = DateTime.now().difference(startedAt);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(activeSessionProvider);
    final session = sessionAsync.asData?.value;
    if (session == null) return const SizedBox.shrink();

    final exercisesAsync = ref.watch(sessionExercisesProvider(session.id));
    final catalog = ref.watch(exerciseCatalogProvider(null));

    final exercises = exercisesAsync.asData?.value ?? [];
    String exerciseName = 'Workout in progress';
    if (exercises.isNotEmpty) {
      final firstId = exercises.first.exerciseId;
      final match = catalog.asData?.value
          .where((e) => e.id == firstId)
          .firstOrNull;
      if (match != null) exerciseName = match.name;
    }

    final elapsedStr = _formatElapsed(session.startedAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: GestureDetector(
            onTap: () {
              Haptics.selection();
              widget.onResume();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  // Pulsing green dot
                  _PulsingDot(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Workout',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              elapsedStr,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          exerciseName,
                          style: const TextStyle(
                            color: AppColors.secondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Up arrow to resume
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween(begin: 0.4, end: 1.0).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFF30D158), // iOS green
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
