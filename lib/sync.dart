// Tiny REST client for the "browser capture" inbox, backed by a Firebase
// Realtime Database. The Chrome extension POSTs captured tasks to
// `<dbUrl>/inbox/<code>.json`; the app polls that path, imports new entries,
// then deletes them. No Firebase SDK — plain HTTPS via package:http, which
// works on web (fetch/XHR). Access is gated by the secret <code>.
import 'dart:convert';

import 'package:http/http.dart' as http;

class InboxEntry {
  final String key; // Firebase push id
  final String name;
  final String? note;

  InboxEntry({required this.key, required this.name, this.note});
}

class InboxSync {
  /// Normalize a DB URL to `https://host` with no trailing slash.
  static String _base(String dbUrl) {
    var u = dbUrl.trim();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    return u;
  }

  static Uri _pathUri(String dbUrl, String code, [String? key]) {
    final tail = key == null ? 'inbox/$code.json' : 'inbox/$code/$key.json';
    return Uri.parse('${_base(dbUrl)}/$tail');
  }

  /// Fetch all pending entries. Returns [] on any error or empty inbox.
  static Future<List<InboxEntry>> fetch(String dbUrl, String code) async {
    try {
      final res = await http
          .get(_pathUri(dbUrl, code))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200 || res.body.isEmpty || res.body == 'null') {
        return [];
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return [];
      final out = <InboxEntry>[];
      decoded.forEach((k, v) {
        if (v is Map) {
          final name = (v['name'] as String?)?.trim() ?? '';
          if (name.isNotEmpty) {
            out.add(InboxEntry(
              key: k as String,
              name: name,
              note: (v['note'] as String?)?.trim(),
            ));
          }
        }
      });
      return out;
    } catch (_) {
      return [];
    }
  }

  /// Delete an entry after it's been imported. Best-effort.
  static Future<void> remove(String dbUrl, String code, String key) async {
    try {
      await http
          .delete(_pathUri(dbUrl, code, key))
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // ignore; a stale entry will just be de-duped in memory this session
    }
  }
}
