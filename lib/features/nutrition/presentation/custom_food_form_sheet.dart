import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database.dart';
import '../../../theme/colors.dart';
import '../../../widgets/premium_button.dart';
import 'nutrition_providers.dart';

class CustomFoodFormSheet extends ConsumerStatefulWidget {
  final String? initialName;
  final String? initialBarcode;

  const CustomFoodFormSheet({super.key, this.initialName, this.initialBarcode});

  static Future<FoodData?> show(BuildContext context, {String? initialName, String? initialBarcode}) {
    return showModalBottomSheet<FoodData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: CustomFoodFormSheet(initialName: initialName, initialBarcode: initialBarcode),
      ),
    );
  }

  @override
  ConsumerState<CustomFoodFormSheet> createState() => _CustomFoodFormSheetState();
}

class _CustomFoodFormSheetState extends ConsumerState<CustomFoodFormSheet> {
  late final _name = TextEditingController(text: widget.initialName);
  final _brand = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _servingG = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _brand, _kcal, _protein, _carbs, _fat, _servingG]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final kcal = double.tryParse(_kcal.text.trim());
    if (name.isEmpty || kcal == null || kcal <= 0) {
      setState(() => _error = 'Name and kcal/100g are required');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final food = await ref.read(nutritionRepositoryProvider).createCustomFood(
          name: name,
          brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
          kcalPer100g: kcal,
          proteinPer100g: double.tryParse(_protein.text.trim()) ?? 0,
          carbsPer100g: double.tryParse(_carbs.text.trim()) ?? 0,
          fatPer100g: double.tryParse(_fat.text.trim()) ?? 0,
          servingGrams: double.tryParse(_servingG.text.trim()),
        );
    if (!mounted) return;
    Navigator.of(context).pop(food);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: theme.bottomSheetTheme.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Custom food', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('All values per 100 g/ml', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary)),
            const SizedBox(height: 24),
            _Field(label: 'Name *', controller: _name),
            const SizedBox(height: 14),
            _Field(label: 'Brand', controller: _brand),
            const SizedBox(height: 14),
            _Field(label: 'kcal / 100g *', controller: _kcal, numeric: true),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _Field(label: 'Protein g', controller: _protein, numeric: true)),
                const SizedBox(width: 12),
                Expanded(child: _Field(label: 'Carbs g', controller: _carbs, numeric: true)),
                const SizedBox(width: 12),
                Expanded(child: _Field(label: 'Fat g', controller: _fat, numeric: true)),
              ],
            ),
            const SizedBox(height: 14),
            _Field(label: 'Default serving (g)', controller: _servingG, numeric: true),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 28),
            PremiumButton(
              text: _saving ? 'Saving…' : 'Save food',
              onTap: _saving ? () {} : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool numeric;
  const _Field({required this.label, required this.controller, this.numeric = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.secondary,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          inputFormatters: numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceContainer,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
