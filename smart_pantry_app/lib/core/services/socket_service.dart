import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/api_constants.dart';
import 'audio_alarm_service.dart';
import '../../features/admin/providers/user_management_provider.dart';
import '../../features/auth/data/models/user_model.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/inventory/data/models/ingredient_model.dart';
import '../../features/inventory/providers/inventory_provider.dart';
import '../../features/shopping_list/providers/shopping_list_provider.dart';

class LiveUsageAlert {
  final String ingredientId;
  final String ingredientName;
  final int dayOfMonth;
  final double amount;
  final String unit;
  final String staffName;
  final String staffEmail;
  final String staffRole;
  final DateTime timestamp;

  LiveUsageAlert({
    required this.ingredientId,
    required this.ingredientName,
    required this.dayOfMonth,
    required this.amount,
    required this.unit,
    required this.staffName,
    required this.staffEmail,
    required this.staffRole,
    required this.timestamp,
  });
}

final activeLiveAlertProvider = StateProvider<LiveUsageAlert?>((ref) => null);
final activeClearedDaysBannerProvider = StateProvider<String?>((ref) => null);

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService(ref);
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

class SocketService {
  final Ref _ref;
  io.Socket? _socket;
  Timer? _alertDismissTimer;
  Timer? _bannerDismissTimer;
  bool _isConnecting = false;

  SocketService(this._ref);

  void init() {
    if (_socket != null || _isConnecting) return;
    _isConnecting = true;

    final socketUrl = ApiConstants.socketUrl;
    debugPrint('[SocketService] Connecting to Socket.IO at $socketUrl');

    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket?.onConnect((_) {
      _isConnecting = false;
      debugPrint('[SocketService] Connected to server successfully (socket id: ${_socket?.id})');
      _joinStoreRoom();
    });

    _socket?.onDisconnect((_) {
      debugPrint('[SocketService] Disconnected from server');
    });

    _socket?.onConnectError((err) {
      _isConnecting = false;
      debugPrint('[SocketService] Connect error: $err');
    });

    _socket?.on('inventory_usage_logged', (rawData) {
      _handleUsageLoggedEvent(rawData);
    });

    _socket?.on('inventory_cleared_days', (rawData) {
      _handleClearedDaysEvent(rawData);
    });

    _socket?.on('inventory_month_closed', (rawData) {
      _handleMonthClosedEvent(rawData);
    });

    _socket?.on('inventory_item_added', (rawData) {
      _handleItemAddedEvent(rawData);
    });

    _socket?.on('inventory_item_updated', (rawData) {
      _handleItemUpdatedEvent(rawData);
    });

    _socket?.on('inventory_item_deleted', (rawData) {
      _handleItemDeletedEvent(rawData);
    });

    _socket?.on('user_permissions_updated', (rawData) {
      _handleUserPermissionsUpdated(rawData);
    });

    // Re-join rooms if user profile changes or logs in
    _ref.listen<AsyncValue<dynamic>>(authControllerProvider, (prev, next) {
      if (next.valueOrNull != null && _socket != null && _socket!.connected) {
        _joinStoreRoom();
      }
    });
  }

  void _joinStoreRoom() {
    final user = _ref.read(authControllerProvider).valueOrNull;
    if (user != null) {
      final storeOwnerId = user.storeOwnerId;
      if (storeOwnerId != null && storeOwnerId.isNotEmpty) {
        _socket?.emit('join_store', storeOwnerId);
        debugPrint('[SocketService] Emitted join_store for storeOwnerId: $storeOwnerId');
      }
      if (user.id != null && user.id != storeOwnerId) {
        _socket?.emit('join_store', user.id);
        debugPrint('[SocketService] Emitted join_store for userId: ${user.id}');
      }
    }
    _socket?.emit('join_store', 'pantry_store');
    debugPrint('[SocketService] Emitted join_store for pantry_store');
  }

