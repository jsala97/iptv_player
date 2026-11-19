import 'package:material_ui/material_ui.dart';
import 'settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _audio = 'auto';
  String _sub = 'off';
  String _mode = 'dark';
  int _accent = 0xFF5B8DEF;
  bool _clean = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await AppSettings.audioLang();
    final s = await AppSettings.subLang();
    final m = await AppSettings.themeMode(); 
    final c = await AppSettings.accent();
    final cl = await AppSettings.cleanNames();
    

    if (mounted) {
      setState(() {
      _mode = m; 
      _accent = c;
      _audio = a;
      _sub = s;
      _clean = cl;
    });
    }
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
                                ListTile(
                  title: const Text('Tema'),
                  trailing: _dropdown(
                    _mode,
                    const {
                      'dark': 'Oscuro',
                      'light': 'Claro',
                      'system': 'Del sistema',
                    },
                    (v) {
                      setState(() => _mode = v);
                      AppSettings.setThemeMode(v);
                      themeModeNotifier.value = switch (v) {
                        'light' => ThemeMode.light,
                        'system' => ThemeMode.system,
                        _ => ThemeMode.dark,
                      };
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Color de acento'),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      for (final c in const [
                        0xFF5B8DEF, 0xFF2EC4B6, 0xFF9B6BFF,
                        0xFFFF6B6B, 0xFFFFB84D, 0xFF6BCB77,
                      ])
                        InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            setState(() => _accent = c);
                            AppSettings.setAccent(c);
                            accentNotifier.value = Color(c);
                          },
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: Color(c),
                            child: _accent == c
                                ? const Icon(Icons.check,
                                    size: 16, color: Colors.white)
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
                SwitchListTile(
                  title: const Text('Quitar prefijos de los nombres de canales'),
                  value: _clean,
                  onChanged: (v) {
                    setState(() => _clean = v);
                    AppSettings.setCleanNames(v);
                    cleanNamesNotifier.value = v;
                  },
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