import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../models/recipe_model.dart';

class RecipeRepository {
  final DioClient _dioClient;

  RecipeRepository(this._dioClient);

  Future<Map<String, List<RecipeModel>>> getSuggestions() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.recipeSuggestions);
      final data = response.data['data'];
      
      final fullMatch = (data['fullMatch'] as List)
          .map((json) => RecipeModel.fromJson(json))
          .toList();
          
      final partialMatch = (data['partialMatch'] as List)
          .map((json) => RecipeModel.fromJson(json))
          .toList();

      return {
        'fullMatch': fullMatch,
        'partialMatch': partialMatch,
      };
    } on DioException catch (e) {
      throw _dioClient.handleDioError(e);
    }
  }
}
