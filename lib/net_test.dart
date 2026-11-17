import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class TestServer {
  final String name;
  final String pingUrl;
  final String downloadUrl;
  final String? uploadUrl;
  final bool rangePing;
  final bool distant;

  const TestServer({
    required this.name,
    required this.pingUrl,
    required this.downloadUrl,
    this.uploadUrl,
    this.rangePing = false,
    this.distant = false,
  });
}

const testServers = [
  TestServer(
    name: 'Cloudflare',
    pingUrl: 'https://speed.cloudflare.com/__down?bytes=0',
    downloadUrl: 'https://speed.cloudflare.com/__down?bytes=25000000',
    uploadUrl: 'https://speed.cloudflare.com/__up',
  ),
  TestServer(
    name: 'Hetzner (Alemania)',
    pingUrl: 'https://fsn1-speed.hetzner.com/100MB.bin',
    downloadUrl: 'https://fsn1-speed.hetzner.com/1GB.bin',
    rangePing: true,
    distant: true,
  ),
];

/// Busca el primer servidor que responde y devuelve también su latencia.
Future<(TestServer, int)> findServer() async {
  Object? lastError;
  for (final s in testServers) {
    try {
      return (s, await measurePing(s));
    } catch (e) {
      lastError = e;
    }
  }
  throw lastError ?? Exception('Ningún servidor de pruebas responde');
}

/// Latencia en ms (la mejor de varias), restando el tiempo de proceso del
/// servidor si lo indica. La primera petición se descarta.
Future<int> measurePing(TestServer s) async {
  final client = http.Client();
  try {
    final times = <double>[];
    for (var i = 0; i < 6; i++) {
      final sw = Stopwatch()..start();
      final res = await client
          .get(
            Uri.parse(s.pingUrl),
            headers: s.rangePing ? {'Range': 'bytes=0-0'} : null,
          )
          .timeout(const Duration(seconds: 5));
      sw.stop();
      if (res.statusCode != 200 && res.statusCode != 206) {
        throw Exception('HTTP ${res.statusCode}');
      }
      var ms = sw.elapsedMicroseconds / 1000;
      final st = res.headers['server-timing'];
      final m = st == null ? null : RegExp(r'dur=([\d.]+)').firstMatch(st);
      if (m != null) ms -= double.parse(m.group(1)!);
      if (i > 0) times.add(ms < 0 ? 0 : ms);
    }
    times.sort();
    return times.first.round();
  } finally {
    client.close();
  }
}

/// Descarga en Mbps con varias conexiones a la vez.
Future<double> measureDownloadMbps(
  TestServer s, {
  int connections = 4,
  Duration duration = const Duration(seconds: 8),
}) async {
  var bytes = 0;
  var running = true;
  final clients = <http.Client>[];

  Future<void> worker() async {
    final client = http.Client();
    clients.add(client);
    while (running) {
      final res = await client
          .send(http.Request('GET', Uri.parse(s.downloadUrl)))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      await for (final chunk in res.stream) {
        if (!running) break;
        bytes += chunk.length;
      }
    }
  }

  final workers = Future.wait(List.generate(connections, (_) => worker()));
  final sw = Stopwatch()..start();

  final measurement = () async {
    // Calentamiento: ignoramos el arranque de las conexiones.
    await Future.delayed(const Duration(milliseconds: 1500));
    final b0 = bytes;
    final t0 = sw.elapsedMilliseconds;
    await Future.delayed(duration);
    final b1 = bytes;
    final t1 = sw.elapsedMilliseconds;
    return (b1 - b0) * 8 / 1000000 / ((t1 - t0) / 1000);
  }();

  try {
    return await Future.any<double>([measurement, workers.then((_) => 0.0)]);
  } finally {
    running = false;
    for (final c in clients) {
      c.close();
    }
  }
}

/// Subida en Mbps: una ronda corta de prueba y otra ajustada a ~3 segundos.
Future<double> measureUploadMbps(TestServer s, {int connections = 4}) async {
  final url = s.uploadUrl;
  if (url == null) throw Exception('Este servidor no admite subida');
  final clients = List.generate(connections, (_) => http.Client());

  Future<double> round(int mbEach) async {
    final data = Uint8List(mbEach * 1024 * 1024);
    final sw = Stopwatch()..start();
    final responses = await Future.wait(
      clients.map(
        (c) => c
            .post(Uri.parse(url), body: data)
            .timeout(const Duration(seconds: 40)),
      ),
    );
    sw.stop();
    for (final r in responses) {
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    }
    return data.length *
        8 *
        connections /
        1000000 /
        (sw.elapsedMilliseconds / 1000);
  }

  try {
    final probe = await round(5);
    final mbEach = (probe * 3 / 8 / connections).clamp(5, 25).round();
    final main = await round(mbEach);
    return main > probe ? main : probe;
  } finally {
    for (final c in clients) {
      c.close();
    }
  }
}