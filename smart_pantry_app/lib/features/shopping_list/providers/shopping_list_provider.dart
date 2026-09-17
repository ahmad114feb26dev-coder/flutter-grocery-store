import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:smart_pantry_app/core/providers/core_providers.dart';
import 'package:smart_pantry_app/features/shopping_list/data/models/shopping_list_item_model.dart';
import 'package:smart_pantry_app/features/shopping_list/data/repositories/shopping_list_repository.dart';
import 'package:smart_pantry_app/features/inventory/data/models/ingredient_model.dart';
import 'package:smart_pantry_app/features/inventory/providers/inventory_provider.dart';

part 'shopping_list_provider.g.dart';

@riverpod
ShoppingListRepository shoppingListRepository(ShoppingListRepositoryRef ref) {
  return ShoppingListRepository(ref.watch(dioClientProvider));
}

@riverpod
class ShoppingListController extends _$ShoppingListController {
  @override
  FutureOr<List<ShoppingListItemModel>> build() async {
    try {
      final items = await ref.watch(shoppingListRepositoryProvider).getShoppingList();
      return items;
    } catch (e) {
      return [];
    }
  }

  Future<void> addItem(
    String name,
    double quantity,
    String reason, {
    DateTime? date,
    bool resolved = false,
  }) async {
    final repo = ref.read(shoppingListRepositoryProvider);
    final newItem = await repo.addItem(
      name,
      quantity,
      reason.isEmpty ? 'manual' : reason,
      date: date,
      resolved: resolved,
    );
    
    final currentList = state.valueOrNull ?? [];
    state = AsyncValue.data([newItem, ...currentList]);
  }

  Future<void> toggleResolved(String id, bool resolved) async {
    final currentList = state.valueOrNull ?? [];
    final existing = currentList.firstWhere((e) => e.id == id, orElse: () => currentList.first);
    if (existing.movedToPantry && !resolved) {
      // Cannot uncheck an item that has already moved to pantry
      return;
    }

    final repo = ref.read(shoppingListRepositoryProvider);
    final updatedItem = await repo.updateItem(id, {
      'resolved': resolved,
      'boughtAt': resolved ? DateTime.now().toIso8601String() : null,
    });
    
    state = AsyncValue.data(
      currentList.map((e) => e.id == id ? updatedItem : e).toList(),
    );
  }

  Future<void> updateQuantity(String id, double newQuantity) async {
    if (newQuantity <= 0) return;
    final repo = ref.read(shoppingListRepositoryProvider);
    final updatedItem = await repo.updateItem(id, {
      'quantityNeeded': newQuantity,
    });

    final currentList = state.valueOrNull ?? [];
    state = AsyncValue.data(
      currentList.map((e) => e.id == id ? updatedItem : e).toList(),
    );
  }

  Future<void> toggleFreezeAll({List<String>? itemIds, bool freeze = true}) async {
    final repo = ref.read(shoppingListRepositoryProvider);
    try {
      final updatedList = await repo.finalizeShoppingList(ids: itemIds, isFrozen: freeze);
      state = AsyncValue.data(updatedList);
    } catch (e) {
      final currentList = state.valueOrNull ?? [];
      state = AsyncValue.data(
        currentList.map((e) {
          if (itemIds == null || itemIds.contains(e.id)) {
            return e.copyWith(isFrozen: freeze);
          }
          return e;
        }).toList(),
      );
    }
  }

  Future<void> deleteItem(String id) async {
    final currentList = state.valueOrNull ?? [];
    final item = currentList.firstWhere((e) => e.id == id, orElse: () => currentList.first);
    if (item.isFrozen) return; // Prevent deleting frozen items

    final repo = ref.read(shoppingListRepositoryProvider);
    await repo.deleteItem(id);
    state = AsyncValue.data(currentList.where((e) => e.id != id).toList());
  }

  Future<void> clearCompleted() async {
    final currentList = state.valueOrNull ?? [];
    final toDelete = currentList.where((e) => e.resolved).toList();
    final repo = ref.read(shoppingListRepositoryProvider);

    for (final item in toDelete) {
      if (item.id != null) {
        try {
          await repo.deleteItem(item.id!);
        } catch (_) {}
      }
    }

    final toKeep = currentList.where((e) => !e.resolved).toList();
    state = AsyncValue.data(toKeep);
  }

  Future<void> movePurchasedToPantry() async {
    final currentList = state.valueOrNull ?? [];
    final resolvedItems = currentList.where((e) => e.resolved && !e.movedToPantry).toList();
    if (resolvedItems.isEmpty) return;

    final repo = ref.read(shoppingListRepositoryProvider);

    for (final item in resolvedItems) {
      // Add to inventory (persists directly to MongoDB)
      await ref.read(inventoryControllerProvider.notifier).addIngredient(
        IngredientModel(
          name: item.ingredientName,
          quantity: item.quantityNeeded,
          unit: 'pcs',
          category: 'Pantry',
          expiryDate: DateTime.now().add(const Duration(days: 14)),
          daysLeft: 14,
        ),
      );

      // Preserve in shopping history with movedToPantry: true
      if (item.id != null) {
        try {
          await repo.updateItem(item.id!, {
            'movedToPantry': true,
            'resolved': true,
            'boughtAt': (item.boughtAt ?? DateTime.now()).toIso8601String(),
          });
        } catch (_) {}
      }
    }

    try {
      final items = await repo.getShoppingList();
      state = AsyncValue.data(items);
    } catch (_) {}
  }
}
