import 'package:shared_preferences/shared_preferences.dart';

class FavoritesStore {
  static String _key(String accountId) => 'fav_$accountId';

  static Future<Set<String>> load(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key(accountId)) ?? []).toSet();
  }

  static Future<void> save(String accountId, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key(accountId), ids.toList());
  }

  static Future<Set<String>> toggle(String accountId, String id) async {
    final s = await load(accountId);
    if (!s.add(id)) s.remove(id);
    await save(accountId, s);
    return s;
  }
}