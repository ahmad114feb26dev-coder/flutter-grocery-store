import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../models/user_model.dart';

class AuthRepository {
  final DioClient _dioClient;
  final SecureStorageService _storageService;

  AuthRepository(this._dioClient, this._storageService);

  Future<UserModel> login(String email, String password) async {
    try {
      final response = await _dioClient.dio.post(ApiConstants.login, data: {
        'email': email,
        'password': password,
      });

      final data = response.data['data'];
      await _storageService.saveTokens(
        accessToken: data['tokens']['accessToken'],
        refreshToken: data['tokens']['refreshToken'],
      );

      return UserModel.fromJson(data['user']);
    } on DioException catch (e) {
      throw _dioClient.handleDioError(e);
    }
  }

  Future<UserModel> register(String name, String email, String password) async {
    try {
      final response = await _dioClient.dio.post(ApiConstants.register, data: {
        'name': name,
        'email': email,
        'password': password,
      });

      final data = response.data['data'];
      await _storageService.saveTokens(
        accessToken: data['tokens']['accessToken'],
        refreshToken: data['tokens']['refreshToken'],
      );

      return UserModel.fromJson(data['user']);
    } on DioException catch (e) {
      throw _dioClient.handleDioError(e);
    }
  }

  Future<void> logout() async {
    try {
      await _dioClient.dio.post(ApiConstants.logout);
    } catch (_) {
      // Ignore errors on logout
    } finally {
      await _storageService.deleteTokens();
      await _storageService.deleteUserData();
    }
  }

  Future<UserModel> getMe() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.me);
      final data = response.data['data'];
      return UserModel.fromJson(data['user']);
    } on DioException catch (e) {
      throw _dioClient.handleDioError(e);
    }
  }
}
