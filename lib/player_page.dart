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

  Channel get _current => widget.channels[_index.value];

  @override
  void initState() {
    super.initState();
    player.open(Media(_current.url));
  }

  @override
  void dispose() {
    player.dispose();
    _index.dispose();
    super.dispose();
  }

  void _changeChannel(int delta) {
    final n = widget.channels.length;
    if (n < 2) return;
    _index.value = (_index.value + delta) % n;
    player.open(Media(_current.url));
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
        body: Video(key: _videoKey, controller: controller),
      ),
    );
  }
}