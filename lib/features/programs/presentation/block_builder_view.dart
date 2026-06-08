import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../theme/colors.dart';
import '../../../widgets/glass_container.dart';
import '../../../widgets/premium_button.dart';
import 'programs_providers.dart';
import '../../../data/local/database.dart';


class BlockBuilderView extends ConsumerStatefulWidget {
  const BlockBuilderView({super.key});

  @override
  ConsumerState<BlockBuilderView> createState() => _BlockBuilderViewState();
}

class _BlockBuilderViewState extends ConsumerState<BlockBuilderView> {
  int _currentStep = 1;

  // Step 1 State: Timeframe
  int _selectedWeeks = 12; // 4, 12, or 24 weeks

  // Step 2 State: Weekly Skeleton
  final Map<int, String?> _assignedWorkouts = {
    1: null, // Mon
    2: null, // Tue
    3: null, // Wed
    4: null, // Thu
    5: null, // Fri
    6: null, // Sat
    7: null, // Sun
  };

  final Map<int, String> _dayEmojis = {
    1: "🦍",
    2: "🍗",
    3: "🌊",
    4: "🚀",
    5: "⚡",
    6: "🏆",
    7: "🧘",
  };

  final List<String> _workoutCatalog = [
    "Upper Power 🦍",
    "Lower Hypertrophy 🍗",
    "Push Hypertrophy 🌊",
    "Pull Hypertrophy 🚀",
    "Leg Strength ⚡",
    "Active Recovery 🧘",
    "Full Body Metabolic 🏆",
  ];

  // Step 3 State: Progression Strategy
  String _progressionStrategy = 'volume'; // volume, intensity, dynamic

