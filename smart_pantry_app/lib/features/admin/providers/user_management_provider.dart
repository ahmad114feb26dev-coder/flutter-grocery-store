import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/core_providers.dart';
import '../../auth/data/models/user_model.dart';
import '../data/user_management_repository.dart';

final userManagementRepositoryProvider = Provider<UserManagementRepository>((ref) {
  return UserManagementRepository(ref.watch(dioClientProvider));
});

class UsersListNotifier extends StateNotifier<AsyncValue<List<UserModel>>> {
  final UserManagementRepository _repository;

  UsersListNotifier(this._repository) : super(const AsyncValue.loading()) {
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    state = const AsyncValue.loading();
    try {
      final users = await _repository.getUsers();
      state = AsyncValue.data(users);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
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
    final newUser = await _repository.createUser(
      name: name,
      email: email,
      password: password,
      allowedSections: allowedSections,
      role: role,
      accessMode: accessMode,
      shiftType: shiftType,
      shiftStartTime: shiftStartTime,
      shiftEndTime: shiftEndTime,
    );
    await fetchUsers();
    return newUser;
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
    final updated = await _repository.updateUser(
      userId,
      name: name,
      email: email,
      password: password,
      allowedSections: allowedSections,
      role: role,
      accessMode: accessMode,
      shiftType: shiftType,
      shiftStartTime: shiftStartTime,
      shiftEndTime: shiftEndTime,
    );
    await fetchUsers();
    return updated;
  }

  Future<void> deleteUser(String userId) async {
    await _repository.deleteUser(userId);
    await fetchUsers();
  }
}

final usersListProvider =
    StateNotifierProvider<UsersListNotifier, AsyncValue<List<UserModel>>>((ref) {
  final repo = ref.watch(userManagementRepositoryProvider);
  return UsersListNotifier(repo);
});
