import 'dart:async';
import 'alarm_audio.dart';
import '../data/models/ingredient_model.dart';

class LowStockAlarmService {
  static final LowStockAlarmService _instance = LowStockAlarmService._internal();
  factory LowStockAlarmService() => _instance;
  LowStockAlarmService._internal();

  Timer? _twoHourTimer;
  DateTime? _lastAlarmTriggerTime;
  static const Duration alarmInterval = Duration(hours: 2);
  static const double lowStockThreshold = 3.0;

  // Stream controller to notify UI when an alarm is triggered
  final _alarmStreamController = StreamController<List<IngredientModel>>.broadcast();
  Stream<List<IngredientModel>> get onAlarmTriggered => _alarmStreamController.stream;

  DateTime? get lastAlarmTime => _lastAlarmTriggerTime;
  Duration? get timeUntilNextAlarm {
    if (_lastAlarmTriggerTime == null) return Duration.zero;
    final elapsed = DateTime.now().difference(_lastAlarmTriggerTime!);
    if (elapsed >= alarmInterval) return Duration.zero;
    return alarmInterval - elapsed;
  }

  void startPeriodicMonitor(List<IngredientModel> Function() getItems) {
    _twoHourTimer?.cancel();
    _lastAlarmTriggerTime ??= DateTime.now();
    // Check periodically if 2 hours have elapsed and low-stock items exist
    _twoHourTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final items = getItems();
      final lowStockItems = items.where((e) => e.quantity <= (e.lowStockThreshold ?? lowStockThreshold)).toList();
      if (lowStockItems.isNotEmpty) {
        final now = DateTime.now();
        if (_lastAlarmTriggerTime == null || now.difference(_lastAlarmTriggerTime!) >= alarmInterval) {
          triggerAlarm(lowStockItems);
        }
      }
    });
  }

  void stopMonitor() {
    _twoHourTimer?.cancel();
    _twoHourTimer = null;
  }

  /// Triggers the audio alarm and broadcasts to UI
  void triggerAlarm(List<IngredientModel> lowStockItems) {
    _lastAlarmTriggerTime = DateTime.now();
    playAlarmTone();
    _alarmStreamController.add(lowStockItems);
  }

  /// Plays synthesized audio alarm tone
  void playAlarmTone() {
    playAlarmSound();
  }
}
