import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:smart_pantry_app/core/providers/core_providers.dart';
import 'package:smart_pantry_app/features/inventory/data/models/ingredient_model.dart';
import 'package:smart_pantry_app/features/inventory/data/repositories/inventory_repository.dart';

part 'inventory_provider.g.dart';

@riverpod
InventoryRepository inventoryRepository(InventoryRepositoryRef ref) {
  return InventoryRepository(ref.watch(dioClientProvider));
}

@riverpod
class InventoryController extends _$InventoryController {
  @override
  FutureOr<List<IngredientModel>> build() async {
    try {
      final items = await ref.watch(inventoryRepositoryProvider).getInventory();
      return items;
    } catch (e) {
      return [];
    }
  }

  Future<void> addIngredient(IngredientModel ingredient) async {
    final repo = ref.read(inventoryRepositoryProvider);
    final savedItem = await repo.addIngredient(ingredient);
    
    final currentList = state.valueOrNull ?? [];
    final existingIndex = currentList.indexWhere((e) => e.id == savedItem.id);
    if (existingIndex != -1) {
      final updated = [...currentList];
      updated[existingIndex] = savedItem;
      state = AsyncValue.data(updated);
    } else {
      state = AsyncValue.data([savedItem, ...currentList]);
    }
  }

  Future<void> restock(String id, double amount) async {
    final repo = ref.read(inventoryRepositoryProvider);
    final updatedItem = await repo.restock(id, amount);
    
    final currentList = state.valueOrNull ?? [];
    state = AsyncValue.data(
      currentList.map((e) => e.id == id ? updatedItem : e).toList(),
    );
  }

  void applyLiveUpdate(IngredientModel updatedItem) {
    final currentList = state.valueOrNull ?? [];
    final idx = currentList.indexWhere((e) => e.id == updatedItem.id);
    if (idx != -1) {
      final updated = [...currentList];
      updated[idx] = updatedItem;
      state = AsyncValue.data(updated);
    } else {
      state = AsyncValue.data([updatedItem, ...currentList]);
    }
  }

  void applyFullListUpdate(List<IngredientModel> newList) {
    state = AsyncValue.data(newList);
  }

  void removeIngredient(String id) {
    final currentList = state.valueOrNull ?? [];
    state = AsyncValue.data(currentList.where((e) => e.id != id).toList());
  }

  Future<void> logUsage(String id, int dayOfMonth, double amount, {bool isOverwrite = true, String? reason}) async {
    final repo = ref.read(inventoryRepositoryProvider);
    final updatedItem = await repo.logUsage(id, dayOfMonth, amount, isOverwrite: isOverwrite, reason: reason);
    
    final currentList = state.valueOrNull ?? [];
    state = AsyncValue.data(
      currentList.map((e) => e.id == id ? updatedItem : e).toList(),
    );
  }

  Future<void> updateIngredient(String id, Map<String, dynamic> data) async {
    final repo = ref.read(inventoryRepositoryProvider);
    final updatedItem = await repo.updateIngredient(id, data);
    
    final currentList = state.valueOrNull ?? [];
    state = AsyncValue.data(
      currentList.map((e) => e.id == id ? updatedItem : e).toList(),
    );
  }

  Future<void> deleteIngredient(String id) async {
    final repo = ref.read(inventoryRepositoryProvider);
    await repo.deleteIngredient(id);
    
    final currentList = state.valueOrNull ?? [];
    state = AsyncValue.data(currentList.where((e) => e.id != id).toList());
  }

  Future<void> clearMonthDays() async {
    final repo = ref.read(inventoryRepositoryProvider);
    final updatedList = await repo.clearMonthDays();
    state = AsyncValue.data(updatedList);
  }

  Future<Map<String, dynamic>> closeMonth(String monthYear, {bool force = false}) async {
    final repo = ref.read(inventoryRepositoryProvider);
    final result = await repo.closeMonth(monthYear, force: force);
    final newItems = (result['newIngredients'] as List)
        .map((e) => IngredientModel.fromJson(e))
        .toList();
    state = AsyncValue.data(newItems);
    ref.invalidate(monthlyArchivesProvider);
    return result;
  }

  Future<void> deleteMonthlyArchive(String archiveId) async {
    final repo = ref.read(inventoryRepositoryProvider);
    await repo.deleteMonthlyArchive(archiveId);
    ref.invalidate(monthlyArchivesProvider);
  }
}

final monthlyArchivesProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.read(inventoryRepositoryProvider);
  return await repo.getMonthlyArchives();
});
