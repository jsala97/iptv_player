import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'settings.dart';

class TmdbInfo {
  final String? overview, director, directorLabel, trailerKey, year;
  final double? rating;
  final int? runtime;
  final List<String> genres, cast;

  TmdbInfo({
    this.overview,
    this.director,
    this.directorLabel,
    this.trailerKey,
    this.year,
    this.rating,
    this.runtime,
    this.genres = const [],
    this.cast = const [],
  });

  Map<String, dynamic> toJson() => {
        'o': overview,
        'd': director,
        'dl': directorLabel,
        't': trailerKey,
        'y': year,
        'r': rating,
        'm': runtime,
        'g': genres,
        'c': cast,
      };

  factory TmdbInfo.fromJson(Map<String, dynamic> j) => TmdbInfo(
        overview: j['o'] as String?,
        director: j['d'] as String?,
        directorLabel: j['dl'] as String?,
        trailerKey: j['t'] as String?,
        year: j['y'] as String?,
        rating: (j['r'] as num?)?.toDouble(),
        runtime: j['m'] as int?,
        genres: List<String>.from(j['g'] ?? const []),
        cast: List<String>.from(j['c'] ?? const []),
      );
}

/// "4K-TOP - Spider-Man: Brand New Day (2026)" -> título y año.
({String title, String? year}) parseVodTitle(String raw) {
  String? year;
  final y = RegExp(r'[\(\[]\s*((?:19|20)\d{2})\s*[\)\]]').firstMatch(raw);
  if (y != null) year = y[1];
  var s = raw.replaceAll(RegExp(r'\[.*?\]|\(.*?\)'), ' ');
  s = s.replaceAll(
    RegExp(
      r'\b(?:4k|uhd|fhd|hd|sd|hdr10?|dv|hevc|h26[45]|x26[45]|1080p|2160p|720p|multi|dual|latino|castellano|vose|vos|web-?dl|bluray)\b',
      caseSensitive: false,
    ),
    ' ',
  );
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return (title: s, year: year);
}

