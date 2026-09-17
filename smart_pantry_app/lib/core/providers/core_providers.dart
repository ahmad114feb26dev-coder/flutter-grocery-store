import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/secure_storage_service.dart';

part 'core_providers.g.dart';

final sessionExpirySignalProvider = StateProvider<int>((ref) => 0);

@Riverpod(keepAlive: true)
SecureStorageService secureStorage(SecureStorageRef ref) {
  return SecureStorageService();
}

@Riverpod(keepAlive: true)
DioClient dioClient(DioClientRef ref) {
  final storage = ref.watch(secureStorageProvider);
  return DioClient(
    storage,
    onSessionExpired: () {
      ref.read(sessionExpirySignalProvider.notifier).state++;
    },
  );
}