  void _handleUsageLoggedEvent(dynamic rawData) {
    try {
      debugPrint('[SocketService] Event received: inventory_usage_logged -> $rawData');
      if (rawData is! Map) return;

      final data = Map<String, dynamic>.from(rawData);
      final rawIngredient = data['updatedIngredient'];
      if (rawIngredient is Map) {
        final updated = IngredientModel.fromJson(Map<String, dynamic>.from(rawIngredient));
        _ref.read(inventoryControllerProvider.notifier).applyLiveUpdate(updated);
        // Refresh shopping list if needed
        _ref.invalidate(shoppingListControllerProvider);
      }

      final loggedBy = data['loggedBy'] as Map? ?? {};
      final staffId = loggedBy['id']?.toString() ?? '';
      final staffName = loggedBy['name']?.toString() ?? 'Staff User';
      final staffEmail = loggedBy['email']?.toString() ?? '';
      final staffRole = loggedBy['role']?.toString() ?? 'user';

      final currentUser = _ref.read(authControllerProvider).valueOrNull;
      final isSelf = currentUser != null && currentUser.id == staffId;

      final alert = LiveUsageAlert(
        ingredientId: data['ingredientId']?.toString() ?? '',
        ingredientName: data['ingredientName']?.toString() ?? 'Item',
        dayOfMonth: (data['dayOfMonth'] as num?)?.toInt() ?? 1,
        amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
        unit: data['unit']?.toString() ?? '',
        staffName: staffName,
        staffEmail: staffEmail,
        staffRole: staffRole,
        timestamp: DateTime.tryParse(data['timestamp']?.toString() ?? '') ?? DateTime.now(),
      );

      // Trigger notification and sound for Admin (or any user viewing who did not enter it)
      if (!isSelf) {
        // 1. Play audible alarm chime!
        AudioAlarmService.playAlarmChime();

        // 2. Set active alert banner
        _ref.read(activeLiveAlertProvider.notifier).state = alert;

        // Auto dismiss after 8 seconds
        _alertDismissTimer?.cancel();
        _alertDismissTimer = Timer(const Duration(seconds: 8), () {
          if (_ref.read(activeLiveAlertProvider) == alert) {
            _ref.read(activeLiveAlertProvider.notifier).state = null;
          }
        });
      }
    } catch (e, st) {
      debugPrint('[SocketService] Error processing event: $e\n$st');
    }
  }

  void _handleClearedDaysEvent(dynamic rawData) {
    try {
      debugPrint('[SocketService] Event received: inventory_cleared_days -> $rawData');
      if (rawData is Map) {
        final data = Map<String, dynamic>.from(rawData);
        final rawList = data['updatedIngredients'];
        if (rawList is List && rawList.isNotEmpty) {
          final updatedList = <IngredientModel>[];
          for (final itemJson in rawList) {
            try {
              final map = Map<String, dynamic>.from(itemJson as Map);
              updatedList.add(IngredientModel.fromJson(map));
            } catch (itemErr) {
              debugPrint('[SocketService] Error parsing item in clear_days: $itemErr');
            }
          }

          if (updatedList.isNotEmpty) {
            // Instant real-time state update
            _ref.read(inventoryControllerProvider.notifier).applyFullListUpdate(updatedList);
            _ref.invalidate(shoppingListControllerProvider);

            // Play audible chime alert
            AudioAlarmService.playAlarmChime();

            // Set visual alert banner on screen
            final clearedBy = data['clearedBy'] as Map? ?? {};
            final adminName = clearedBy['name']?.toString() ?? 'Admin';
            _ref.read(activeClearedDaysBannerProvider.notifier).state =
                '✨ $adminName ne tamam days (1–31) ka usage data clear kar diya hai! Stock balance restore ho gaya hai.';

            _bannerDismissTimer?.cancel();
            _bannerDismissTimer = Timer(const Duration(seconds: 10), () {
              _ref.read(activeClearedDaysBannerProvider.notifier).state = null;
            });
            return;
          }
        }
      }
      _ref.invalidate(inventoryControllerProvider);
      _ref.invalidate(shoppingListControllerProvider);
    } catch (e, st) {
      debugPrint('[SocketService] Error processing inventory_cleared_days: $e\n$st');
      _ref.invalidate(inventoryControllerProvider);
    }
  }

  void _handleMonthClosedEvent(dynamic rawData) {
    try {
      debugPrint('[SocketService] Event received: inventory_month_closed -> $rawData');
      if (rawData is Map) {
        final data = Map<String, dynamic>.from(rawData);
        final rawList = data['newIngredients'];
        if (rawList is List && rawList.isNotEmpty) {
          final updatedList = <IngredientModel>[];
          for (final itemJson in rawList) {
            try {
              final map = Map<String, dynamic>.from(itemJson as Map);
              updatedList.add(IngredientModel.fromJson(map));
            } catch (itemErr) {
              debugPrint('[SocketService] Error parsing item in month_closed: $itemErr');
            }
          }
          if (updatedList.isNotEmpty) {
            _ref.read(inventoryControllerProvider.notifier).applyFullListUpdate(updatedList);
          }
        }

        // Trigger alarm chime
        AudioAlarmService.playAlarmChime();

        // Show prominent visual banner
        final closedBy = data['closedBy'] as Map? ?? {};
        final adminName = closedBy['name']?.toString() ?? 'Admin';
        final monthLabel = data['monthYear']?.toString() ?? '';
        _ref.read(activeClearedDaysBannerProvider.notifier).state =
            '🗓️ $adminName ne $monthLabel ka mahina close kar diya hai! Naye mahine ke liye stock rollover ho chuka hai aur sheet clear ho gayi hai.';

        _bannerDismissTimer?.cancel();
        _bannerDismissTimer = Timer(const Duration(seconds: 10), () {
          _ref.read(activeClearedDaysBannerProvider.notifier).state = null;
        });
      }
      _ref.invalidate(inventoryControllerProvider);
      _ref.invalidate(monthlyArchivesProvider);
      _ref.invalidate(shoppingListControllerProvider);
    } catch (e, st) {
      debugPrint('[SocketService] Error processing inventory_month_closed: $e\n$st');
      _ref.invalidate(inventoryControllerProvider);
    }
  }

