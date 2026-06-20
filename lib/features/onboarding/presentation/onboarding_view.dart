import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../theme/colors.dart';
import '../../../widgets/glass_container.dart';
import '../../../widgets/premium_button.dart';
import '../../profile/domain/profile.dart';

class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({super.key});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  final _pageController = PageController();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();

  int _index = 0;
  FitnessGoal? _goal;
  ActivityLevel? _activity;

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  bool get _canAdvance => switch (_index) {
        0 => _goal != null,
        1 => _activity != null,
        2 => true,
        _ => false,
      };

  Future<void> _next() async {
    if (_index < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }
    await _complete();
  }

  Future<void> _complete() async {
    final name = _nameCtrl.text.trim();
    final profile = Profile(
      name: name.isEmpty ? null : name,
      goal: _goal ?? FitnessGoal.maintenance,
      activityLevel: _activity ?? ActivityLevel.lightlyActive,
      ageYears: int.tryParse(_ageCtrl.text.trim()),
      weightKg: double.tryParse(_weightCtrl.text.trim()),
      heightCm: double.tryParse(_heightCtrl.text.trim()),
    );
    await ref.read(localProfileRepositoryProvider).save(profile);
    if (!mounted) return;
    context.go('/app');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _index > 0
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
              )
            : const SizedBox.shrink(),
        actions: [
          TextButton(
            onPressed: _complete,
            child: Text('Skip', style: TextStyle(color: AppColors.secondary)),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Row(
                children: List.generate(3, (i) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 4,
                      decoration: BoxDecoration(
                        color: _index >= i ? AppColors.primary : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    _buildGoals(theme),
                    _buildActivity(theme),
                    _buildDetails(theme),
                  ],
                ),
              ),
              PremiumButton(
                text: _index == 2 ? 'Complete' : 'Next',
                onTap: _canAdvance ? _next : () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoals(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("What is your primary goal?", style: theme.textTheme.displayMedium),
        const SizedBox(height: 32),
        ...FitnessGoal.values.map((g) {
          final selected = _goal == g;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: GestureDetector(
              onTap: () => setState(() => _goal = g),
              child: GlassContainer(
                padding: const EdgeInsets.all(20),
                border: selected ? Border.all(color: AppColors.primary, width: 2) : null,
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: selected ? AppColors.primary : AppColors.outline,
                    ),
                    const SizedBox(width: 16),
                    Text(g.label, style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActivity(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("What is your activity level?", style: theme.textTheme.displayMedium),
        const SizedBox(height: 32),
        ...ActivityLevel.values.map((a) {
          final selected = _activity == a;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: GestureDetector(
              onTap: () => setState(() => _activity = a),
              child: GlassContainer(
                padding: const EdgeInsets.all(20),
                border: selected ? Border.all(color: AppColors.primary, width: 2) : null,
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: selected ? AppColors.primary : AppColors.outline,
                    ),
                    const SizedBox(width: 16),
                    Text(a.label, style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDetails(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Tell us about yourself", style: theme.textTheme.displayMedium),
        const SizedBox(height: 8),
        Text("This helps us calculate your macros accurately.", style: theme.textTheme.bodyMedium),
        const SizedBox(height: 32),
        _textField("Name (optional)", "e.g. Alex", _nameCtrl,
            keyboardType: TextInputType.name),
        const SizedBox(height: 16),
        _numField("Age", "e.g. 25", _ageCtrl),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _numField("Weight (kg)", "e.g. 65", _weightCtrl)),
            const SizedBox(width: 16),
            Expanded(child: _numField("Height (cm)", "e.g. 170", _heightCtrl)),
          ],
        ),
      ],
    );
  }

  Widget _numField(String label, String hint, TextEditingController controller) =>
      _textField(label, hint, controller, keyboardType: TextInputType.number);

  Widget _textField(
    String label,
    String hint,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.surfaceContainerLowest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
            ),
          ),
          keyboardType: keyboardType,
        ),
      ],
    );
  }
}
