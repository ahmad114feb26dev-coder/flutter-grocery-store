import 'package:flutter/services.dart';

class AudioAlarmService {
  static Future<void> playAlarmChime() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }
}