  void _handleItemAddedEvent(dynamic rawData) {
    try {
      if (rawData is Map) {
        final data = Map<String, dynamic>.from(rawData);
        final rawIngredient = data['ingredient'];
        if (rawIngredient is Map) {
          final item = IngredientModel.fromJson(Map<String, dynamic>.from(rawIngredient));
          _ref.read(inventoryControllerProvider.notifier).applyLiveUpdate(item);
        }
      }
      _ref.invalidate(inventoryControllerProvider);
    } catch (e) {
      _ref.invalidate(inventoryControllerProvider);
    }
  }

  void _handleItemUpdatedEvent(dynamic rawData) {
    try {
      if (rawData is Map) {
        final data = Map<String, dynamic>.from(rawData);
        final rawIngredient = data['ingredient'];
        if (rawIngredient is Map) {
          final item = IngredientModel.fromJson(Map<String, dynamic>.from(rawIngredient));
          _ref.read(inventoryControllerProvider.notifier).applyLiveUpdate(item);
        }
      }
      _ref.invalidate(inventoryControllerProvider);
      _ref.invalidate(shoppingListControllerProvider);
    } catch (e) {
      _ref.invalidate(inventoryControllerProvider);
    }
  }

  void _handleItemDeletedEvent(dynamic rawData) {
    try {
      if (rawData is Map) {
        final data = Map<String, dynamic>.from(rawData);
        final id = data['id']?.toString();
        if (id != null) {
          _ref.read(inventoryControllerProvider.notifier).removeIngredient(id);
        }
      }
      _ref.invalidate(inventoryControllerProvider);
      _ref.invalidate(shoppingListControllerProvider);
    } catch (e) {
      _ref.invalidate(inventoryControllerProvider);
    }
  }

  void _handleUserPermissionsUpdated(dynamic rawData) {
    try {
      debugPrint('[SocketService] Event received: user_permissions_updated -> $rawData');
      if (rawData is! Map) return;

      final data = Map<String, dynamic>.from(rawData);
      final rawUser = data['user'];
      if (rawUser is Map) {
        final updatedUser = UserModel.fromJson(Map<String, dynamic>.from(rawUser));
        final currentUser = _ref.read(authControllerProvider).valueOrNull;

        if (currentUser != null &&
            (currentUser.id == updatedUser.id || currentUser.email == updatedUser.email)) {
          debugPrint('[SocketService] Updating current user shift & permissions in real time!');
          _ref.read(authControllerProvider.notifier).updateCurrentUser(updatedUser);

          // Play alarm chime so user notices shift change
          AudioAlarmService.playAlarmChime();

          // Set live notification alert banner
          final shiftText = updatedUser.isShiftRestricted
              ? 'Shift: ${updatedUser.shiftDisplayLabel}'
              : 'All Day 24h Access';
          _ref.read(activeLiveAlertProvider.notifier).state = LiveUsageAlert(
            ingredientId: '',
            ingredientName: 'Shift / Permissions Updated',
            dayOfMonth: DateTime.now().day,
            amount: 0,
            unit: shiftText,
            staffName: 'Admin',
            staffEmail: '',
            staffRole: 'admin',
            timestamp: DateTime.now(),
          );

          _alertDismissTimer?.cancel();
          _alertDismissTimer = Timer(const Duration(seconds: 8), () {
            _ref.read(activeLiveAlertProvider.notifier).state = null;
          });
        }
      }

      // Invalidate usersListProvider so Admin panel shows changes in real-time
      _ref.invalidate(usersListProvider);
    } catch (e) {
      debugPrint('[SocketService] Error handling user_permissions_updated: $e');
    }
  }

  void dismissAlert() {
    _alertDismissTimer?.cancel();
    _ref.read(activeLiveAlertProvider.notifier).state = null;
  }

  void dispose() {
    _alertDismissTimer?.cancel();
    _bannerDismissTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
