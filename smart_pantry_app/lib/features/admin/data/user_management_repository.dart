import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../auth/data/models/user_model.dart';

class UserManagementRepository {
  final DioClient _dioClient;

  UserManagementRepository(this._dioClient);

  Future<List<UserModel>> getUsers() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.users);
      final list = (response.data['data']['users'] as List? ?? []);
      return list.map((json) => UserModel.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _dioClient.handleDioError(e);
    }
  }

  Future<UserModel> createUser({
    required String name,
    required String email,
    required String password,
    required List<String> allowedSections,
    String role = 'user',
    String accessMode = 'view_only',
    String shiftType = 'all_day',
    String? shiftStartTime,
    String? shiftEndTime,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.users,
        data: {
          'name': name,
          'email': email,
          'password': password,
          'role': role,
          'accessMode': accessMode,
          'allowedSections': allowedSections,
          'shiftType': shiftType,
          if (shiftStartTime != null) 'shiftStartTime': shiftStartTime,
          if (shiftEndTime != null) 'shiftEndTime': shiftEndTime,
        },
      );
      return UserModel.fromJson(response.data['data']['user']);
    } on DioException catch (e) {
      throw _dioClient.handleDioError(e);
    }
  }

  Future<UserModel> updateUser(
    String userId, {
    String? name,
    String? email,
    String? password,
    List<String>? allowedSections,
    String? role,
    String? accessMode,
    String? shiftType,
    String? shiftStartTime,
    String? shiftEndTime,
  }) async {
    try {
      final Map<String, dynamic> payload = {};
      if (name != null) payload['name'] = name;
      if (email != null) payload['email'] = email;
      if (password != null && password.isNotEmpty) payload['password'] = password;
      if (allowedSections != null) payload['allowedSections'] = allowedSections;
      if (role != null) payload['role'] = role;
      if (accessMode != null) payload['accessMode'] = accessMode;
      if (shiftType != null) payload['shiftType'] = shiftType;
      if (shiftStartTime != null) payload['shiftStartTime'] = shiftStartTime;
      if (shiftEndTime != null) payload['shiftEndTime'] = shiftEndTime;

      final response = await _dioClient.dio.patch(
        '${ApiConstants.users}/$userId',
        data: payload,
      );
      return UserModel.fromJson(response.data['data']['user']);
    } on DioException catch (e) {
      throw _dioClient.handleDioError(e);
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _dioClient.dio.delete('${ApiConstants.users}/$userId');
    } on DioException catch (e) {
      throw _dioClient.handleDioError(e);
    }
  }
}
