import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/providers/core_providers.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../shopping_list/providers/shopping_list_provider.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';

part 'auth_provider.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepository(
    ref.watch(dioClientProvider),
    ref.watch(secureStorageProvider),
  );
}

@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  FutureOr<UserModel?> build() async {
    final storage = ref.read(secureStorageProvider);
    final accessToken = await storage.getAccessToken();

    // If no access token exists, user is not authenticated
    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    final userJson = await storage.getUserData();
    UserModel? cachedUser;
    if (userJson != null) {
      try {
        final map = jsonDecode(userJson) as Map<String, dynamic>;
        cachedUser = UserModel.fromJson(map);
      } catch (_) {}
    }

    // If cached user exists, return immediately so the UI renders instantly without flashing
    if (cachedUser != null) {
      final repo = ref.read(authRepositoryProvider);
      repo.getMe().then((freshUser) async {
        await storage.saveUserData(jsonEncode(freshUser.toJson()));
        state = AsyncValue.data(freshUser);
      }).catchError((_) {
        // Any 401 is cleanly handled by AuthInterceptor (refresh token or onSessionExpired)
      });
      return cachedUser;
    }

    try {
      final repo = ref.read(authRepositoryProvider);
      final freshUser = await repo.getMe();
      await storage.saveUserData(jsonEncode(freshUser.toJson()));
      return freshUser;
    } catch (e) {
      return null;
    }
  }

  Future<UserModel> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.login(email, password);
      final storage = ref.read(secureStorageProvider);
      await storage.saveUserData(jsonEncode(user.toJson()));
      state = AsyncValue.data(user);
      ref.invalidate(inventoryControllerProvider);
      ref.invalidate(shoppingListControllerProvider);
      ref.invalidate(monthlyArchivesProvider);
      return user;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.register(name, email, password);
      final storage = ref.read(secureStorageProvider);
      await storage.saveUserData(jsonEncode(user.toJson()));
      ref.invalidate(inventoryControllerProvider);
      ref.invalidate(shoppingListControllerProvider);
      ref.invalidate(monthlyArchivesProvider);
      return user;
    });
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (_) {
    } finally {
      final storage = ref.read(secureStorageProvider);
      await storage.deleteTokens();
      await storage.deleteUserData();
      ref.invalidate(inventoryControllerProvider);
      ref.invalidate(shoppingListControllerProvider);
      ref.invalidate(monthlyArchivesProvider);
      state = const AsyncValue.data(null);
    }
  }

  Future<void> handleSessionExpired() async {
    final storage = ref.read(secureStorageProvider);
    await storage.deleteTokens();
    await storage.deleteUserData();
    ref.invalidate(inventoryControllerProvider);
    ref.invalidate(shoppingListControllerProvider);
    ref.invalidate(monthlyArchivesProvider);
    state = const AsyncValue.data(null);
  }

  Future<UserModel?> refreshProfile() async {
    final storage = ref.read(secureStorageProvider);
    final accessToken = await storage.getAccessToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      try {
        final repo = ref.read(authRepositoryProvider);
        final freshUser = await repo.getMe();
        await storage.saveUserData(jsonEncode(freshUser.toJson()));
        state = AsyncValue.data(freshUser);
        return freshUser;
      } catch (_) {}
    }
    return state.valueOrNull;
  }

  void updateCurrentUser(UserModel updated) {
    final storage = ref.read(secureStorageProvider);
    storage.saveUserData(jsonEncode(updated.toJson()));
    state = AsyncValue.data(updated);
  }
}
