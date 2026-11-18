import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'iptv_source.dart';
import 'm3u_source.dart';
import 'xtream_api.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AccountType { xtream, m3u }

class Account {
  final String id;
  final String name;
  final AccountType type;
  final List<String> servers;
  final String user;
  final String pass;
  final String? lastServer;
  final String? epgUrl;

  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.servers,
    required this.user,
    required this.pass,
    this.lastServer,
    this.epgUrl,
  });

  String get currentServer =>
      (lastServer != null && servers.contains(lastServer))
          ? lastServer!
          : servers.first;

  String label(String server) => type == AccountType.m3u
      ? (Uri.tryParse(server)?.host ?? 'Lista M3U')
      : server;

  /// La guía propia de la cuenta; si no hay, en Xtream se prueba la del servidor.
  String? effectiveEpgUrl(String server) {
    final custom = epgUrl;
    if (custom != null && custom.isNotEmpty) return custom;
    if (type == AccountType.xtream) {
      return '$server/xmltv.php?username=${Uri.encodeQueryComponent(user)}&password=${Uri.encodeQueryComponent(pass)}';
    }
    return null;
  }

  Account copyWith({String? lastServer}) => Account(
        id: id,
        name: name,
        type: type,
        servers: servers,
        user: user,
        pass: pass,
        lastServer: lastServer ?? this.lastServer,
        epgUrl: epgUrl,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'servers': servers,
        'user': user,
        'pass': pass,
        'lastServer': lastServer,
        'epgUrl': epgUrl,
      };

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: j['id'],
        name: j['name'],
        type: AccountType.values.byName(j['type']),
        servers: j['servers'] != null
            ? List<String>.from(j['servers'])
            : [j['server'] as String],
        user: j['user'],
        pass: j['pass'],
        lastServer: j['lastServer'] as String?,
        epgUrl: j['epgUrl'] as String?,
      );

  IptvSource createSource(String server) {
    return switch (type) {
      AccountType.xtream => XtreamApi(server, user, pass),
      AccountType.m3u => M3uSource(server),
    };
  }
}

class AccountStore {
  static const _idsKey = 'account_ids';
  static const _legacyKey = 'accounts';
  static const _secure = FlutterSecureStorage();

  static Future<List<Account>> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Migración desde la versión anterior (texto plano).
    final legacy = prefs.getString(_legacyKey);
    if (legacy != null) {
      final old = (jsonDecode(legacy) as List)
          .map((e) => Account.fromJson(e as Map<String, dynamic>))
          .toList();
      try {
        await save(old);
        await prefs.remove(_legacyKey);
      } catch (_) {
        return old;
      }
    }

    final out = <Account>[];
    for (final id in prefs.getStringList(_idsKey) ?? <String>[]) {
      final raw = await _secure.read(key: 'acc_$id');
      if (raw != null) {
        out.add(Account.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      }
    }
    return out;
  }

  static Future<void> save(List<Account> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final oldIds = prefs.getStringList(_idsKey) ?? <String>[];
    final newIds = accounts.map((a) => a.id).toList();
    for (final a in accounts) {
      await _secure.write(key: 'acc_${a.id}', value: jsonEncode(a.toJson()));
    }
    for (final id in oldIds.where((id) => !newIds.contains(id))) {
      await _secure.delete(key: 'acc_$id');
    }
    await prefs.setStringList(_idsKey, newIds);
  }
}