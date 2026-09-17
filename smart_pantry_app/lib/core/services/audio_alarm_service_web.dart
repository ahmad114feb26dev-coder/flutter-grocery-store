// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;

class AudioAlarmService {
  static Future<void> playAlarmChime() async {
    try {
      js.context.callMethod('eval', [
        '''
        (function() {
          try {
            var AudioCtx = window.AudioContext || window.webkitAudioContext;
            if (!AudioCtx) return;
            var ctx = new AudioCtx();
            if (ctx.state === 'suspended') {
              ctx.resume();
            }
            function beep(freq, delay, dur) {
              var osc = ctx.createOscillator();
              var gain = ctx.createGain();
              osc.type = 'sine';
              osc.frequency.setValueAtTime(freq, ctx.currentTime + delay);
              gain.gain.setValueAtTime(0.001, ctx.currentTime + delay);
              gain.gain.exponentialRampToValueAtTime(0.3, ctx.currentTime + delay + 0.02);
              gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + delay + dur);
              osc.connect(gain);
              gain.connect(ctx.destination);
              osc.start(ctx.currentTime + delay);
              osc.stop(ctx.currentTime + delay + dur);
            }
            // 2-tone chime: 880Hz (A5) then 1320Hz (E6), repeated
            beep(880, 0.00, 0.12);
            beep(1320, 0.14, 0.22);
            beep(880, 0.40, 0.12);
            beep(1320, 0.54, 0.28);
          } catch(e) {
            console.warn('[AudioAlarmService] Audio context error:', e);
          }
        })();
        '''
      ]);
    } catch (_) {}
  }
}
