// Web sound + vibration using the Web Audio and Vibration APIs.
import 'dart:js_interop';

@JS('navigator.vibrate')
external JSBoolean _vibrate(JSAny pattern);

@JS('AudioContext')
extension type _AudioContext._(JSObject _) implements JSObject {
  external factory _AudioContext();
  external _OscNode createOscillator();
  external _GainNode createGain();
  external JSObject get destination;
  external double get currentTime;
  external JSPromise<JSAny?> resume();
}

extension type _OscNode._(JSObject _) implements JSObject {
  external _AudioParam get frequency;
  external set type(String t);
  external void connect(JSObject dest);
  external void start([double when]);
  external void stop([double when]);
}

extension type _GainNode._(JSObject _) implements JSObject {
  external _AudioParam get gain;
  external void connect(JSObject dest);
}

extension type _AudioParam._(JSObject _) implements JSObject {
  external set value(double v);
  external void setValueAtTime(double v, double t);
  external void exponentialRampToValueAtTime(double v, double t);
}

_AudioContext? _ctx;

/// Create/resume the AudioContext from a user gesture so playback is allowed.
void prime() {
  try {
    _ctx ??= _AudioContext();
    _ctx!.resume();
  } catch (_) {}
}

void _beep(double freq, double startOffset, double dur) {
  final ctx = _ctx!;
  final osc = ctx.createOscillator();
  final gain = ctx.createGain();
  osc.type = 'sine';
  osc.frequency.value = freq;
  osc.connect(gain);
  gain.connect(ctx.destination);
  final t0 = ctx.currentTime + startOffset;
  gain.gain.setValueAtTime(0.0001, t0);
  gain.gain.exponentialRampToValueAtTime(0.25, t0 + 0.02);
  gain.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
  osc.start(t0);
  osc.stop(t0 + dur + 0.03);
}

void alert() {
  try {
    prime();
    _beep(880, 0, 0.25); // A5
    _beep(1174.66, 0.28, 0.35); // D6
  } catch (_) {}
  try {
    _vibrate(<int>[220, 120, 320].jsify()!);
  } catch (_) {}
}
