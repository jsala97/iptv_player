import 'package:flutter/material.dart';
import 'account.dart';
import 'channels_page.dart';

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

  Future<void> _connect(Account acc) async {
    setState(() => _connecting = true);
    try {
      final source = acc.createSource();
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
    final server = TextEditingController();
    final user = TextEditingController();
    final pass = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva cuenta'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nombre (ej: Casa)'),
              ),
              TextField(
                controller: server,
                decoration: const InputDecoration(
                  labelText: 'Servidor (ej: servidor.com:8080)',
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

    var base = server.text.trim();
    if (!base.startsWith('http')) base = 'http://$base';
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);

    final acc = Account(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.text.trim().isEmpty ? base : name.text.trim(),
      type: AccountType.xtream,
      server: base,
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
              ? const Center(child: Text('Aún no tienes cuentas. Pulsa "Añadir cuenta".'))
              : Stack(
                  children: [
                    ListView.builder(
                      itemCount: _accounts.length,
                      itemBuilder: (context, i) {
                        final acc = _accounts[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: ListTile(
                            leading: const Icon(Icons.dns),
                            title: Text(acc.name),
                            subtitle: Text(acc.server),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(acc),
                            ),
                            onTap: _connecting ? null : () => _connect(acc),
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