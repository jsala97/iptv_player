import 'dart:convert';
import 'dart:isolate';
import 'package:http/http.dart' as http;
import 'iptv_source.dart';

String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

class XtreamApi implements IptvSource {
  // Si tuviste que cambiar a .ts para que funcionara, pon 'ts' aquí.
  static const streamExt = 'm3u8';

  final String base;
  final String user;
  final String pass;
  XtreamApi(this.base, this.user, this.pass);

  @override
  bool get supportsVod => true;

  Future<dynamic> _get(
    Map<String, String> extra, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final uri = Uri.parse('$base/player_api.php').replace(
      queryParameters: {'username': user, 'password': pass, ...extra},
    );
    final res = await http.get(uri).timeout(timeout);
    final text = const Utf8Decoder(allowMalformed: true).convert(res.bodyBytes);
    if (text.length > 1000000) {
      return await Isolate.run(() => jsonDecode(text));
    }
    return jsonDecode(text);
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
    final data = await _get(
      {'action': 'get_live_streams'},
      timeout: const Duration(seconds: 90),
    ) as List;
    return data.map((e) {
      final id = '${e['stream_id']}';
      return Channel(
        id,
        '${e['name']}',
        '${e['category_id']}',
        '$base/live/$user/$pass/$id.$streamExt',
        epgId: e['epg_channel_id']?.toString(),
      );
    }).toList();
  }

  Future<String?> sampleStreamId() async {
    final cats = await _get({'action': 'get_live_categories'}) as List;
    if (cats.isEmpty) return null;
    final streams = await _get({
      'action': 'get_live_streams',
      'category_id': '${cats.first['category_id']}',
    }) as List;
    if (streams.isEmpty) return null;
    return '${streams.first['stream_id']}';
  }

  @override
  Future<List<Category>> vodCategories() async {
    final data = await _get({'action': 'get_vod_categories'});
    if (data is! List) return [];
    return data
        .map((e) => Category('${e['category_id']}', '${e['category_name']}'))
        .toList();
  }

  @override
  Future<List<Movie>> movies() async {
    final data = await _get(
      {'action': 'get_vod_streams'},
      timeout: const Duration(seconds: 90),
    );
    if (data is! List) return [];
    return data.map((e) {
      final id = '${e['stream_id']}';
      final ext = _str(e['container_extension']) ?? 'mp4';
      return Movie(
        id: id,
        name: '${e['name']}',
        categoryId: '${e['category_id']}',
        url: '$base/movie/$user/$pass/$id.$ext',
        icon: _str(e['stream_icon']),
        rating: _str(e['rating']),
        added: int.tryParse('${e['added']}'),
      );
    }).toList();
  }

  @override
  Future<MovieInfo?> movieInfo(Movie m) async {
    final data = await _get({'action': 'get_vod_info', 'vod_id': m.id});
    final info = data is Map ? data['info'] : null;
    if (info is! Map) return null;
    return MovieInfo(
      plot: _str(info['plot'] ?? info['description']),
      cast: _str(info['cast'] ?? info['actors']),
      director: _str(info['director']),
      genre: _str(info['genre']),
      releaseDate: _str(info['releasedate'] ?? info['release_date']),
      duration: _str(info['duration']),
    );
  }
}