import 'dart:convert';
import 'package:http/http.dart' as http;
import 'iptv_source.dart';

class _Parsed {
  final List<Category> categories;
  final List<Channel> channels;
  _Parsed(this.categories, this.channels);
}

class M3uSource implements IptvSource {
  final String url;
  M3uSource(this.url);

  Future<_Parsed>? _cache;

  Future<_Parsed> _load() => _cache ??= _download();

  Future<_Parsed> _download() async {
    final res =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final text = utf8.decode(res.bodyBytes, allowMalformed: true);
    return _parse(text);
  }

  static final _attr = RegExp(r'([\w-]+)="([^"]*)"');

  _Parsed _parse(String text) {
    final channels = <Channel>[];
    final groups = <String>{};
    String? name;
    String? epgId;
    var group = 'Sin grupo';

    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        final attrs = {
          for (final m in _attr.allMatches(line))
            m.group(1)!.toLowerCase(): m.group(2)!,
        };
        final lastQuote = line.lastIndexOf('"');
        final comma = line.indexOf(',', lastQuote < 0 ? 0 : lastQuote);
        var n = comma >= 0 ? line.substring(comma + 1).trim() : '';
        if (n.isEmpty) n = attrs['tvg-name'] ?? 'Sin nombre';
        name = n;
        epgId = attrs['tvg-id'];
        group = (attrs['group-title'] ?? '').trim();
        if (group.isEmpty) group = 'Sin grupo';
      } else if (!line.startsWith('#')) {
        if (name != null) {
          groups.add(group);
          channels.add(Channel(line, name, group, line, epgId: epgId));
          name = null;
        }
      }
    }
    return _Parsed([for (final g in groups) Category(g, g)], channels);
  }

  @override
  Future<bool> login() async {
    try {
      return (await _load()).channels.isNotEmpty;
    } catch (_) {
      _cache = null;
      rethrow;
    }
  }

  @override
  Future<List<Category>> liveCategories() async => (await _load()).categories;

  @override
  Future<List<Channel>> liveStreams() async => (await _load()).channels;
}