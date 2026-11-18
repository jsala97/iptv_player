import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';
import 'iptv_source.dart';

const _noise = {
  'raw', 'hd', 'fhd', 'uhd', 'sd', '4k', 'hevc', 'h265', 'h264',
  '1080p', '720p', '50fps', '60fps', 'vip', 'backup',
};

/// "GO: ANTENA 3 RAW" -> "antena3"
String normalizeName(String s) {
  var t = s.toLowerCase();
  t = t.replaceFirst(RegExp(r'^\s*[a-z]{2,4}\s*:\s*'), '');
  t = t.replaceAll(RegExp(r'\[.*?\]|\(.*?\)'), ' ');
  const from = 'áàäâéèëêíìïîóòöôúùüûñç';
  const to = 'aaaaeeeeiiiioooouuuunc';
  final b = StringBuffer();
  for (final r in t.runes) {
    final ch = String.fromCharCode(r);
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b
      .toString()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.isNotEmpty && !_noise.contains(w))
      .join();
}

class Programme {
  final String title;
  final String desc;
  final DateTime start; // UTC
  final DateTime end; // UTC
  Programme(this.title, this.desc, this.start, this.end);

  factory Programme.fromJson(Map j) => Programme(
        j['t'] as String,
        j['d'] as String,
        DateTime.fromMillisecondsSinceEpoch(j['s'] as int, isUtc: true),
        DateTime.fromMillisecondsSinceEpoch(j['e'] as int, isUtc: true),
      );
}

class Epg {
  final Map<String, List<Programme>> byChannel;
  final Map<String, String> nameToId;
  final Map<String, String?> _memo = {};

  Epg(this.byChannel, this.nameToId);

  String? _idFor(Channel ch) {
    return _memo.putIfAbsent(ch.id, () {
      final id = ch.epgId;
      if (id != null && id.isNotEmpty && byChannel.containsKey(id)) return id;
      return nameToId[normalizeName(ch.name)];
    });
  }

  List<Programme> programmesFor(Channel ch) {
    final id = _idFor(ch);
    if (id == null) return const [];
    return byChannel[id] ?? const [];
  }

  bool hasData(Channel ch) => programmesFor(ch).isNotEmpty;

  Programme? nowOn(Channel ch) {
    final t = DateTime.now().toUtc();
    for (final p in programmesFor(ch)) {
      if (!p.start.isAfter(t) && p.end.isAfter(t)) return p;
    }
    return null;
  }

  Programme? nextOn(Channel ch) {
    final t = DateTime.now().toUtc();
    Programme? best;
    for (final p in programmesFor(ch)) {
      if (p.start.isAfter(t) && (best == null || p.start.isBefore(best.start))) {
        best = p;
      }
    }
    return best;
  }
}

/// Convierte "20261118200000 +0100" a UTC.
DateTime? _parseTime(String? s) {
  if (s == null) return null;
  final m = RegExp(r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})\s*([+-]\d{4})?')
      .firstMatch(s.trim());
  if (m == null) return null;
  var dt = DateTime.utc(
    int.parse(m[1]!),
    int.parse(m[2]!),
    int.parse(m[3]!),
    int.parse(m[4]!),
    int.parse(m[5]!),
    int.parse(m[6]!),
  );
  final tz = m[7];
  if (tz != null) {
    final sign = tz.startsWith('-') ? -1 : 1;
    final h = int.parse(tz.substring(1, 3));
    final mi = int.parse(tz.substring(3, 5));
    dt = dt.subtract(Duration(hours: sign * h, minutes: sign * mi));
  }
  return dt;
}

/// Se ejecuta en otro hilo: descarga la guía y la lee por partes.
Future<Map<String, dynamic>> _downloadAndParse(
  String url,
  Set<String> wantedIds,
  Set<String> wantedNames,
  int fromMs,
  int toMs,
) async {
  final client = http.Client();
  final programmes = <String, List<Map<String, dynamic>>>{};
  final nameToId = <String, String>{};
  final ids = {...wantedIds};
  try {
    final res = await client
        .send(http.Request('GET', Uri.parse(url)))
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

    final nodes = res.stream
        .transform(const Utf8Decoder(allowMalformed: true))
        .toXmlEvents()
        .normalizeEvents()
        .selectSubtreeEvents(
          (e) => e.localName == 'programme' || e.localName == 'channel',
        )
        .toXmlNodes()
        .flatten();

    await for (final node in nodes) {
      if (node is! XmlElement) continue;

      if (node.name.local == 'channel') {
        final id = node.getAttribute('id');
        if (id == null) continue;
        for (final dn in node.findElements('display-name')) {
          final n = normalizeName(dn.innerText);
          if (n.isNotEmpty && wantedNames.contains(n)) {
            ids.add(id);
            nameToId.putIfAbsent(n, () => id);
          }
        }
        continue;
      }

      final ch = node.getAttribute('channel');
      if (ch == null || !ids.contains(ch)) continue;
      final start = _parseTime(node.getAttribute('start'));
      final stop = _parseTime(node.getAttribute('stop'));
      if (start == null || stop == null) continue;
      if (stop.millisecondsSinceEpoch < fromMs ||
          start.millisecondsSinceEpoch > toMs) {
        continue;
      }
      final title = node.getElement('title')?.innerText.trim() ?? '';
      var desc = node.getElement('desc')?.innerText.trim() ?? '';
      if (desc.length > 300) desc = desc.substring(0, 300);
      programmes.putIfAbsent(ch, () => []).add({
        't': title,
        'd': desc,
        's': start.millisecondsSinceEpoch,
        'e': stop.millisecondsSinceEpoch,
      });
    }
    return {'programmes': programmes, 'names': nameToId};
  } finally {
    client.close();
  }
}

class EpgService {
  static const ttl = Duration(hours: 6);

  static Future<File> _file(String accountId) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}epg2_$accountId.json');
  }

  static Epg _decode(Map data, Map names) {
    final out = <String, List<Programme>>{};
    data.forEach((k, v) {
      final list = [for (final p in (v as List)) Programme.fromJson(p as Map)];
      list.sort((a, b) => a.start.compareTo(b.start));
      out[k as String] = list;
    });
    return Epg(out, {
      for (final e in names.entries) e.key as String: e.value as String,
    });
  }

  /// Devuelve la guía guardada si tiene menos de 6 horas.
  static Future<Epg?> loadCached(String accountId) async {
    try {
      final f = await _file(accountId);
      if (!await f.exists()) return null;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final fetched = DateTime.fromMillisecondsSinceEpoch(j['fetched'] as int);
      if (DateTime.now().difference(fetched) > ttl) return null;
      return _decode(j['data'] as Map, (j['names'] as Map?) ?? {});
    } catch (_) {
      return null;
    }
  }

  static Future<Epg> download(
    String accountId,
    String url,
    Set<String> epgIds,
    Set<String> names,
  ) async {
    final now = DateTime.now().toUtc();
    final fromMs =
        now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
    final toMs = now.add(const Duration(hours: 24)).millisecondsSinceEpoch;

    final result = await Isolate.run(
      () => _downloadAndParse(url, epgIds, names, fromMs, toMs),
    );

    try {
      final f = await _file(accountId);
      await f.writeAsString(jsonEncode({
        'fetched': DateTime.now().millisecondsSinceEpoch,
        'data': result['programmes'],
        'names': result['names'],
      }));
    } catch (_) {}

    return _decode(result['programmes'] as Map, result['names'] as Map);
  }
}