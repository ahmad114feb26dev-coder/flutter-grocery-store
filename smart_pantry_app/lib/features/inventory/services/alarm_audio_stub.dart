import 'package:flutter/services.dart';

void playPantryAlarmAudio() {
  SystemSound.play(SystemSoundType.alert);
}
