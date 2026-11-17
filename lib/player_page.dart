import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'iptv_source.dart';

class PlayerPage extends StatefulWidget {
  final List<Channel> channels;
  final int startIndex;
  final void Function(Channel)? onChannelChanged;

  const PlayerPage({
    super.key,
    required this.channels,
    required this.startIndex,
    this.onChannelChanged,
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
              widget.channels[i].name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ),
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
            builder: (_, i, __) => Text(widget.channels[i].name),
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