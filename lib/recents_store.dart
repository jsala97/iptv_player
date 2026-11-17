import 'package:shared_preferences/shared_preferences.dart';

class RecentsStore {
  static const maxItems = 30;

  static String _key(String accountId) => 'recent_$accountId';

  static Future<List<String>> load(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key(accountId)) ?? [];
  }

  static Future<void> save(String accountId, List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key(accountId), ids);
  }
}