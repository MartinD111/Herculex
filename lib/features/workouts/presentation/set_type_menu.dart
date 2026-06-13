import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../theme/colors.dart';
import '../domain/set_type.dart';

/// Result of the set-type menu: a type plus its serialized metadata.
class SetTypeSelection {
  final SetType type;
  final String? metaJson;
  const SetTypeSelection(this.type, [this.metaJson]);
}

/// One-tap set-type switcher (§15, §26). Tapping a set's index cell opens this
/// sheet; selection is instantaneous, with inline quick-picks for the types
/// that carry metadata (pause duration, drop percent, down-set decrement).
class SetTypeMenu extends StatelessWidget {
  final SetType current;
  const SetTypeMenu({super.key, required this.current});

  static Future<SetTypeSelection?> show(BuildContext context,
      {required SetType current}) {
    return showModalBottomSheet<SetTypeSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SetTypeMenu(current: current),
    );
  }

  /// Short badge shown in the set-index cell (e.g. "D" for drop set).
  static String badge(SetType type) => switch (type) {
        SetType.standard => '',
        SetType.drop => 'D',
        SetType.restPause => 'RP',
        SetType.partials => 'P½',
        SetType.myoReps => 'MY',
        SetType.pyramid => 'PY',
        SetType.forced => 'F',
        SetType.negatives => 'N',
        SetType.pause => 'PA',
        SetType.mechanicalDrop => 'MD',
        SetType.giant => 'G',
        SetType.preExhaustion => 'PE',
        SetType.twentyOnes => '21',
        SetType.volume20x60 => '20x',
        SetType.downSets => 'DN',
        SetType.amrap => 'AM',
        SetType.emom => 'EM',
        SetType.forTime => 'FT',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Set Type',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  for (final type in SetType.values)
                    _SetTypeTile(type: type, isSelected: type == current),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetTypeTile extends StatelessWidget {
  final SetType type;
  final bool isSelected;
  const _SetTypeTile({required this.type, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Pause reps offer the standard 2/3/5s quick-picks inline (§15).
    if (type == SetType.pause) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: _decoration(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(child: Text(type.label, style: _labelStyle(theme))),
              for (final s in pauseRepSecondsOptions)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ActionChip(
                    label: Text('${s}s'),
                    onPressed: () => Navigator.of(context).pop(
                      SetTypeSelection(type, jsonEncode({'pauseSeconds': s})),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (type == SetType.drop) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: _decoration(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(child: Text(type.label, style: _labelStyle(theme))),
              for (final pct in const [10, 20, 30])
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ActionChip(
                    label: Text('-$pct%'),
                    onPressed: () => Navigator.of(context).pop(
                      SetTypeSelection(type, jsonEncode({'dropPercent': pct})),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: _decoration(),
      child: ListTile(
        dense: true,
        title: Text(type.label, style: _labelStyle(theme)),
        trailing: isSelected
            ? const Icon(Icons.check, color: AppColors.primary, size: 20)
            : null,
        onTap: () => Navigator.of(context).pop(SetTypeSelection(type)),
      ),
    );
  }

  BoxDecoration _decoration() => BoxDecoration(
        color: isSelected
            ? AppColors.primaryContainer.withValues(alpha: 0.3)
            : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      );

  TextStyle? _labelStyle(ThemeData theme) => theme.textTheme.titleSmall
      ?.copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500);
}
