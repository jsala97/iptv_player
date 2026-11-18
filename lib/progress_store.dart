import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'iptv_source.dart';

/// "http://host/movie/USER/PASS/123.mkv" -> "movie/123.mkv" (sin credenciales)
String pathOf(String? url) {
  final s = Uri.tryParse(url ?? '')?.pathSegments ?? const <String>[];
  return s.length == 4 ? '${s.first}/${s.last}' : '';
}


class ProgressEntry {
  final String id, name, path;
  final int posMs, durMs, ts;
  ProgressEntry(this.id, this.name, this.path, this.posMs, this.durMs, this.ts);
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
      var legacy = false;
      final out = m.map((k, v) {
        final e = v as Map<String, dynamic>;
        if (e.containsKey('u')) legacy = true;
        return MapEntry(
          k,
          ProgressEntry(
            k,
            e['n'] as String,
            (e['x'] as String?) ?? pathOf(e['u'] as String?),
            e['p'] as int,
            e['d'] as int,
            e['t'] as int,
          ),
        );
      });
      if (legacy) await _write(acc, out);
      return out;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _write(String acc, Map<String, ProgressEntry> m) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(acc),
      jsonEncode(m.map((k, e) => MapEntry(
          k, {'n': e.name, 'x': e.path, 'p': e.posMs, 'd': e.durMs, 't': e.ts}))),
    );
  }

  static Future<void> save(
      String acc, Channel ch, Duration pos, Duration dur) async {
    if (pos < const Duration(seconds: 30)) return;
    final m = await _load(acc);
    if (pos.inMilliseconds >= dur.inMilliseconds * 0.95) {
      m.remove(ch.id);
    } else {
      m[ch.id] = ProgressEntry(ch.id, ch.name, pathOf(ch.url), pos.inMilliseconds,
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
    (await _load(acc)).values.where((e) => e.path.isNotEmpty).toList()
      ..sort((a, b) => b.ts.compareTo(a.ts));

  static Future<void> remove(String acc, String id) async {
    final m = await _load(acc);
    m.remove(id);
    await _write(acc, m);
  }
}