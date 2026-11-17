import 'dart:convert';
import 'package:http/http.dart' as http;
import 'iptv_source.dart';

class XtreamApi implements IptvSource {
  // Si tuviste que cambiar a .ts para que funcionara, pon 'ts' aquí.
  static const streamExt = 'm3u8';

  final String base;
  final String user;
  final String pass;
  XtreamApi(this.base, this.user, this.pass);

  Future<dynamic> _get(Map<String, String> extra) async {
    final uri = Uri.parse('$base/player_api.php').replace(
      queryParameters: {'username': user, 'password': pass, ...extra},
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 30));
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  @override
  Future<bool> login() async {
    final data = await _get({});
    final info = data['user_info'];
    return info != null && '${info['auth']}' == '1';
  }

  @override
  Future<List<Category>> liveCategories() async {
    final data = await _get({'action': 'get_live_categories'}) as List;
    return data
        .map((e) => Category('${e['category_id']}', '${e['category_name']}'))
        .toList();
  }

  @override
  Future<List<Channel>> liveStreams() async {
    final data = await _get({'action': 'get_live_streams'}) as List;
    return data.map((e) {
      final id = '${e['stream_id']}';
      return Channel(
        id,
        '${e['name']}',
        '${e['category_id']}',
        '$base/live/$user/$pass/$id.$streamExt',
      );
    }).toList();
  }
}