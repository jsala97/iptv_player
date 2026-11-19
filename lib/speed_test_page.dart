import 'package:material_ui/material_ui.dart';
import 'net_test.dart';

class SpeedTestPage extends StatefulWidget {
  const SpeedTestPage({super.key});

  @override
  State<SpeedTestPage> createState() => _SpeedTestPageState();
}

class _SpeedTestPageState extends State<SpeedTestPage> {
  int? _ping;
  double? _down;
  double? _up;
  bool _upUnavailable = false;
  TestServer? _server;
  List<String> _notes = [];
  String _phase = '';
  String? _error;
  bool _running = false;
  DateTime? _lastRun;

  Future<void> _run() async {
    final last = _lastRun;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 60)) {
      setState(() => _error =
          'Espera un minuto entre tests para no saturar el servidor de pruebas.');
      return;
    }
    _lastRun = DateTime.now();

    setState(() {
      _running = true;
      _ping = null;
      _down = null;
      _up = null;
      _upUnavailable = false;
      _server = null;
      _notes = [];
      _error = null;
      _phase = 'Buscando servidor...';
    });

    final notes = <String>[];
    try {
      TestServer? used;
      int? ping;
      double? down;

      for (final s in testServers) {
        try {
          if (mounted) setState(() => _phase = 'Probando ${s.name}...');
          final p = await measurePing(s);
          if (mounted) {
            setState(() {
              _ping = p;
              _phase = 'Midiendo descarga (${s.name})...';
            });
          }
          final d = await measureDownloadMbps(s);
          used = s;
          ping = p;
          down = d;
          break;
        } catch (e) {
          notes.add('${s.name}: $e');
          if (mounted) setState(() => _ping = null);
        }
      }

      if (!mounted) return;
      final srv = used;
      if (srv == null) {
        setState(() {
          _notes = notes;
          _error = 'Ningún servidor de pruebas ha respondido.';
        });
        return;
      }

      setState(() {
        _server = srv;
        _ping = ping;
        _down = down;
        _phase = 'Midiendo subida...';
      });

      final upServers = testServers.where((s) => s.uploadUrl != null).toList();
      if (upServers.isEmpty) {
        _upUnavailable = true;
      } else {
        try {
          final up = await measureUploadMbps(upServers.first);
          if (!mounted) return;
          setState(() => _up = up);
        } catch (e) {
          notes.add('Subida (${upServers.first.name}): $e');
          _upUnavailable = true;
        }
      }
      if (mounted) setState(() => _notes = notes);
    } catch (e) {
      if (mounted) {
        setState(() {
          _notes = notes;
          _error = 'No se pudo completar el test: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _phase = '';
        });
      }
    }
  }

  Widget _metric(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 16)),
            Text(value, style: const TextStyle(fontSize: 26)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final down = _down;
    final server = _server;
    return Scaffold(
      appBar: AppBar(title: const Text('Test de mi conexión')),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _metric('Latencia', _ping == null ? '—' : '$_ping ms'),
                  _metric(
                    'Descarga',
                    down == null ? '—' : '${down.toStringAsFixed(1)} Mbps',
                  ),
                  _metric(
                    'Subida',
                    _up != null
                        ? '${_up!.toStringAsFixed(1)} Mbps'
                        : (_upUnavailable ? 'no disponible' : '—'),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _running ? null : _run,
                    icon: const Icon(Icons.speed),
                    label: Text(_running ? _phase : 'Iniciar test'),
                  ),
                  if (server != null) ...[
                    const SizedBox(height: 12),
                    Text('Servidor de pruebas: ${server.name}'),
                    if (server.distant)
                      const Text(
                        'Servidor lejano: la latencia saldrá más alta y la descarga puede quedar algo por debajo de la real.',
                        textAlign: TextAlign.center,
                      ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                  ],
                  if (_notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Avisos:'),
                    for (final n in _notes)
                      Text(
                        n,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                    if (down != null && server != null && !server.distant) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Tu descarga da para unos ${(down / 8).floor()} canales HD a la vez (calculando ~8 Mbps por canal).',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}