import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../models/shopping_list_item_model.dart';

class ShoppingListRepository {
  final DioClient _dioClient;

  ShoppingListRepository(this._dioClient);

  Future<List<ShoppingListItemModel>> getShoppingList() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.shoppingList);
      final List<dynamic> data = response.data['data']['items'];
      return data.map((json) => ShoppingListItemModel.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _dioClient.handleDioError(e);
    }
  }

  Future<ShoppingListItemModel> addItem(
    String name,
    double quantityNeeded,
    String reason, {
    DateTime? date,
    bool resolved = false,
  }) async {
    try {
      final response = await _dioClient.dio.post(ApiConstants.shoppingList, data: {
        'ingredientName': name,
        'quantityNeeded': quantityNeeded,
        'addedReason': reason,
        if (resolved) 'resolved': true,
        if (date != null) 'boughtAt': date.toIso8601String(),
        if (date != null) 'createdAt': date.toIso8601String(),
      });
      return ShoppingListItemModel.fromJson(response.data['data']['item']);
    } on DioException catch (e) {
      throw _dioClient.handleDioError(e);
    }
  }

  Future<ShoppingListItemModel> updateItem(String id, Map<String, dynamic> updateData) async {
    try {
      final response = await _dioClient.dio.patch('${ApiConstants.shoppingList}/$id', data: updateData);
      return ShoppingListItemModel.fromJson(response.data['data']['item']);
    } on DioException catch (e) {
      throw _dioClient.handleDioError(e);
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      await _dioClient.dio.delete('${ApiConstants.shoppingList}/$id');
    } on DioException catch (e) {
      throw _dioClient.handleDioError(e);
    }
  }

  Future<List<ShoppingListItemModel>> finalizeShoppingList({
    List<String>? ids,
    bool isFrozen = true,
  }) async {
    try {
      final response = await _dioClient.dio.patch(
        '${ApiConstants.shoppingList}/finalize',
        data: {
          if (ids != null) 'ids': ids,
          'isFrozen': isFrozen,
        },
      );
      final List<dynamic> data = response.data['data']['items'];
      return data.map((json) => ShoppingListItemModel.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _dioClient.handleDioError(e);
    }
  }
}
