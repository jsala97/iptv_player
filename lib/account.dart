import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'iptv_source.dart';
import 'xtream_api.dart';

enum AccountType { xtream }

class Account {
  final String id;
  final String name;
  final AccountType type;
  final String server;
  final String user;
  final String pass;

  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.server,
    required this.user,
    required this.pass,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'server': server,
        'user': user,
        'pass': pass,
      };

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: j['id'],
        name: j['name'],
        type: AccountType.values.byName(j['type']),
        server: j['server'],
        user: j['user'],
        pass: j['pass'],
      );

  IptvSource createSource() {
    return switch (type) {
      AccountType.xtream => XtreamApi(server, user, pass),
    };
  }
}

class AccountStore {
  static const _key = 'accounts';

  static Future<List<Account>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => Account.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> save(List<Account> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );
  }
}