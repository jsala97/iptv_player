import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PlayerPage extends StatefulWidget {
  final String title;
  final String url;
  const PlayerPage({super.key, required this.title, required this.url});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player player = Player();
  late final VideoController controller = VideoController(player);
  final GlobalKey<VideoState> _videoKey = GlobalKey<VideoState>();

  @override
  void initState() {
    super.initState();
    player.open(Media(widget.url));
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
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
    );
    return MaterialDesktopVideoControlsTheme(
      normal: theme,
      fullscreen: theme,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Video(key: _videoKey, controller: controller),
      ),
    );
  }
}