import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:video_player/video_player.dart';

import '../api/cameo_api.dart' show mediaUri;
import '../content/app.g.dart';
import '../design_system/design_system.dart';
import 'scrim_button.dart';

/// Loads a video only after an explicit play gesture. Hidden pages and app
/// backgrounding stop playback; signed media URLs never receive API credentials.
class MediaPlayer extends StatefulWidget {
  const MediaPlayer({
    super.key,
    required this.uri,
    required this.poster,
    this.active = true,
  });
  final String uri;
  final ImageProvider poster;
  final bool active;

  @override
  State<MediaPlayer> createState() => _MediaPlayerState();
}

class _MediaPlayerState extends State<MediaPlayer> with WidgetsBindingObserver {
  VideoPlayerController? _player;
  bool _loading = false, _failed = false;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context)?.isCurrent == false) unawaited(_player?.pause());
  }

  @override
  void didUpdateWidget(MediaPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) {
      _epoch++;
      final old = _player;
      _player = null;
      _loading = _failed = false;
      if (old != null) unawaited(old.dispose());
    } else if (!widget.active) {
      unawaited(_player?.pause());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_player?.pause());
  }

  Future<void> _toggle() async {
    if (_loading || !widget.active) return;
    final epoch = _epoch;
    try {
      var player = _player;
      if (player == null || _failed) {
        setState(() {
          _loading = true;
          _failed = false;
        });
        await player?.dispose();
        final options = VideoPlayerOptions(mixWithOthers: true);
        player = widget.uri.startsWith('https://')
            ? VideoPlayerController.networkUrl(
                mediaUri(widget.uri),
                videoPlayerOptions: options,
              )
            : VideoPlayerController.file(
                File(widget.uri),
                videoPlayerOptions: options,
              );
        _player = player;
        await player.initialize();
        if (!mounted || epoch != _epoch) return;
        setState(() => _loading = false);
      }
      if (!mounted ||
          epoch != _epoch ||
          !widget.active ||
          (WidgetsBinding.instance.lifecycleState != null &&
              WidgetsBinding.instance.lifecycleState !=
                  AppLifecycleState.resumed)) {
        return;
      }
      if (player.value.isPlaying) {
        await player.pause();
      } else {
        if (player.value.position >= player.value.duration) {
          await player.seekTo(Duration.zero);
        }
        await player.play();
      }
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _epoch++;
    WidgetsBinding.instance.removeObserver(this);
    final player = _player;
    if (player != null) unawaited(player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    final copy = AppContent.of(context).v6.storage;
    Widget content(VideoPlayerValue? value) => Stack(
      fit: StackFit.expand,
      children: [
        Image(image: widget.poster, fit: BoxFit.cover, gaplessPlayback: true),
        if (player != null && value?.isInitialized == true && !_failed)
          FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: value!.size.width,
              height: value.size.height,
              child: VideoPlayer(player),
            ),
          ),
        Center(
          child: _loading
              ? CupertinoActivityIndicator(
                  color: CameoPalette.dark.staticWhiteBase,
                )
              : ScrimButton(
                  size: ScrimButtonSize.xl,
                  tone: ScrimButtonTone.dark,
                  icon: value?.isPlaying == true
                      ? CameoIconName.playerPauseFilled
                      : CameoIconName.playerPlayFilled,
                  semanticLabel: value?.isPlaying == true
                      ? copy.pauseVideo
                      : copy.playVideo,
                  onPress: _toggle,
                ),
        ),
        if (_failed || value?.hasError == true)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(CameoSpace.s16),
              child: CameoText(
                copy.videoFailed,
                style: CameoTextStyles.bodyMd,
                color: CameoPalette.dark.staticWhiteBase,
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
    return player == null
        ? content(null)
        : ValueListenableBuilder(
            valueListenable: player,
            builder: (_, value, __) => content(value),
          );
  }
}
