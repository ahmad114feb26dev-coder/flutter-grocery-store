import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';

class DioClient {
  late final Dio _dio;
  final SecureStorageService _storageService;
  final void Function()? onSessionExpired;

  DioClient(this._storageService, {this.onSessionExpired}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 25),
        responseType: ResponseType.json,
      ),
    );

    _dio.interceptors.addAll([
      AuthInterceptor(_dio, _storageService, onSessionExpired: onSessionExpired),
    ]);
  }

  Dio get dio => _dio;

  Exception handleDioError(DioException err) {
    if (err.response != null) {
      final data = err.response?.data;
      if (data is Map<String, dynamic> && data.containsKey('message')) {
        return ApiException(data['message'], statusCode: err.response?.statusCode);
      }
      return ApiException('Server error (${err.response?.statusCode}). Please try again.', statusCode: err.response?.statusCode);
    }
    final uri = err.requestOptions.uri;
    final errorDetail = err.error?.toString() ?? err.message ?? 'No response';
    return ApiException('Connection failed: [$uri] -> ${err.type.name}: $errorDetail');
  }
}
