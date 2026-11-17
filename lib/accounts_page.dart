import 'package:flutter/material.dart';
import 'account.dart';
import 'channels_page.dart';
import 'server_picker_page.dart';

String _normalize(String s) {
  s = s.trim();
  if (s.isEmpty) return '';
  if (!s.startsWith('http')) s = 'http://$s';
  if (s.endsWith('/')) s = s.substring(0, s.length - 1);
  return s;
}

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  List<Account> _accounts = [];
  bool _loaded = false;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await AccountStore.load();
    if (!mounted) return;
    setState(() {
      _accounts = list;
      _loaded = true;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _open(Account acc) async {
    String? server;
    if (acc.servers.length == 1) {
      server = acc.servers.first;
    } else {
      server = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => ServerPickerPage(account: acc)),
      );
    }
    if (server == null) return;
    await _connect(acc, server);
  }

  Future<void> _connect(Account acc, String server) async {
    setState(() => _connecting = true);
    try {
      final source = acc.createSource(server);
      if (!await source.login()) {
        _snack('Usuario o contraseña incorrectos');
        return;
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChannelsPage(source: source, accountId: acc.id),
        ),
      );
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _addAccount() async {
    final name = TextEditingController();
    final servers = TextEditingController();
    final user = TextEditingController();
    final pass = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva cuenta'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nombre (ej: Casa)'),
              ),
              TextField(
                controller: servers,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Servidores (uno por línea)',
                  hintText: 'servidor1.com:8080\nservidor2.com:8080',
                ),
              ),
              TextField(
                controller: user,
                decoration: const InputDecoration(labelText: 'Usuario'),
              ),
              TextField(
                controller: pass,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final list = servers.text
        .split('\n')
        .map(_normalize)
        .where((s) => s.isNotEmpty)
        .toList();
    if (list.isEmpty) {
      _snack('Añade al menos un servidor');
      return;
    }

    final acc = Account(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.text.trim().isEmpty ? list.first : name.text.trim(),
      type: AccountType.xtream,
      servers: list,
      user: user.text.trim(),
      pass: pass.text.trim(),
    );
    _accounts.add(acc);
    await AccountStore.save(_accounts);
    setState(() {});
  }

  Future<void> _delete(Account acc) async {
    _accounts.remove(acc);
    await AccountStore.save(_accounts);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis cuentas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAccount,
        icon: const Icon(Icons.add),
        label: const Text('Añadir cuenta'),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
              ? const Center(
                  child: Text('Aún no tienes cuentas. Pulsa "Añadir cuenta".'),
                )
              : Stack(
                  children: [
                    ListView.builder(
                      itemCount: _accounts.length,
                      itemBuilder: (context, i) {
                        final acc = _accounts[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.dns),
                            title: Text(acc.name),
                            subtitle: Text(
                              acc.servers.length == 1
                                  ? acc.servers.first
                                  : '${acc.servers.length} servidores',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(acc),
                            ),
                            onTap: _connecting ? null : () => _open(acc),
                          ),
                        );
                      },
                    ),
                    if (_connecting)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
    );
  }
}