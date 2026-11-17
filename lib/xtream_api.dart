import 'dart:convert';
import 'package:http/http.dart' as http;

class Category {
  final String id;
  final String name;
  Category(this.id, this.name);
}

class Channel {
  final String id;
  final String name;
  final String categoryId;
  Channel(this.id, this.name, this.categoryId);
}

class XtreamApi {
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

  Future<bool> login() async {
    final data = await _get({});
    final info = data['user_info'];
    return info != null && '${info['auth']}' == '1';
  }

  Future<List<Category>> liveCategories() async {
    final data = await _get({'action': 'get_live_categories'}) as List;
    return data
        .map((e) => Category('${e['category_id']}', '${e['category_name']}'))
        .toList();
  }

  Future<List<Channel>> liveStreams() async {
    final data = await _get({'action': 'get_live_streams'}) as List;
    return data
        .map((e) => Channel(
              '${e['stream_id']}',
              '${e['name']}',
              '${e['category_id']}',
            ))
        .toList();
  }

  String streamUrl(String id) => '$base/live/$user/$pass/$id.m3u8';
}