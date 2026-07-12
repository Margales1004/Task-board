// Native side of voice dictation, used only by the APK shell (main_shell.dart).
// The web app posts {action:'start'|'stop'} to the `SpeechBridge` channel; here
// we run the device recognizer (Hebrew) and push results back into the page.
import 'dart:convert';

import 'package:speech_to_text/speech_to_text.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ShellSpeech {
  static final SpeechToText _stt = SpeechToText();
  static bool _initialized = false;

  static Future<void> handle(String raw, WebViewController controller) async {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (msg['action']) {
      case 'start':
        await _start(controller);
        break;
      case 'stop':
        await _stt.stop();
        _done(controller);
        break;
    }
  }

  static Future<void> _start(WebViewController controller) async {
    if (!_initialized) {
      _initialized = await _stt.initialize(
        onError: (_) => _done(controller),
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') _done(controller);
        },
      );
    }
    if (!_initialized) {
      _done(controller);
      return;
    }
    await _stt.listen(
      onResult: (r) {
        controller.runJavaScript(
          'window.__speechResult && window.__speechResult(${jsonEncode(r.recognizedWords)})',
        );
      },
      listenOptions: SpeechListenOptions(
        localeId: 'he_IL',
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  static void _done(WebViewController controller) {
    controller.runJavaScript('window.__speechDone && window.__speechDone()');
  }
}
