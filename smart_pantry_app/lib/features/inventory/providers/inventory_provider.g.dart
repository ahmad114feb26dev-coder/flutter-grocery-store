// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$inventoryRepositoryHash() =>
    r'bbfcfe60491a0bd432581996c621e209c2a17e53';

/// See also [inventoryRepository].
@ProviderFor(inventoryRepository)
final inventoryRepositoryProvider =
    AutoDisposeProvider<InventoryRepository>.internal(
  inventoryRepository,
  name: r'inventoryRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$inventoryRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef InventoryRepositoryRef = AutoDisposeProviderRef<InventoryRepository>;
String _$inventoryControllerHash() =>
    r'eedfbe30b9b0b5e113d2e128bee0489af9bbc1a0';

/// See also [InventoryController].
@ProviderFor(InventoryController)
final inventoryControllerProvider = AutoDisposeAsyncNotifierProvider<
    InventoryController, List<IngredientModel>>.internal(
  InventoryController.new,
  name: r'inventoryControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$inventoryControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$InventoryController = AutoDisposeAsyncNotifier<List<IngredientModel>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
