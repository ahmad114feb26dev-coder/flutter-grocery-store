import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/providers/core_providers.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../data/models/recipe_model.dart';
import '../data/repositories/recipe_repository.dart';

part 'recipe_provider.g.dart';

@riverpod
RecipeRepository recipeRepository(RecipeRepositoryRef ref) {
  return RecipeRepository(ref.watch(dioClientProvider));
}

class RecipeTemplate {
  final String id;
  final String title;
  final List<String> requiredIngredients;
  final List<String> instructions;
  final String cuisineType;
  final int prepTimeMinutes;
  final List<Map<String, String>> substituteOptions;

  RecipeTemplate({
    required this.id,
    required this.title,
    required this.requiredIngredients,
    required this.instructions,
    required this.cuisineType,
    required this.prepTimeMinutes,
    this.substituteOptions = const [],
  });
}

@riverpod
class RecipeController extends _$RecipeController {
  static final List<RecipeTemplate> _templates = [
    RecipeTemplate(
      id: 'rec_1',
      title: 'Spicy Tomato Pasta',
      requiredIngredients: ['Pasta', 'Tomato Sauce', 'Garlic', 'Chili Flakes'],
      instructions: [
        'Boil penne pasta in salted water for 9-11 minutes.',
        'In a pan, heat olive oil and sauté minced garlic until fragrant.',
        'Add tomato sauce and chili flakes. Simmer on low for 5 minutes.',
        'Toss boiled pasta in the sauce, garnish with herbs, and serve hot.',
      ],
      cuisineType: 'Italian',
      prepTimeMinutes: 20,
      substituteOptions: [
        {'original': 'Pasta', 'usedSubstitute': 'Zucchini Noodles'},
      ],
    ),
    RecipeTemplate(
      id: 'rec_2',
      title: 'Chicken Fried Rice',
      requiredIngredients: ['Rice', 'Chicken Breast', 'Eggs', 'Soy Sauce', 'Peas'],
      instructions: [
        'Dice chicken breast and stir-fry in oil until golden brown.',
        'Push chicken to the side and scramble eggs in the same pan.',
        'Add cooked rice, peas, and drizzle soy sauce evenly.',
        'Toss everything vigorously on high heat for 3 minutes.',
      ],
      cuisineType: 'Asian',
      prepTimeMinutes: 25,
      substituteOptions: [
        {'original': 'Chicken Breast', 'usedSubstitute': 'Tofu'},
        {'original': 'Rice', 'usedSubstitute': 'Quinoa'},
      ],
    ),
    RecipeTemplate(
      id: 'rec_3',
      title: 'Fluffy Spinach & Cheese Omelette',
      requiredIngredients: ['Eggs', 'Spinach', 'Cheese', 'Butter'],
      instructions: [
        'Whisk 2-3 eggs in a bowl with a pinch of salt.',
        'Melt butter in a non-stick skillet and lightly wilt the baby spinach.',
        'Pour beaten eggs over the spinach and cook on medium-low.',
        'Sprinkle shredded cheese on one half, fold over, and serve warm.',
      ],
      cuisineType: 'Continental',
      prepTimeMinutes: 12,
      substituteOptions: [
        {'original': 'Butter', 'usedSubstitute': 'Olive Oil'},
      ],
    ),
    RecipeTemplate(
      id: 'rec_4',
      title: 'Creamy Apple Cinnamon Oatmeal',
      requiredIngredients: ['Oats', 'Milk', 'Apples', 'Honey'],
      instructions: [
        'Combine rolled oats and milk in a small saucepan.',
        'Cook over medium heat for 4-5 minutes until thick and creamy.',
        'Dice fresh crisp apples into bite-sized cubes.',
        'Top warm oatmeal with diced apples, a drizzle of honey, and a pinch of cinnamon.',
      ],
      cuisineType: 'Breakfast',
      prepTimeMinutes: 10,
    ),
    RecipeTemplate(
      id: 'rec_5',
      title: 'Garlic Sautéed Baby Spinach',
      requiredIngredients: ['Spinach', 'Garlic', 'Olive Oil'],
      instructions: [
        'Wash and pat dry fresh baby spinach leaves.',
        'Warm extra virgin olive oil in a skillet and lightly toast sliced garlic.',
        'Add baby spinach in batches, tossing until just wilted (about 2 minutes).',
        'Season with sea salt and cracked black pepper.',
      ],
      cuisineType: 'Mediterranean',
      prepTimeMinutes: 8,
    ),
  ];

  @override
  FutureOr<Map<String, List<RecipeModel>>> build() {
    // Calculate dynamic matches synchronously based on active pantry inventory
    final inventoryState = ref.watch(inventoryControllerProvider);
    final currentIngredients = inventoryState.valueOrNull ?? [];
    final currentNames = currentIngredients.map((e) => e.name.toLowerCase()).toList();

    final List<RecipeModel> fullMatches = [];
    final List<RecipeModel> partialMatches = [];

    for (final template in _templates) {
      final List<String> missing = [];
      int matchedCount = 0;

      for (final req in template.requiredIngredients) {
        final reqLower = req.toLowerCase();
        final exists = currentNames.any((name) => name.contains(reqLower) || reqLower.contains(name));
        if (exists) {
          matchedCount++;
        } else {
          missing.add(req);
        }
      }

      final total = template.requiredIngredients.length;
      final matchPct = (matchedCount / total) * 100.0;

      final model = RecipeModel(
        id: template.id,
        title: template.title,
        instructions: template.instructions,
        cuisineType: template.cuisineType,
        prepTimeMinutes: template.prepTimeMinutes,
        matchPercentage: matchPct,
        missingIngredients: missing,
        substituteOptions: template.substituteOptions,
      );

      if (missing.isEmpty) {
        fullMatches.add(model);
      } else {
        partialMatches.add(model);
      }
    }

    // Sort partial matches by highest percentage first
    partialMatches.sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));

    return {
      'fullMatch': fullMatches,
      'partialMatch': partialMatches,
    };
  }
}
