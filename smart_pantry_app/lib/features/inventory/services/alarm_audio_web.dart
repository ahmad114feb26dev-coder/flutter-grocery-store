import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';

void playPantryAlarmAudio() {
  try {
    if (globalContext.has('playPantryAlarm')) {
      globalContext.callMethod('playPantryAlarm'.toJS);
    }
  } catch (e) {
    debugPrint('LowStockAlarmService: AudioContext play error: $e');
  }
}
