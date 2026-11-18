import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

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
  Epg(this.byChannel);

  Programme? nowOn(String? epgId) {
    if (epgId == null) return null;
    final t = DateTime.now().toUtc();
    for (final p in byChannel[epgId] ?? const <Programme>[]) {
      if (!p.start.isAfter(t) && p.end.isAfter(t)) return p;
    }
    return null;
  }

  Programme? nextOn(String? epgId) {
    if (epgId == null) return null;
    final t = DateTime.now().toUtc();
    Programme? best;
    for (final p in byChannel[epgId] ?? const <Programme>[]) {
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
Future<Map<String, List<Map<String, dynamic>>>> _downloadAndParse(
  String url,
  Set<String> wanted,
  int fromMs,
  int toMs,
) async {
  final client = http.Client();
  final result = <String, List<Map<String, dynamic>>>{};
  try {
    final res = await client
        .send(http.Request('GET', Uri.parse(url)))
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

    final nodes = res.stream
        .transform(const Utf8Decoder(allowMalformed: true))
        .toXmlEvents()
        .normalizeEvents()
        .selectSubtreeEvents((e) => e.localName == 'programme')
        .toXmlNodes()
        .flatten();

    await for (final node in nodes) {
      if (node is! XmlElement) continue;
      final ch = node.getAttribute('channel');
      if (ch == null || !wanted.contains(ch)) continue;
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
      result.putIfAbsent(ch, () => []).add({
        't': title,
        'd': desc,
        's': start.millisecondsSinceEpoch,
        'e': stop.millisecondsSinceEpoch,
      });
    }
    return result;
  } finally {
    client.close();
  }
}

class EpgService {
  static const ttl = Duration(hours: 6);

  static Future<File> _file(String accountId) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}epg_$accountId.json');
  }

  static Epg _decode(Map data) {
    final out = <String, List<Programme>>{};
    data.forEach((k, v) {
      final list = [for (final p in (v as List)) Programme.fromJson(p as Map)];
      list.sort((a, b) => a.start.compareTo(b.start));
      out[k as String] = list;
    });
    return Epg(out);
  }

  /// Devuelve la guía guardada si tiene menos de 6 horas.
  static Future<Epg?> loadCached(String accountId) async {
    try {
      final f = await _file(accountId);
      if (!await f.exists()) return null;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final fetched = DateTime.fromMillisecondsSinceEpoch(j['fetched'] as int);
      if (DateTime.now().difference(fetched) > ttl) return null;
      return _decode(j['data'] as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<Epg> download(
    String accountId,
    String url,
    Set<String> epgIds,
  ) async {
    final now = DateTime.now().toUtc();
    final fromMs =
        now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
    final toMs = now.add(const Duration(hours: 24)).millisecondsSinceEpoch;

    final data = await Isolate.run(
      () => _downloadAndParse(url, epgIds, fromMs, toMs),
    );

    try {
      final f = await _file(accountId);
      await f.writeAsString(jsonEncode({
        'fetched': DateTime.now().millisecondsSinceEpoch,
        'data': data,
      }));
    } catch (_) {}

    return _decode(data);
  }
}