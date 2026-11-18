import 'package:flutter/material.dart';
import 'iptv_source.dart';
import 'player_page.dart';
import 'progress_store.dart';

String _fmt(int ms) {
  final d = Duration(milliseconds: ms);
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:$m:$s' : '${d.inMinutes}:$s';
}

class ContinuePage extends StatefulWidget {
  final String accountId;
  const ContinuePage({super.key, required this.accountId});

  @override
  State<ContinuePage> createState() => _ContinuePageState();
}

class _ContinuePageState extends State<ContinuePage> {
  List<ProgressEntry>? _items;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final l = await ProgressStore.list(widget.accountId);
    if (mounted) setState(() => _items = l);
  }

  Future<void> _resume(ProgressEntry e) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerPage(
        channels: [Channel(e.id, e.name, '', e.url)],
        startIndex: 0,
        accountId: widget.accountId,
      ),
    ));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Continuar viendo')),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(child: Text('Todavía no hay nada empezado.'))
              : ListView(
                  children: [
                    for (final e in items)
                      ListTile(
                        leading: const Icon(Icons.play_circle_outline),
                        title: Text(e.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            LinearProgressIndicator(value: e.fraction),
                            const SizedBox(height: 4),
                            Text('${_fmt(e.posMs)} / ${_fmt(e.durMs)}'),
                          ],
                        ),
                        trailing: IconButton(
                          tooltip: 'Quitar',
                          icon: const Icon(Icons.close),
                          onPressed: () async {
                            await ProgressStore.remove(widget.accountId, e.id);
                            _reload();
                          },
                        ),
                        onTap: () => _resume(e),
                      ),
                  ],
                ),
    );
  }
}