// Web implementation: talk to the shell's `Notifier` JavaScript channel.
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

bool bridgeAvailable() => globalContext.has('Notifier');

void _post(Map<String, dynamic> message) {
  final notifier = globalContext['Notifier'];
  if (notifier == null || notifier.isUndefinedOrNull) return;
  (notifier as JSObject)
      .callMethod<JSAny?>('postMessage'.toJS, jsonEncode(message).toJS);
}

void requestPermission() => _post({'action': 'requestPermission'});

void cancelAll() => _post({'action': 'cancelAll'});

void cancel(int id) => _post({'action': 'cancel', 'id': id});

void schedule(int id, String title, String body, int epochMs) => _post({
      'action': 'schedule',
      'id': id,
      'title': title,
      'body': body,
      'epochMs': epochMs,
    });
