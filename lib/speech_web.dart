// Web side of voice dictation: talk to the shell's `SpeechBridge` channel and
// receive results via callbacks the shell invokes with runJavaScript.
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

void Function(String)? _onResult;
void Function()? _onDone;
bool _installed = false;

bool available() => globalContext.has('SpeechBridge');

void _install() {
  if (_installed) return;
  globalContext['__speechResult'] = ((JSString t) {
    _onResult?.call(t.toDart);
  }).toJS;
  globalContext['__speechDone'] = (() {
    _onDone?.call();
  }).toJS;
  _installed = true;
}

void listen(void Function(String) onResult, void Function()? onDone) {
  if (!available()) return;
  _onResult = onResult;
  _onDone = onDone;
  _install();
  (globalContext['SpeechBridge'] as JSObject).callMethod<JSAny?>(
    'postMessage'.toJS,
    jsonEncode({'action': 'start', 'locale': 'he-IL'}).toJS,
  );
}

void stop() {
  if (!available()) return;
  (globalContext['SpeechBridge'] as JSObject).callMethod<JSAny?>(
    'postMessage'.toJS,
    jsonEncode({'action': 'stop'}).toJS,
  );
}
