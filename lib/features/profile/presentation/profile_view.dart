import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../theme/colors.dart';
import '../domain/profile.dart';

// ── Units preference ─────────────────────────────────────────────────────────
// Stored in SharedPreferences via a simple notifier.

final _unitsProvider = StateNotifierProvider<_UnitsNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return _UnitsNotifier(prefs.getBool('units_metric') ?? true, prefs);
});

class _UnitsNotifier extends StateNotifier<bool> {
  _UnitsNotifier(super.initial, this._prefs);
  final dynamic _prefs;

  void toggle() {
    state = !state;
    _prefs.setBool('units_metric', state);
  }
}

// ── Profile view ─────────────────────────────────────────────────────────────

class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) => _ProfileBody(profile: profile),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}

class _ProfileBody extends ConsumerStatefulWidget {
  final Profile? profile;
  const _ProfileBody({required this.profile});

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  late FitnessGoal _goal;
  late ActivityLevel _activityLevel;
  late BiologicalSex? _sex;

  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _goal = p?.goal ?? FitnessGoal.maintenance;
    _activityLevel = p?.activityLevel ?? ActivityLevel.lightlyActive;
    _sex = p?.sex;
    _nameCtrl.text = p?.name ?? '';
    _ageCtrl.text = p?.ageYears?.toString() ?? '';
    _weightCtrl.text = p?.weightKg?.toString() ?? '';
    _heightCtrl.text = p?.heightCm?.toString() ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final name = _nameCtrl.text.trim();
    final profile = Profile(
      name: name.isEmpty ? null : name,
      goal: _goal,
      activityLevel: _activityLevel,
      sex: _sex,
      ageYears: int.tryParse(_ageCtrl.text.trim()),
      weightKg: double.tryParse(_weightCtrl.text.trim()),
      heightCm: double.tryParse(_heightCtrl.text.trim()),
    );
    await ref.read(localProfileRepositoryProvider).save(profile);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Profile saved'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      ),
    );
  }

  Future<void> _clearData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear all data?'),
        content: const Text(
            'This will permanently delete your profile, workouts, nutrition logs, and all other local data. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: const StadiumBorder(),
            ),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Clearing the profile drops the user back to onboarding via the router
    // redirect (which watches profileProvider).
    await ref.read(localProfileRepositoryProvider).clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMetric = ref.watch(_unitsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
      children: [
        if (Navigator.of(context).canPop())
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.chevron_left, size: 28),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        // ── Avatar / header ───────────────────────────────────────────────
        _AvatarHeader(profile: widget.profile),
        const SizedBox(height: 32),

        // ── Name ──────────────────────────────────────────────────────────
        _SectionHeader('Name'),
        const SizedBox(height: 12),
        _StatField(
          label: 'Name (optional)',
          hint: 'Your name',
          controller: _nameCtrl,
          keyboardType: TextInputType.name,
        ),

        const SizedBox(height: 28),

        // ── Body stats ────────────────────────────────────────────────────
        _SectionHeader('Body Stats'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _StatField(
              label: 'Age',
              hint: 'yrs',
              controller: _ageCtrl,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatField(
              label: isMetric ? 'Weight (kg)' : 'Weight (lbs)',
              hint: isMetric ? 'kg' : 'lbs',
              controller: _weightCtrl,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatField(
              label: isMetric ? 'Height (cm)' : 'Height (in)',
              hint: isMetric ? 'cm' : 'in',
              controller: _heightCtrl,
            ),
          ),
        ]),

        const SizedBox(height: 8),
        // BMI chip (read-only, calculated)
        if (widget.profile?.weightKg != null && widget.profile?.heightCm != null)
          _BmiChip(
            weightKg: widget.profile!.weightKg!,
            heightCm: widget.profile!.heightCm!,
          ),

        const SizedBox(height: 28),

        // ── Biological sex ────────────────────────────────────────────────
        _SectionHeader('Biological Sex'),
        const SizedBox(height: 12),
        Row(
          children: BiologicalSex.values.map((s) {
            final selected = _sex == s;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: s == BiologicalSex.male ? 8 : 0),
                child: _PillToggle(
                  label: s.label,
                  selected: selected,
                  onTap: () => setState(() => _sex = s),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 28),

        // ── Fitness goal ──────────────────────────────────────────────────
        _SectionHeader('Fitness Goal'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: FitnessGoal.values.map((g) {
            final selected = _goal == g;
            return _PillToggle(
              label: g.label,
              selected: selected,
              onTap: () => setState(() => _goal = g),
            );
          }).toList(),
        ),

        const SizedBox(height: 28),

        // ── Activity level ────────────────────────────────────────────────
        _SectionHeader('Activity Level'),
        const SizedBox(height: 12),
        Column(
          children: ActivityLevel.values.map((a) {
            final selected = _activityLevel == a;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ActivityTile(
                level: a,
                selected: selected,
                onTap: () => setState(() => _activityLevel = a),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 28),

        // ── App settings ──────────────────────────────────────────────────
        _SectionHeader('App Settings'),
        const SizedBox(height: 12),
        _SettingsCard(children: [
          _SettingsTile(
            icon: Icons.straighten_rounded,
            label: 'Units',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMetric ? 'Metric' : 'Imperial',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: isMetric,
                  onChanged: (_) => ref.read(_unitsProvider.notifier).toggle(),
                ),
              ],
            ),
          ),
          _SettingsDivider(),
          _SettingsTile(
            icon: Icons.dark_mode_rounded,
            label: 'Theme',
            trailing: _ThemeToggle(),
          ),
          _SettingsDivider(),
          _SettingsTile(
            icon: Icons.analytics_rounded,
            label: 'Insights',
            trailing: Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
            onTap: () => context.push('/insights'),
          ),
          _SettingsDivider(),
          _SettingsTile(
            icon: Icons.straighten,
            label: 'Body Measurements',
            trailing: Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
            onTap: () => context.push('/measurements'),
          ),
          _SettingsDivider(),
          _SettingsTile(
            icon: Icons.location_on_outlined,
            label: 'My Gyms',
            trailing: Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
            onTap: () => context.push('/gyms'),
          ),
          _SettingsDivider(),
          _SettingsTile(
            icon: Icons.task_alt,
            label: 'Micro Workouts',
            trailing: Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
            onTap: () => context.push('/micro-workouts'),
          ),
          _SettingsDivider(),
          _SettingsTile(
            icon: Icons.notifications_rounded,
            label: 'Notifications',
            trailing: Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
            onTap: () => _showComingSoon(context, 'Notifications'),
          ),
        ]),

        const SizedBox(height: 28),

        // ── Save stats button ─────────────────────────────────────────────
        _SaveButton(saving: _saving, onTap: _save),

        const SizedBox(height: 28),

        // ── Account ───────────────────────────────────────────────────────
        _SectionHeader('Account'),
        const SizedBox(height: 12),
        _SettingsCard(children: [
          _SettingsTile(
            icon: Icons.delete_forever_rounded,
            label: 'Clear All Data',
            iconColor: Colors.red.shade900,
            labelColor: Colors.red.shade900,
            onTap: () => _clearData(context),
          ),
        ]),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature settings coming soon'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      ),
    );
  }
}

