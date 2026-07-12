import 'speech_stub.dart' if (dart.library.js_interop) 'speech_web.dart' as impl;

/// Voice dictation via the native shell's `SpeechBridge` channel.
///
/// Available only inside the installed app (the shell injects the channel).
/// In a plain browser [available] is false and callers show a hint instead.
class Speech {
  static bool get available => impl.available();

  static void listen({
    required void Function(String text) onResult,
    void Function()? onDone,
  }) =>
      impl.listen(onResult, onDone);

  static void stop() => impl.stop();
}
