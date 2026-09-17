import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_pantry_app/core/constants/app_colors.dart';
import 'package:smart_pantry_app/features/shopping_list/providers/shopping_list_provider.dart';
import 'package:smart_pantry_app/features/recipes/data/models/recipe_model.dart';
import 'package:smart_pantry_app/features/recipes/providers/recipe_provider.dart';
import 'package:smart_pantry_app/features/recipes/presentation/widgets/recipe_match_card.dart';

class RecipeSuggestionsScreen extends ConsumerStatefulWidget {
  const RecipeSuggestionsScreen({super.key});

  @override
  ConsumerState<RecipeSuggestionsScreen> createState() => _RecipeSuggestionsScreenState();
}

class _RecipeSuggestionsScreenState extends ConsumerState<RecipeSuggestionsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final recipeAsync = ref.watch(recipeControllerProvider);
    final recipes = recipeAsync.valueOrNull ?? {'fullMatch': [], 'partialMatch': []};

    final fullMatches = (recipes['fullMatch'] ?? []).where((r) =>
        r.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (r.cuisineType?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)).toList();

    final partialMatches = (recipes['partialMatch'] ?? []).where((r) =>
        r.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (r.cuisineType?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Screen Title Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Smart Recipe Matcher 🍳',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Recipes dynamically calculated from ingredients in your pantry.',
                              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Search input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Search recipes by name or cuisine...',
                          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () => setState(() => _searchQuery = ''),
                                )
                              : null,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tabs
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TabBar(
                        indicatorColor: AppColors.primary,
                        labelColor: AppColors.primaryDark,
                        unselectedLabelColor: AppColors.textSecondary,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        indicatorSize: TabBarIndicatorSize.tab,
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text('Full Matches (${fullMatches.length})'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.pie_chart_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text('Partial Matches (${partialMatches.length})'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Tab View
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildRecipeList(fullMatches, isFullMatch: true),
                          _buildRecipeList(partialMatches, isFullMatch: false),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecipeList(List<RecipeModel> list, {required bool isFullMatch}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.ramen_dining_rounded, size: 44, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            Text(
              isFullMatch ? 'No full matches right now' : 'No recipes found',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              isFullMatch
                  ? 'Check "Partial Matches" or add more items to your pantry.'
                  : 'Try searching with a different recipe name.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final recipe = list[index];
        return RecipeMatchCard(
          title: recipe.title,
          matchPercentage: recipe.matchPercentage,
          prepTime: recipe.prepTimeMinutes ?? 20,
          cuisine: recipe.cuisineType ?? 'Chef Selection',
          missingIngredients: recipe.missingIngredients,
          substitutes: recipe.substituteOptions,
          onTap: () => _showRecipeDetails(context, recipe),
          onAddMissingToShopping: recipe.missingIngredients.isEmpty
              ? null
              : () {
                  _addMissingIngredients(context, recipe);
                },
        );
      },
    );
  }

  void _addMissingIngredients(BuildContext context, RecipeModel recipe) {
    for (final ing in recipe.missingIngredients) {
      ref.read(shoppingListControllerProvider.notifier).addItem(
            ing,
            1,
            'Required for ${recipe.title}',
          );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${recipe.missingIngredients.length} missing items to Shopping List!'),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showRecipeDetails(BuildContext context, RecipeModel recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                recipe.title,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    '${recipe.cuisineType ?? 'Chef Specialty'} Cuisine',
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(width: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.timer_outlined, size: 16, color: AppColors.textMuted),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${recipe.prepTimeMinutes} mins prep',
                                        style: const TextStyle(color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Missing Ingredients Alert & Button
                    if (recipe.missingIngredients.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Missing Ingredients for this recipe',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              recipe.missingIngredients.join(', '),
                              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                _addMissingIngredients(context, recipe);
                                Navigator.pop(ctx);
                              },
                              icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                              label: const Text('Add Missing to Shopping List'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Instructions Section
                    const Text(
                      'Step-by-Step Instructions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...recipe.instructions.asMap().entries.map((entry) {
                      final stepNum = entry.key + 1;
                      final instruction = entry.value;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$stepNum',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryDark,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                instruction,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
