import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'epg.dart';
import 'iptv_source.dart';

String _hhmm(DateTime d) {
  final l = d.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

const _langs = {
  'spa': 'Español', 'es': 'Español', 'eng': 'Inglés', 'en': 'Inglés',
  'fre': 'Francés', 'fra': 'Francés', 'fr': 'Francés', 'ger': 'Alemán',
  'deu': 'Alemán', 'de': 'Alemán', 'ita': 'Italiano', 'it': 'Italiano',
  'por': 'Portugués', 'pt': 'Portugués', 'cat': 'Catalán', 'ca': 'Catalán',
  'jpn': 'Japonés', 'ja': 'Japonés', 'kor': 'Coreano', 'ko': 'Coreano',
  'rus': 'Ruso', 'ru': 'Ruso', 'ara': 'Árabe', 'ar': 'Árabe',
};

String _trackLabel(String id, String? title, String? lang, int i) {
  if (id == 'no') return 'Desactivados';
  final l = lang == null ? null : (_langs[lang.toLowerCase()] ?? lang);
  final text = [l, title]
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .toSet()
      .join(' · ');
  return text.isEmpty ? 'Pista ${i + 1}' : text;
}

class PlayerPage extends StatefulWidget {
  final List<Channel> channels;
  final int startIndex;
  final void Function(Channel)? onChannelChanged;
  final Epg? Function()? epgProvider;

  const PlayerPage({
    super.key,
    required this.channels,
    required this.startIndex,
    this.onChannelChanged,
    this.epgProvider,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player player = Player();
  late final VideoController controller = VideoController(player);
  final GlobalKey<VideoState> _videoKey = GlobalKey<VideoState>();
  late final ValueNotifier<int> _index = ValueNotifier<int>(widget.startIndex);
  final ValueNotifier<bool> _stalled = ValueNotifier<bool>(false);
  final List<StreamSubscription> _subs = [];
  Timer? _watchdog;
  bool _playedOk = false;

  Channel get _current => widget.channels[_index.value];

  @override
  void initState() {
    super.initState();
    _subs.add(player.stream.position.listen((p) {
      if (p > Duration.zero) {
        _playedOk = true;
        _watchdog?.cancel();
        if (_stalled.value) _stalled.value = false;
      }
    }));
    _subs.add(player.stream.error.listen((_) => _markStalled()));
    _openChannel();
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    player.dispose();
    _index.dispose();
    _stalled.dispose();
    super.dispose();
  }

  void _markStalled() {
    if (_playedOk || !mounted) return;
    _watchdog?.cancel();
    _stalled.value = true;
    player.stop();
  }

  void _openChannel() {
    _playedOk = false;
    _stalled.value = false;
    _watchdog?.cancel();
    player.open(Media(_current.url));
    _watchdog = Timer(const Duration(seconds: 15), _markStalled);
  }

  void _changeChannel(int delta) {
    final n = widget.channels.length;
    if (n < 2) return;
    _index.value = (_index.value + delta) % n;
    _openChannel();
    widget.onChannelChanged?.call(_current);
  }

  String _titleLine(Channel ch) {
    final now = widget.epgProvider?.call()?.nowOn(ch);
    if (now == null) return ch.name;
    return '${ch.name}  ·  ${_hhmm(now.start)}–${_hhmm(now.end)} ${now.title}';
  }

  Widget _appBarTitle(Channel ch) {
    final now = widget.epgProvider?.call()?.nowOn(ch);
    if (now == null) return Text(ch.name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(ch.name),
        Text(
          '${_hhmm(now.start)}–${_hhmm(now.end)}  ${now.title}',
          style: const TextStyle(fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _showGuide() {
    final ch = _current;
    final epg = widget.epgProvider?.call();
    final now = DateTime.now().toUtc();
    final all = epg?.programmesFor(ch) ?? <Programme>[];
    final list = all.where((p) => p.end.isAfter(now)).toList();

    String reason;
    if (epg == null) {
      reason =
          'La guía aún no está cargada, o no se ha configurado en la cuenta.';
    } else if (all.isEmpty) {
      reason = 'La guía no tiene programación para este canal.\n'
          'Identificador de guía del canal: ${ch.epgId ?? '(ninguno)'}';
    } else {
      reason = 'No quedan programas próximos para este canal.';
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ch.name),
        content: SizedBox(
          width: 460,
          height: 380,
          child: list.isEmpty
              ? Text(reason)
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final p = list[i];
                    return ListTile(
                      dense: true,
                      selected: !p.start.isAfter(now),
                      leading: Text('${_hhmm(p.start)}\n${_hhmm(p.end)}'),
                      title: Text(p.title),
                      subtitle: p.desc.isEmpty
                          ? null
                          : Text(
                              p.desc,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showTracks() {
    final t = player.state.tracks;
    final audio = t.audio.where((a) => a.id != 'auto' && a.id != 'no').toList();
    final subs = t.subtitle.where((s) => s.id != 'auto').toList();
    var selA = player.state.track.audio.id;
    var selS = player.state.track.subtitle.id;
    const bold = TextStyle(fontWeight: FontWeight.bold);

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Audio y subtítulos'),
          content: SizedBox(
            width: 420,
            height: 360,
            child: ListView(
              children: [
                const Text('Audio', style: bold),
                if (audio.isEmpty)
                  const Text('No hay pistas de audio alternativas.'),
                for (var i = 0; i < audio.length; i++)
                  ListTile(
                    dense: true,
                    title: Text(_trackLabel(
                        audio[i].id, audio[i].title, audio[i].language, i)),
                    trailing:
                        selA == audio[i].id ? const Icon(Icons.check) : null,
                    onTap: () {
                      player.setAudioTrack(audio[i]);
                      setS(() => selA = audio[i].id);
                    },
                  ),
                const Divider(),
                const Text('Subtítulos', style: bold),
                if (subs.length < 2)
                  const Text('No hay subtítulos disponibles.'),
                for (var i = 0; i < subs.length; i++)
                  ListTile(
                    dense: true,
                    title: Text(_trackLabel(
                        subs[i].id, subs[i].title, subs[i].language, i)),
                    trailing:
                        selS == subs[i].id ? const Icon(Icons.check) : null,
                    onTap: () {
                      player.setSubtitleTrack(subs[i]);
                      setS(() => selS = subs[i].id);
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
        const SingleActivator(LogicalKeyboardKey.space): () =>
            player.playOrPause(),
        const SingleActivator(LogicalKeyboardKey.keyM): () =>
            player.setVolume(player.state.volume > 0 ? 0 : 100),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            player.setVolume(
                (player.state.volume + 5).clamp(0.0, 100.0).toDouble()),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            player.setVolume(
                (player.state.volume - 5).clamp(0.0, 100.0).toDouble()),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => player.seek(
            player.state.position - const Duration(seconds: 10)),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => player.seek(
            player.state.position + const Duration(seconds: 10)),
        const SingleActivator(LogicalKeyboardKey.pageUp): () =>
            _changeChannel(-1),
        const SingleActivator(LogicalKeyboardKey.pageDown): () =>
            _changeChannel(1),
        const SingleActivator(LogicalKeyboardKey.keyI): _showGuide,
        const SingleActivator(LogicalKeyboardKey.keyS): _showTracks,
        const SingleActivator(LogicalKeyboardKey.keyF): () =>
            _videoKey.currentState?.toggleFullscreen(),
        const SingleActivator(LogicalKeyboardKey.f11): () =>
            _videoKey.currentState?.toggleFullscreen(),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            _videoKey.currentState?.exitFullscreen(),
      };

  Widget _stalledOverlay() {
    return ValueListenableBuilder<bool>(
      valueListenable: _stalled,
      builder: (_, stalled, __) {
        if (!stalled) return const SizedBox.shrink();
        return Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 40),
                  const SizedBox(height: 8),
                  const Text('El canal no responde'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton(
                        onPressed: _openChannel,
                        child: const Text('Reintentar'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonal(
                        onPressed: () => _changeChannel(1),
                        child: const Text('Siguiente canal'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = MaterialDesktopVideoControlsThemeData(
      keyboardShortcuts: _shortcuts,
      bottomButtonBar: [
        MaterialDesktopCustomButton(
          icon: const Icon(Icons.skip_previous),
          onPressed: () => _changeChannel(-1),
        ),
        const MaterialDesktopPlayOrPauseButton(),
        MaterialDesktopCustomButton(
          icon: const Icon(Icons.skip_next),
          onPressed: () => _changeChannel(1),
        ),
        const MaterialDesktopVolumeButton(),
        const SizedBox(width: 12),
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: _index,
            builder: (_, i, __) => Text(
              _titleLine(widget.channels[i]),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        MaterialDesktopCustomButton(
          icon: const Icon(Icons.subtitles),
          onPressed: _showTracks,
        ),
        MaterialDesktopCustomButton(
          icon: const Icon(Icons.list_alt),
          onPressed: _showGuide,
        ),
        const MaterialFullscreenButton(),
      ],
    );

    return MaterialDesktopVideoControlsTheme(
      normal: theme,
      fullscreen: theme,
      child: Scaffold(
        appBar: AppBar(
          title: ValueListenableBuilder<int>(
            valueListenable: _index,
            builder: (_, i, __) => _appBarTitle(widget.channels[i]),
          ),
        ),
        body: Video(
          key: _videoKey,
          controller: controller,
          controls: (state) => Stack(
            children: [
              MaterialDesktopVideoControls(state),
              _stalledOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}