// ── Avatar header ─────────────────────────────────────────────────────────────

class _AvatarHeader extends StatelessWidget {
  final Profile? profile;
  const _AvatarHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: const Icon(Icons.person_rounded, size: 38, color: AppColors.primary),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (profile?.name?.trim().isNotEmpty ?? false)
                    ? profile!.name!.trim()
                    : 'My Profile',
                style: theme.textTheme.displayMedium,
              ),
              const SizedBox(height: 4),
              if (profile != null)
                Text(
                  '${profile!.goal.label} · ${profile!.activityLevel.label}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.onSurfaceVariant),
                )
              else
                Text(
                  'Set your goals and stats',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── BMI chip ──────────────────────────────────────────────────────────────────

class _BmiChip extends StatelessWidget {
  final double weightKg;
  final double heightCm;
  const _BmiChip({required this.weightKg, required this.heightCm});

  @override
  Widget build(BuildContext context) {
    final h = heightCm / 100;
    final bmi = weightKg / (h * h);
    final (label, color) = switch (bmi) {
      < 18.5 => ('Underweight', Colors.blue.shade400),
      < 25.0 => ('Healthy weight', Colors.green.shade600),
      < 30.0 => ('Overweight', Colors.orange.shade600),
      _ => ('Obese', Colors.red.shade600),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monitor_heart_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            'BMI ${bmi.toStringAsFixed(1)} · $label',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Save button ───────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final bool saving;
  final VoidCallback onTap;
  const _SaveButton({required this.saving, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: saving ? null : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
      ),
      child: saving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text(
              'Save Profile',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
    );
  }
}

// ── Stat text field ───────────────────────────────────────────────────────────

class _StatField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  const _StatField({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
  });

  bool get _isNumeric =>
      keyboardType == const TextInputType.numberWithOptions(decimal: true);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: _isNumeric
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
              : null,
          textAlign: _isNumeric ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.outline, fontSize: 13),
            filled: true,
            fillColor: AppColors.surfaceContainer,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Pill toggle button ────────────────────────────────────────────────────────

class _PillToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PillToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Activity level tile ───────────────────────────────────────────────────────

class _ActivityTile extends StatelessWidget {
  final ActivityLevel level;
  final bool selected;
  final VoidCallback onTap;
  const _ActivityTile({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  static const _icons = {
    ActivityLevel.sedentary: Icons.weekend_rounded,
    ActivityLevel.lightlyActive: Icons.directions_walk_rounded,
    ActivityLevel.active: Icons.directions_run_rounded,
    ActivityLevel.veryActive: Icons.bolt_rounded,
  };

  static const _descriptions = {
    ActivityLevel.sedentary: 'Desk job, little or no exercise',
    ActivityLevel.lightlyActive: 'Light exercise 1–3 days/week',
    ActivityLevel.active: 'Moderate exercise 3–5 days/week',
    ActivityLevel.veryActive: 'Hard training 6–7 days/week',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.outlineVariant.withValues(alpha: 0.4),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _icons[level]!,
                size: 20,
                color: selected ? Colors.white : AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.primary : null,
                    ),
                  ),
                  Text(
                    _descriptions[level]!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.outline,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Settings card / tile helpers ──────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 56,
      color: AppColors.outlineVariant.withValues(alpha: 0.4),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final Color? iconColor;
  final Color? labelColor;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.trailing,
    this.iconColor,
    this.labelColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: iconColor ?? AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

// ── Theme toggle ──────────────────────────────────────────────────────────────

final _themeModeProvider =
    StateNotifierProvider<_ThemeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final saved = prefs.getString('theme_mode') ?? 'system';
  final initial = switch (saved) {
    'dark' => ThemeMode.dark,
    'light' => ThemeMode.light,
    _ => ThemeMode.system,
  };
  return _ThemeNotifier(initial, prefs);
});

class _ThemeNotifier extends StateNotifier<ThemeMode> {
  _ThemeNotifier(super.initial, this._prefs);
  final dynamic _prefs;

  void set(ThemeMode mode) {
    state = mode;
    _prefs.setString(
        'theme_mode',
        switch (mode) {
          ThemeMode.dark => 'dark',
          ThemeMode.light => 'light',
          _ => 'system',
        });
  }
}

class _ThemeToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(_themeModeProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ThemePill(
          label: 'Light',
          icon: Icons.light_mode_rounded,
          selected: mode == ThemeMode.light,
          onTap: () => ref.read(_themeModeProvider.notifier).set(ThemeMode.light),
        ),
        const SizedBox(width: 4),
        _ThemePill(
          label: 'System',
          icon: Icons.brightness_auto_rounded,
          selected: mode == ThemeMode.system,
          onTap: () => ref.read(_themeModeProvider.notifier).set(ThemeMode.system),
        ),
        const SizedBox(width: 4),
        _ThemePill(
          label: 'Dark',
          icon: Icons.dark_mode_rounded,
          selected: mode == ThemeMode.dark,
          onTap: () => ref.read(_themeModeProvider.notifier).set(ThemeMode.dark),
        ),
      ],
    );
  }
}

class _ThemePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ThemePill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          size: 18,
          color: selected ? Colors.white : AppColors.outline,
        ),
      ),
    );
  }
}
