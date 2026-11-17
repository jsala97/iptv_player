import 'dart:async';
import 'package:http/http.dart' as http;
import 'xtream_api.dart';

class ServerResult {
  final String server;
  final bool ok;
  final int? latencyMs;
  final double? mbps;
  final String? error;

  ServerResult({
    required this.server,
    required this.ok,
    this.latencyMs,
    this.mbps,
    this.error,
  });
}

Future<double?> _measureMbps(String url) async {
  final client = http.Client();
  try {
    final res = await client
        .send(http.Request('GET', Uri.parse(url)))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;

    var bytes = 0;
    final done = Completer<void>();
    final sw = Stopwatch()..start();
    final sub = res.stream.listen(
      (chunk) => bytes += chunk.length,
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      onError: (_) {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    await Future.any([done.future, Future.delayed(const Duration(seconds: 5))]);
    final elapsedMs = sw.elapsedMilliseconds;
    await sub.cancel();

    // Si llegó muy poco, no es un stream continuo y no se puede medir.
    if (bytes < 100000 || elapsedMs == 0) return null;
    return bytes * 8 / 1000000 / (elapsedMs / 1000);
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

Future<ServerResult> testServer(String server, String user, String pass) async {
  final api = XtreamApi(server, user, pass);
  final sw = Stopwatch()..start();
  try {
    final ok = await api.login().timeout(const Duration(seconds: 10));
    final latency = sw.elapsedMilliseconds;
    if (!ok) {
      return ServerResult(
        server: server,
        ok: false,
        error: 'Credenciales rechazadas',
      );
    }

    double? mbps;
    try {
      final id = await api.sampleStreamId();
      if (id != null) {
        mbps = await _measureMbps('$server/live/$user/$pass/$id.ts');
      }
    } catch (_) {}

    return ServerResult(
      server: server,
      ok: true,
      latencyMs: latency,
      mbps: mbps,
    );
  } catch (_) {
    return ServerResult(
      server: server,
      ok: false,
      error: 'Sin respuesta o error de red',
    );
  }
}