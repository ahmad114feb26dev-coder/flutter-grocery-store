import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../models/ingredient_model.dart';

class InventoryRepository {
  final DioClient _dioClient;

  InventoryRepository(this._dioClient);

  Future<List<IngredientModel>> getInventory() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.inventory);
      final List<dynamic> data = response.data['data']['ingredients'];
      return data.map((json) => IngredientModel.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _dioClient.handleDioError(e);
    }
  }

  Future<IngredientModel> addIngredient(IngredientModel ingredient) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.inventory,
        data: ingredient.toJson(),
      );
      return IngredientModel.fromJson(response.data['data']['ingredient']);
    } on DioException catch (e) {
      throw _dioClient.handleDioError(e);
    }
  }

  Future<IngredientModel> updateIngredient(String id, Map<String, dynamic> updateData) async {
    try {
      final response = await _dioClient.dio.patch(
        '${ApiConstants.inventory}/$id',
        data: updateData,
      );
      return IngredientModel.fromJson(response.data['data']['ingredient']);
    } on DioException catch (e) {
      throw _dioClient.handleDioError(e);
    }
  }

  Future<IngredientModel> restock(String id, double addedQuantity) async {
    try {
      final response = await _dioClient.dio.post(
        '${ApiConstants.inventory}/$id/restock',
        data: {'addedQuantity': addedQuantity},
      );
      return IngredientModel.fromJson(response.data['data']['ingredient']);
    } on DioException catch (e) {
      throw _dioClient.handleDioError(e);
    }
  }

  Future<IngredientModel> logUsage(String id, int dayOfMonth, double amount, {bool isOverwrite = true, String? reason}) async {
    try {
      final response = await _dioClient.dio.post(
        '${ApiConstants.inventory}/$id/usage',
        data: {
          'dayOfMonth': dayOfMonth,
          'amount': amount,
          'isOverwrite': isOverwrite,
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        },
      );
      return IngredientModel.fromJson(response.data['data']['ingredient']);
    } on DioException catch (e) {
      throw _dioClient.handleDioError(e);
    }
  }

  Future<void> deleteIngredient(String id) async {
    try {
      await _dioClient.dio.delete('${ApiConstants.inventory}/$id');
    } on DioException catch (e) {
      throw _dioClient.handleDioError(e);
    }
  }

  Future<List<IngredientModel>> clearMonthDays() async {
    try {
      final response = await _dioClient.dio.post('${ApiConstants.inventory}/clear-days');
      final list = (response.data['data']['ingredients'] as List)
          .map((e) => IngredientModel.fromJson(e))
          .toList();
      return list;
    } on DioException catch (e) {
      throw _dioClient.handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> closeMonth(String monthYear, {bool force = false}) async {
    try {
      final response = await _dioClient.dio.post(
        '${ApiConstants.inventory}/close-month',
        data: {'monthYear': monthYear, 'force': force},
      );
      return response.data['data'];
    } on DioException catch (e) {
      throw _dioClient.handleDioError(e);
    }
  }

  Future<List<dynamic>> getMonthlyArchives() async {
    try {
      final response = await _dioClient.dio.get('${ApiConstants.inventory}/archives');
      return response.data['data']['archives'] as List<dynamic>;
    } on DioException catch (e) {
      throw _dioClient.handleDioError(e);
    }
  }

  Future<void> deleteMonthlyArchive(String archiveId) async {
    try {
      await _dioClient.dio.delete('${ApiConstants.inventory}/archives/$archiveId');
    } on DioException catch (e) {
      throw _dioClient.handleDioError(e);
    }
  }
}
