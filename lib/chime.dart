import 'chime_stub.dart' if (dart.library.js_interop) 'chime_web.dart' as impl;

/// Plays a completion chime and vibrates the device (web/WebView).
///
/// Works while the app is in the foreground; a screen-off/closed alert needs the
/// native notification path. [prime] must be called from a user gesture (e.g.
/// tapping Start) so the browser allows audio.
class Chime {
  static void prime() => impl.prime();
  static void alert() => impl.alert();
}
