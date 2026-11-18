import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'iptv_source.dart';

class ProgressEntry {
  final String id, name, url;
  final int posMs, durMs, ts;
  ProgressEntry(this.id, this.name, this.url, this.posMs, this.durMs, this.ts);
  double get fraction => durMs == 0 ? 0 : posMs / durMs;
}

class ProgressStore {
  static String _key(String acc) => 'progress_$acc';

  static Future<Map<String, ProgressEntry>> _load(String acc) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(acc));
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) {
        final e = v as Map<String, dynamic>;
        return MapEntry(
          k,
          ProgressEntry(k, e['n'] as String, e['u'] as String, e['p'] as int,
              e['d'] as int, e['t'] as int),
        );
      });
    } catch (_) {
      return {};
    }
  }

  static Future<void> _write(String acc, Map<String, ProgressEntry> m) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(acc),
      jsonEncode(m.map((k, e) => MapEntry(
          k, {'n': e.name, 'u': e.url, 'p': e.posMs, 'd': e.durMs, 't': e.ts}))),
    );
  }

  static Future<void> save(
      String acc, Channel ch, Duration pos, Duration dur) async {
    if (pos < const Duration(seconds: 30)) return;
    final m = await _load(acc);
    if (pos.inMilliseconds >= dur.inMilliseconds * 0.95) {
      m.remove(ch.id);
    } else {
      m[ch.id] = ProgressEntry(ch.id, ch.name, ch.url, pos.inMilliseconds,
          dur.inMilliseconds, DateTime.now().millisecondsSinceEpoch);
      if (m.length > 30) {
        final oldest = (m.values.toList()..sort((a, b) => a.ts.compareTo(b.ts))).first;
        m.remove(oldest.id);
      }
    }
    await _write(acc, m);
  }

  static Future<Duration?> positionFor(String acc, String id) async {
    final e = (await _load(acc))[id];
    return e == null ? null : Duration(milliseconds: e.posMs);
  }

  static Future<List<ProgressEntry>> list(String acc) async =>
      (await _load(acc)).values.toList()..sort((a, b) => b.ts.compareTo(a.ts));

  static Future<void> remove(String acc, String id) async {
    final m = await _load(acc);
    m.remove(id);
    await _write(acc, m);
  }
}