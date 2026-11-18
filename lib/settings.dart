import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const langNames = {
  'es': 'Español', 'en': 'Inglés', 'fr': 'Francés', 'de': 'Alemán',
  'it': 'Italiano', 'pt': 'Portugués', 'ca': 'Catalán', 'ja': 'Japonés',
};

const _words = {
  'es': ['es', 'spa', 'esp', 'spanish', 'español', 'espanol', 'castellano', 'latino'],
  'en': ['en', 'eng', 'english', 'inglés', 'ingles'],
  'fr': ['fr', 'fre', 'fra', 'french', 'francés', 'frances'],
  'de': ['de', 'ger', 'deu', 'german', 'alemán', 'aleman'],
  'it': ['it', 'ita', 'italian', 'italiano'],
  'pt': ['pt', 'por', 'portuguese', 'portugués', 'portugues'],
  'ca': ['ca', 'cat', 'catalan', 'catalán'],
  'ja': ['ja', 'jpn', 'japanese', 'japonés', 'japones'],
};

bool matchesLang(String code, String? language, String? title) {
  final words = _words[code] ?? [code];
  final l = (language ?? '').toLowerCase().split(RegExp(r'[-_]')).first;
  if (l.isNotEmpty && words.contains(l)) return true;
  final t = (title ?? '').toLowerCase();
  return words.where((w) => w.length > 3).any(t.contains);
}

class AppSettings {
  static Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  static Future<String> audioLang() async =>
      (await _p).getString('pref_audio') ?? 'auto';
  static Future<String> subLang() async =>
      (await _p).getString('pref_sub') ?? 'off';
  static Future<void> setAudioLang(String v) async =>
      (await _p).setString('pref_audio', v);
  static Future<void> setSubLang(String v) async =>
      (await _p).setString('pref_sub', v);

  static Future<Map<String, dynamic>> _titleMap() async {
    final raw = (await _p).getString('titlepref');
    if (raw == null) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, String>> titlePref(String key) async {
    final e = (await _titleMap())[key];
    return e is Map ? e.map((k, v) => MapEntry('$k', '$v')) : {};
  }

  static Future<void> setTitlePref(String key,
      {String? audio, String? sub}) async {
    final m = await _titleMap();
    final cur = Map<String, dynamic>.from((m[key] as Map?) ?? {});
    if (audio != null) cur['a'] = audio;
    if (sub != null) cur['s'] = sub;
    m.remove(key);
    m[key] = cur;
    while (m.length > 200) {
      m.remove(m.keys.first);
    }
    await (await _p).setString('titlepref', jsonEncode(m));
  }
}