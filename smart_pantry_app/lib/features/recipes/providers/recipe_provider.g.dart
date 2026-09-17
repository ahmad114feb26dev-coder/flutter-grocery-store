// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$recipeRepositoryHash() => r'030ee7553194ff419bff79aebaba48e423fcdf59';

/// See also [recipeRepository].
@ProviderFor(recipeRepository)
final recipeRepositoryProvider = AutoDisposeProvider<RecipeRepository>.internal(
  recipeRepository,
  name: r'recipeRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$recipeRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef RecipeRepositoryRef = AutoDisposeProviderRef<RecipeRepository>;
String _$recipeControllerHash() => r'387ca4748221cd75e7ebdad126ee11a09950cca1';

/// See also [RecipeController].
@ProviderFor(RecipeController)
final recipeControllerProvider = AutoDisposeAsyncNotifierProvider<
    RecipeController, Map<String, List<RecipeModel>>>.internal(
  RecipeController.new,
  name: r'recipeControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$recipeControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$RecipeController
    = AutoDisposeAsyncNotifier<Map<String, List<RecipeModel>>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
