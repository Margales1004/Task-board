import 'reminders_stub.dart'
    if (dart.library.js_interop) 'reminders_web.dart' as impl;

/// Bridge to schedule real OS notifications through the native WebView shell.
///
/// The web app posts messages to a `Notifier` JavaScript channel that the shell
/// (lib/main_shell.dart) injects and handles with flutter_local_notifications.
/// When running outside the shell (plain browser / tests) every call is a no-op
/// and [available] is false.
class Reminders {
  static bool get available => impl.bridgeAvailable();

  static void requestPermission() => impl.requestPermission();

  static void cancelAll() => impl.cancelAll();

  static void cancel(int id) => impl.cancel(id);

  static void schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) =>
      impl.schedule(id, title, body, when.millisecondsSinceEpoch);
}
