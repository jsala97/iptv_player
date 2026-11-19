import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

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
  static Future<String> themeMode() async =>
      (await _p).getString('theme_mode') ?? 'dark';
  static Future<void> setThemeMode(String v) async =>
      (await _p).setString('theme_mode', v);
  static Future<int> accent() async =>
      (await _p).getInt('accent') ?? 0xFF5B8DEF;
  static Future<void> setAccent(int v) async =>
      (await _p).setInt('accent', v);


  static Future<bool> cleanNames() async =>
      (await _p).getBool('clean_names') ?? true;
  static Future<void> setCleanNames(bool v) async =>
      (await _p).setBool('clean_names', v);
}

final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
final accentNotifier = ValueNotifier<Color>(const Color(0xFF5B8DEF));

Future<void> loadAppearance() async {
  final mode = await AppSettings.themeMode();
  themeModeNotifier.value = switch (mode) {
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    _ => ThemeMode.dark,
  };
  accentNotifier.value = Color(await AppSettings.accent());
  cleanNamesNotifier.value = await AppSettings.cleanNames();
}

final cleanNamesNotifier = ValueNotifier<bool>(true);

final _prefixRe = RegExp(r'^\s*[A-Za-z]{2}\s*[|:\-]\s*');
final _decoRe = RegExp('[\u02B0-\u02FF\u1D2C-\u1D6A\u2070-\u209F]+');
final _tagRe = RegExp(
  r'\b(?:hd|fhd|uhd|sd|4k|8k|raw|hevc|h265|1080p|720p|50fps|60fps)\b',
  caseSensitive: false,
);

String cleanName(String raw) {
  var s = raw.replaceAll(RegExp(r'^[#\s]+|[#\s]+$'), '');
  s = s.replaceFirst(_prefixRe, '');
  s = s.replaceAll(_decoRe, '').replaceAll(_tagRe, '');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  s = s.replaceAll(RegExp(r'^[|:\-\s]+|[|:\-\s]+$'), '');
  return s.isEmpty ? raw : s;
}

String displayName(String n) => cleanNamesNotifier.value ? cleanName(n) : n;