// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shopping_list_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$shoppingListRepositoryHash() =>
    r'1d24578eb7916aebc777c267b19932738664ee2d';

/// See also [shoppingListRepository].
@ProviderFor(shoppingListRepository)
final shoppingListRepositoryProvider =
    AutoDisposeProvider<ShoppingListRepository>.internal(
  shoppingListRepository,
  name: r'shoppingListRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$shoppingListRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ShoppingListRepositoryRef
    = AutoDisposeProviderRef<ShoppingListRepository>;
String _$shoppingListControllerHash() =>
    r'15f7b37028ff60e83019ee999a10b04bc88a4201';

/// See also [ShoppingListController].
@ProviderFor(ShoppingListController)
final shoppingListControllerProvider = AutoDisposeAsyncNotifierProvider<
    ShoppingListController, List<ShoppingListItemModel>>.internal(
  ShoppingListController.new,
  name: r'shoppingListControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$shoppingListControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ShoppingListController
    = AutoDisposeAsyncNotifier<List<ShoppingListItemModel>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