  // Step 4 State: Deload / Vacation
  DateTimeRange? _vacationRange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("BLOCK BUILDER", style: theme.textTheme.titleMedium?.copyWith(letterSpacing: 2.0)),
        centerTitle: true,
        leading: _currentStep > 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _currentStep--;
                  });
                },
              )
            : null,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStepIndicator(theme),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildCurrentStepView(theme),
              ),
            ),
            _buildFooter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(4, (index) {
          final stepNum = index + 1;
          final isActive = _currentStep == stepNum;
          final isCompleted = _currentStep > stepNum;

          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? AppColors.primary
                        : (isActive ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceContainer),
                    border: Border.all(
                      color: isActive ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            "$stepNum",
                            style: TextStyle(
                              color: isCompleted || isActive ? AppColors.primary : AppColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                if (index < 3)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isCompleted ? AppColors.primary : AppColors.surfaceContainer,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepView(ThemeData theme) {
    switch (_currentStep) {
      case 1:
        return _buildStep1Timeframe(theme);
      case 2:
        return _buildStep2Skeleton(theme);
      case 3:
        return _buildStep3Progression(theme);
      case 4:
        return _buildStep4DeloadVacation(theme);
      default:
        return Container();
    }
  }

  // ── Step 1: Timeframe ──
  Widget _buildStep1Timeframe(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("CHOOSE TIMEFRAME", style: theme.textTheme.displayMedium),
        const SizedBox(height: 8),
        Text("Select a timeframe for this block periodization macro-cycle.", style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.secondary)),
        const SizedBox(height: 32),
        Row(
          children: [
            _buildTimeframeCard(4, "Micro-Cycle", "4 Weeks", theme),
            const SizedBox(width: 12),
            _buildTimeframeCard(12, "Meso-Cycle", "12 Weeks", theme),
            const SizedBox(width: 12),
            _buildTimeframeCard(24, "Macro-Cycle", "24 Weeks", theme),
          ],
        ),
        const SizedBox(height: 32),
        GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "BLOCK SPECIFICATIONS",
                    style: theme.textTheme.labelMedium?.copyWith(color: AppColors.primary, letterSpacing: 1.2),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSpecRow("START DATE", DateFormat('MMM d, yyyy').format(DateTime.now()), theme),
              const Divider(height: 24),
              _buildSpecRow("END DATE", DateFormat('MMM d, yyyy').format(DateTime.now().add(Duration(days: _selectedWeeks * 7))), theme),
              const Divider(height: 24),
              _buildSpecRow("ESTIMATED WORKOUTS", "${_selectedWeeks * 3 - 4} to ${_selectedWeeks * 5} Sessions", theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeframeCard(int weeks, String cycleName, String duration, ThemeData theme) {
    final isSelected = _selectedWeeks == weeks;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedWeeks = weeks;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.outlineVariant.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(cycleName, style: theme.textTheme.labelSmall?.copyWith(color: AppColors.secondary, letterSpacing: 1.0)),
              const SizedBox(height: 8),
              Text(duration, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecRow(String label, String value, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: AppColors.secondary)),
        Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ── Step 2: Skeleton ──
  Widget _buildStep2Skeleton(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("WEEKLY SKELETON", style: theme.textTheme.displayMedium),
        const SizedBox(height: 8),
        Text("Map your baseline weekly rhythm before progressions.", style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.secondary)),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (index) {
            final dayIndex = index + 1;
            final days = ["M", "T", "W", "T", "F", "S", "S"];
            final workout = _assignedWorkouts[dayIndex];
            final isAssigned = workout != null;

            return GestureDetector(
              onTap: () => _showWorkoutSelectionBottomSheet(dayIndex),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isAssigned ? AppColors.primary : AppColors.surfaceContainer,
                  border: Border.all(
                    color: isAssigned ? AppColors.primary : AppColors.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Center(
                  child: Text(
                    isAssigned ? _dayEmojis[dayIndex]! : days[index],
                    style: TextStyle(
                      color: isAssigned ? Colors.white : AppColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 32),
        Text("ASSIGNED DAYS", style: theme.textTheme.labelSmall?.copyWith(color: AppColors.secondary, letterSpacing: 1.0)),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 7,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final dayIndex = index + 1;
            final dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
            final workout = _assignedWorkouts[dayIndex];

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Text(
                    dayNames[index],
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  workout == null
                      ? TextButton.icon(
                          onPressed: () => _showWorkoutSelectionBottomSheet(dayIndex),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text("REST / SKIP"),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary),
                          ),
                          child: Row(
                            children: [
                              Text(workout, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _assignedWorkouts[dayIndex] = null;
                                  });
                                },
                                child: const Icon(Icons.close, size: 14, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _showWorkoutSelectionBottomSheet(int dayIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("CHOOSE TEMPLATE", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: _workoutCatalog.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final workout = _workoutCatalog[index];
                    return ListTile(
                      title: Text(workout),
                      onTap: () {
                        setState(() {
                          _assignedWorkouts[dayIndex] = workout;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Step 3: Progression Strategy ──
  Widget _buildStep3Progression(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("PROGRESSION ENGINE", style: theme.textTheme.displayMedium),
        const SizedBox(height: 8),
        Text("Select your macro periodization progression archetype.", style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.secondary)),
        const SizedBox(height: 32),
        _buildStrategyOption(
          'volume',
          "Volume Accumulation",
          "Starts with moderate sets/reps and adds volume each week. Best for hypertrophy.",
          [35, 45, 55, 20], // mini-graph bars
          theme,
        ),
        const SizedBox(height: 16),
        _buildStrategyOption(
          'intensity',
          "Intensity Peaking",
          "Maintains lower volume while systematically increasing weight. Best for strength.",
          [20, 30, 45, 60], // mini-graph line
          theme,
        ),
        const SizedBox(height: 16),
        _buildStrategyOption(
          'dynamic',
          "Dynamic Progression",
          "Volume and weight adapt daily based on your sleep, cycle, and readiness score.",
          null, // animated pulse representation
          theme,
        ),
      ],
    );
  }

  Widget _buildStrategyOption(
    String strategy,
    String title,
    String desc,
    List<double>? graphPoints,
    ThemeData theme,
  ) {
    final isSelected = _progressionStrategy == strategy;

    return GestureDetector(
      onTap: () {
        setState(() {
          _progressionStrategy = strategy;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineVariant.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(desc, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (graphPoints != null)
              CustomPaint(
                size: const Size(60, 40),
                painter: _MiniGraphPainter(graphPoints, isSelected ? AppColors.primary : AppColors.secondary),
              )
            else
              Container(
                width: 60,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceVariant,
                ),
                child: Icon(Icons.online_prediction, color: isSelected ? AppColors.primary : AppColors.secondary),
              ),
          ],
        ),
      ),
    );
  }

  // ── Step 4: Deload & Vacation ──
  Widget _buildStep4DeloadVacation(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("DELOADS & VACATIONS", style: theme.textTheme.displayMedium),
        const SizedBox(height: 8),
        Text("Insert trips or scheduled deload weeks to shift your progression logic automatically.", style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.secondary)),
        const SizedBox(height: 32),
        GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.beach_access, color: AppColors.primary, size: 40),
              const SizedBox(height: 16),
              Text(
                "DO YOU HAVE PLANNED BREAKS?",
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "We will automatically pause your peak calculations so you never drop momentum.",
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              PremiumButton(
                text: _vacationRange == null
                    ? "SELECT TRIP DATES"
                    : "${DateFormat('MMM d').format(_vacationRange!.start)} - ${DateFormat('MMM d').format(_vacationRange!.end)}",
                isPrimary: false,
                icon: Icons.date_range,
                onTap: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (range != null) {
                    setState(() {
                      _vacationRange = range;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Footer & Navigation ──
  Widget _buildFooter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Step $_currentStep of 4",
            style: theme.textTheme.labelSmall?.copyWith(color: AppColors.secondary),
          ),
          PremiumButton(
            text: _currentStep == 4 ? "CREATE BLOCK" : "CONTINUE",
            onTap: () {
              if (_currentStep < 4) {
                setState(() {
                  _currentStep++;
                });
              } else {
                _createAndActivateBlock();
              }
            },
          ),
        ],
      ),
    );
  }

  void _createAndActivateBlock() async {
    final repo = ref.read(programsRepositoryProvider);

    // 1. Create program
    final id = await repo.createProgram(
      name: "$_selectedWeeks-Week Progression",
      description: "Periodized $_progressionStrategy progression block.",
      weeks: _selectedWeeks,
      type: "block",
      progressionStrategy: _progressionStrategy,
    );

    // 2. Add skeleton days
    final weeks = await repo.getProgramWeeks(id);
    for (final week in weeks) {
      for (int dayOfWeek = 1; dayOfWeek <= 7; dayOfWeek++) {
        final workout = _assignedWorkouts[dayOfWeek];
        if (workout != null) {
          await repo.addProgramDay(
            programWeekId: week.id,
            dayOfWeek: dayOfWeek,
            name: workout,
          );
        }
      }
    }

    // 3. Materialise scheduled calendar events
    await repo.materializeProgram(id, DateTime.now());

    // 4. Add vacation if set
    if (_vacationRange != null) {
      await repo.addExternalEvent(
        from: _vacationRange!.start,
        to: _vacationRange!.end,
        type: 'vacation',
        notes: 'Planned holiday break.',
      );
    }

    // Return to dashboard/training blocks
    if (mounted) {
      Navigator.pop(context);
    }
  }
}

class _MiniGraphPainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _MiniGraphPainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final barWidth = size.width / (values.length * 2 - 1);
    for (int i = 0; i < values.length; i++) {
      final h = (values[i] / 100) * size.height;
      final x = i * barWidth * 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, barWidth, h),
          const Radius.circular(2),
        ),
        paint..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
