import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';

class AuthInterceptor extends Interceptor {
  final Dio dio;
  final SecureStorageService storageService;
  final void Function()? onSessionExpired;

  // Single-flight mutex for refreshing tokens to prevent concurrent request race conditions
  Future<String?>? _refreshFuture;

  AuthInterceptor(this.dio, this.storageService, {this.onSessionExpired});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final accessToken = await storageService.getAccessToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    return super.onRequest(options, handler);
  }

  Future<String?> _performTokenRefresh() async {
    final refreshToken = await storageService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    try {
      // Use clean standalone Dio without interceptor to prevent any recursion
      final standaloneDio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          responseType: ResponseType.json,
        ),
      );

      final response = await standaloneDio.post(ApiConstants.refreshToken, data: {
        'refreshToken': refreshToken,
      });

      if (response.statusCode == 200) {
        final newAccessToken = response.data['data']?['tokens']?['accessToken'] as String?;
        final newRefreshToken = response.data['data']?['tokens']?['refreshToken'] as String?;

        if (newAccessToken != null && newRefreshToken != null) {
          await storageService.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );
          return newAccessToken;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final path = err.requestOptions.path;
    final isAuthRoute = path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/logout') ||
        path.contains('/auth/refresh-token');

    // Never intercept auth routes (login, register, logout, refresh-token) with refresh/expiry logic
    if (err.response?.statusCode == 401 && !isAuthRoute) {
      // Coalesce all concurrent 401s into a single refresh call
      _refreshFuture ??= _performTokenRefresh();
      final newAccessToken = await _refreshFuture;
      _refreshFuture = null;

      if (newAccessToken != null && newAccessToken.isNotEmpty) {
        try {
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newAccessToken';
          final cloneReq = await dio.request(
            opts.path,
            options: Options(
              method: opts.method,
              headers: opts.headers,
            ),
            data: opts.data,
            queryParameters: opts.queryParameters,
          );
          return handler.resolve(cloneReq);
        } catch (retryError) {
          if (retryError is DioException) {
            return handler.next(retryError);
          }
        }
      } else {
        // Refresh token invalid or expired: clear storage and signal session expiry
        await storageService.deleteTokens();
        await storageService.deleteUserData();
        onSessionExpired?.call();
      }
    }

    return super.onError(err, handler);
  }
}
