import 'package:flutter/material.dart';
import 'account.dart';
import 'server_test.dart';

class ServerPickerPage extends StatefulWidget {
  final Account account;
  const ServerPickerPage({super.key, required this.account});

  @override
  State<ServerPickerPage> createState() => _ServerPickerPageState();
}

class _ServerPickerPageState extends State<ServerPickerPage> {
  final Map<String, ServerResult> _results = {};
  bool _testing = false;
  String? _testingServer;

  Future<void> _testAll() async {
    setState(() {
      _testing = true;
      _results.clear();
    });
    // Uno detrás de otro, para que no se roben ancho de banda entre ellos.
    for (final s in widget.account.servers) {
      if (!mounted) return;
      setState(() => _testingServer = s);
      final r = await testServer(s, widget.account.user, widget.account.pass);
      if (!mounted) return;
      setState(() => _results[s] = r);
    }
    if (mounted) {
      setState(() {
        _testing = false;
        _testingServer = null;
      });
    }
  }

  String? get _best {
    final ok = _results.values.where((r) => r.ok).toList();
    if (ok.isEmpty) return null;
    ok.sort((a, b) {
      final ma = a.mbps ?? 0;
      final mb = b.mbps ?? 0;
      if (ma != mb) return mb.compareTo(ma);
      return a.latencyMs!.compareTo(b.latencyMs!);
    });
    return ok.first.server;
  }

  String _subtitle(String server) {
    if (_testingServer == server) return 'Probando...';
    final r = _results[server];
    if (r == null) return 'Sin probar';
    if (!r.ok) return '✗ ${r.error}';
    final speed = r.mbps == null
        ? 'velocidad no medible'
        : '${r.mbps!.toStringAsFixed(1)} Mbps';
    return '✓ respuesta ${r.latencyMs} ms · $speed';
  }

  @override
  Widget build(BuildContext context) {
    final best = _best;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account.name),
        actions: [
          TextButton.icon(
            onPressed: _testing ? null : _testAll,
            icon: const Icon(Icons.speed),
            label: Text(_testing ? 'Probando...' : 'Probar todos'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        children: [
          for (final s in widget.account.servers)
            ListTile(
              leading: Icon(s == best ? Icons.star : Icons.dns),
              title: Text(s),
              subtitle: Text(_subtitle(s)),
              trailing: s == best ? const Text('Mejor') : null,
              onTap: () => Navigator.pop(context, s),
            ),
        ],
      ),
    );
  }
}