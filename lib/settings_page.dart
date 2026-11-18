import 'package:flutter/material.dart';
import 'settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _audio = 'auto';
  String _sub = 'off';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await AppSettings.audioLang();
    final s = await AppSettings.subLang();
    if (mounted) setState(() {
      _audio = a;
      _sub = s;
    });
  }

  Widget _dropdown(String value, Map<String, String> options,
      ValueChanged<String> onChanged) {
    return DropdownButton<String>(
      value: value,
      items: [
        for (final e in options.entries)
          DropdownMenuItem(value: e.key, child: Text(e.value)),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Audio preferido'),
                  trailing: _dropdown(
                    _audio,
                    {'auto': 'Automático', ...langNames},
                    (v) {
                      setState(() => _audio = v);
                      AppSettings.setAudioLang(v);
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Subtítulos preferidos'),
                  trailing: _dropdown(
                    _sub,
                    {'off': 'Desactivados', ...langNames},
                    (v) {
                      setState(() => _sub = v);
                      AppSettings.setSubLang(v);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Se aplican al abrir una película o serie. Si el vídeo no tiene ese idioma o está mal etiquetado, se deja la pista por defecto. Lo que elijas a mano se recuerda para ese título.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}