class Tmdb {
  static Map<String, dynamic>? _cache;

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}tmdb_cache.json');
  }

  static Future<Map<String, dynamic>> _loadCache() async {
    final c = _cache;
    if (c != null) return c;
    try {
      final f = await _file();
      if (await f.exists()) {
        return _cache = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      }
    } catch (_) {}
    return _cache = <String, dynamic>{};
  }

  static Future<void> _saveCache() async {
    final c = _cache;
    if (c == null) return;
    while (c.length > 300) {
      c.remove(c.keys.first);
    }
    try {
      await (await _file()).writeAsString(jsonEncode(c));
    } catch (_) {}
  }

  static Future<dynamic> _get(String path, Map<String, String> q) async {
    final key = await AppSettings.tmdbKey();
    final params = {...q, 'language': 'es-ES'};
    final headers = <String, String>{};
    if (key.startsWith('eyJ')) {
      headers['Authorization'] = 'Bearer $key';
    } else {
      params['api_key'] = key;
    }
    final res = await http
        .get(Uri.https('api.themoviedb.org', '/3/$path', params), headers: headers)
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw Exception('TMDB ${res.statusCode}');
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static List<String> _candidates(String title) {
    final out = <String>[];
    final m = RegExp(r'^[A-Za-z0-9+\- ]{1,12}?\s*(?:\||\s-\s)\s*(.+)$')
        .firstMatch(title);
    if (m != null) out.add(m[1]!.trim());
    out.add(title);
    return out;
  }

  static Future<Map<String, dynamic>?> _pass(
    String kind,
    List<String> candidates,
    String? year,
  ) async {
    final dateKey = kind == 'movie' ? 'release_date' : 'first_air_date';
    final yearParam = kind == 'movie' ? 'year' : 'first_air_date_year';
    Map<String, dynamic>? best;
    for (final c in candidates) {
      final data = await _get('search/$kind', {
        'query': c,
        if (year != null) yearParam: year,
      });
      final results =
          ((data['results'] as List?) ?? []).cast<Map<String, dynamic>>();
      if (results.isEmpty) continue;
      if (year != null) {
        final hit = results
            .where((r) => '${r[dateKey]}'.startsWith(year))
            .firstOrNull;
        if (hit != null) return hit;
      }
      best ??= results.first;
    }
    return best;
  }

  static TmdbInfo _parse(String kind, Map<String, dynamic> d) {
    final cast = ((d['credits']?['cast'] as List?) ?? [])
        .take(8)
        .map((c) => '${c['name']}')
        .toList();

    String? director;
    String label = 'Director';
    if (kind == 'movie') {
      final crew = ((d['credits']?['crew'] as List?) ?? []);
      director = crew
          .where((c) => c['job'] == 'Director')
          .map((c) => '${c['name']}')
          .firstOrNull;
    } else {
      label = 'Creador';
      director = ((d['created_by'] as List?) ?? [])
          .map((c) => '${c['name']}')
          .firstOrNull;
    }

    final vids = ((d['videos']?['results'] as List?) ?? [])
        .cast<Map<String, dynamic>>()
        .where((v) => v['site'] == 'YouTube' && v['type'] == 'Trailer')
        .toList();
    String? trailer;
    for (final lang in ['es', 'en']) {
      final v = vids.where((v) => v['iso_639_1'] == lang).firstOrNull;
      if (v != null) {
        trailer = '${v['key']}';
        break;
      }
    }
    trailer ??= vids.isEmpty ? null : '${vids.first['key']}';

    final date = '${d[kind == 'movie' ? 'release_date' : 'first_air_date'] ?? ''}';
    final overview = '${d['overview'] ?? ''}'.trim();
    final rating = (d['vote_average'] as num?)?.toDouble();
    final runtime = kind == 'movie'
        ? d['runtime'] as int?
        : ((d['episode_run_time'] as List?) ?? []).firstOrNull as int?;

    return TmdbInfo(
      overview: overview.isEmpty ? null : overview,
      director: director,
      directorLabel: label,
      trailerKey: trailer,
      year: date.length >= 4 ? date.substring(0, 4) : null,
      rating: (rating == null || rating == 0) ? null : rating,
      runtime: (runtime == null || runtime == 0) ? null : runtime,
      genres: ((d['genres'] as List?) ?? []).map((g) => '${g['name']}').toList(),
      cast: cast,
    );
  }

  /// kind: 'movie' o 'tv'. Devuelve null si no hay clave, no se encuentra o falla.
  static Future<TmdbInfo?> lookup(String kind, String rawName) async {
    if ((await AppSettings.tmdbKey()).isEmpty) return null;
    final parsed = parseVodTitle(rawName);
    if (parsed.title.isEmpty) return null;

    final ck = '$kind|${parsed.title.toLowerCase()}|${parsed.year ?? ''}';
    final cache = await _loadCache();
    final hit = cache[ck];
    if (hit is Map) return TmdbInfo.fromJson(hit.cast<String, dynamic>());

    try {
      final cands = _candidates(parsed.title);
      var r = await _pass(kind, cands, parsed.year);
      if (r == null && parsed.year != null) r = await _pass(kind, cands, null);
      if (r == null) return null;

      final d = await _get('$kind/${r['id']}', {
        'append_to_response': 'credits,videos',
        'include_video_language': 'es,en,null',
      }) as Map<String, dynamic>;
      final info = _parse(kind, d);
      cache[ck] = info.toJson();
      await _saveCache();
      return info;
    } catch (_) {
      return null; // sin mostrar el error: la URL puede llevar la clave
    }
  }
}

class TmdbBlock extends StatelessWidget {
  final TmdbInfo info;
  const TmdbBlock(this.info, {super.key});

  @override
  Widget build(BuildContext context) {
    final meta = [
      info.year,
      if (info.runtime != null) '${info.runtime} min',
      if (info.rating != null) '★ ${info.rating!.toStringAsFixed(1)}',
      if (info.genres.isNotEmpty) info.genres.join(', '),
    ].whereType<String>().join('  ·  ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (meta.isNotEmpty) Text(meta),
        if (info.overview != null) ...[
          const SizedBox(height: 12),
          Text(info.overview!),
        ],
        if (info.director != null) ...[
          const SizedBox(height: 12),
          Text('${info.directorLabel ?? 'Director'}: ${info.director}'),
        ],
        if (info.cast.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Reparto: ${info.cast.join(', ')}'),
        ],
        if (info.trailerKey != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Ver tráiler'),
            onPressed: () => launchUrl(
              Uri.parse('https://www.youtube.com/watch?v=${info.trailerKey}'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        const Text('Datos de TMDB', style: TextStyle(fontSize: 11)),
      ],
    );
  }
}