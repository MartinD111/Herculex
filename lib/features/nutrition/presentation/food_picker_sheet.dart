import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database.dart';
import '../../../theme/colors.dart';
import '../domain/meal.dart';
import 'barcode_scanner_view.dart';
import 'custom_food_form_sheet.dart';
import 'log_entry_sheet.dart';
import 'nutrition_providers.dart';
import 'recipe_builder_view.dart';

/// Tabbed bottom sheet: Search · Scan · Recent · Recipes · Custom.
/// Returns true if anything was logged.
class FoodPickerSheet extends ConsumerStatefulWidget {
  final DateTime date;
  final Meal meal;

  const FoodPickerSheet({super.key, required this.date, required this.meal});

  static Future<bool?> show(
    BuildContext context, {
    required DateTime date,
    required Meal meal,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodPickerSheet(date: date, meal: meal),
    );
  }

  @override
  ConsumerState<FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends ConsumerState<FoodPickerSheet> with TickerProviderStateMixin {
  late final _tabs = TabController(length: 4, vsync: this);
  final _queryCtrl = TextEditingController();
  String? _query;

  @override
  void dispose() {
    _tabs.dispose();
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _logFood(FoodData f) async {
    final logged = await LogEntrySheet.forFood(
      context,
      food: f,
      date: widget.date,
      initialMeal: widget.meal,
    );
    if (logged == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _logRecipe(RecipeData r) async {
    final logged = await LogEntrySheet.forRecipe(
      context,
      recipe: r,
      date: widget.date,
      initialMeal: widget.meal,
    );
    if (logged == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _scan() async {
    final code = await BarcodeScannerView.show(context);
    if (code == null || !mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final food = await ref.read(nutritionRepositoryProvider).lookupBarcode(code);
    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss loader
    if (food == null) {
      // Offer to create custom with this barcode prefilled.
      final created = await CustomFoodFormSheet.show(context, initialBarcode: code);
      if (created != null) _logFood(created);
    } else {
      _logFood(food);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: theme.bottomSheetTheme.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text('Add to ${widget.meal.label}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.secondary,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: 'Search'),
                Tab(text: 'Recent'),
                Tab(text: 'Recipes'),
                Tab(text: 'Custom'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildSearchTab(controller),
                  _buildRecentTab(controller),
                  _buildRecipesTab(controller),
                  _buildCustomTab(controller),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Data via OpenFoodFacts when not in local catalog',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTab(ScrollController controller) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _queryCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  onSubmitted: (_) => _runRemoteSearch(),
                  decoration: InputDecoration(
                    hintText: 'Search foods…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: _scan,
                      tooltip: 'Scan barcode',
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _localResultsList(controller)),
      ],
    );
  }

  Widget _localResultsList(ScrollController controller) {
    final asyncFoods = ref.watch(foodSearchProvider(_query));
    return asyncFoods.when(
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('No matches in your library yet.', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  if ((_query ?? '').trim().isNotEmpty)
                    TextButton.icon(
                      icon: const Icon(Icons.cloud_outlined),
                      label: const Text('Search OpenFoodFacts'),
                      onPressed: _runRemoteSearch,
                    ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          controller: controller,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) => _FoodTile(food: list[i], onTap: () => _logFood(list[i])),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Future<void> _runRemoteSearch() async {
    final q = (_query ?? '').trim();
    if (q.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    await ref.read(nutritionRepositoryProvider).searchFoods(q, includeRemote: true);
    if (!mounted) return;
    Navigator.of(context).pop();
    // foodSearchProvider auto-refreshes via Drift stream — nothing else to do.
  }

  Widget _buildRecentTab(ScrollController controller) {
    final async = ref.watch(recentFoodsProvider);
    return async.when(
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Text('Nothing logged in the last 30 days.', style: Theme.of(context).textTheme.bodyMedium),
          );
        }
        return ListView.separated(
          controller: controller,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) => _FoodTile(food: list[i], onTap: () => _logFood(list[i])),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildRecipesTab(ScrollController controller) {
    final async = ref.watch(recipesProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('New recipe'),
              onPressed: () async {
                final created = await Navigator.push<RecipeData>(
                  context,
                  MaterialPageRoute(builder: (_) => const RecipeBuilderView()),
                );
                if (created != null && mounted) {
                  _logRecipe(created);
                }
              },
            ),
          ),
        ),
        Expanded(
          child: async.when(
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Text('No recipes yet.', style: Theme.of(context).textTheme.bodyMedium),
                );
              }
              return ListView.separated(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.restaurant_menu),
                  title: Text(list[i].name),
                  subtitle: Text('${list[i].servings} servings'),
                  onTap: () => _logRecipe(list[i]),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomTab(ScrollController controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_note, size: 56, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              'Create a one-off food with its own macros.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('New custom food'),
              onPressed: () async {
                final food = await CustomFoodFormSheet.show(context);
                if (food != null && mounted) _logFood(food);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodTile extends StatelessWidget {
  final FoodData food;
  final VoidCallback onTap;
  const _FoodTile({required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: food.imageUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: food.imageUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const Icon(Icons.fastfood),
              ),
            )
          : const Icon(Icons.fastfood),
      title: Text(food.name, style: theme.textTheme.titleSmall),
      subtitle: Text(
        [
          if (food.brand != null) food.brand!,
          '${food.kcalPer100g.toStringAsFixed(0)} kcal/100g',
        ].join(' • '),
        style: theme.textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.add_circle_outline),
      onTap: onTap,
    );
  }
}
