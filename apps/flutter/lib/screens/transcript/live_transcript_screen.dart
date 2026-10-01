import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import '../../api/api_error_text.dart';
import '../../api/cameo_api.dart';
import '../../api/media_models.dart';
import '../../components/backend_notice.dart';
import '../../components/confirm_sheet.dart';
import '../../components/highlight_card_v6.dart';
import '../../components/playback_controller.dart';
import '../../components/player_bar_v6.dart';
import '../../components/solid_button.dart';
import '../../components/transcript_nav_v6.dart';
import '../../components/transcript_v6_line.dart';
import '../../components/transcript_v6_title.dart';
import '../../content/app.g.dart';
import '../../content/lab.g.dart';
import '../../design_system/design_system.dart';
import '../../navigation/cameo_nav.dart';
import '../../state/album_store.dart';
import '../../state/session.dart';

class LiveTranscriptScreen extends StatefulWidget {
  const LiveTranscriptScreen({super.key, this.callId});
  final String? callId;
  @override
  State<LiveTranscriptScreen> createState() => _LiveTranscriptScreenState();
}

class _LiveTranscriptScreenState extends State<LiveTranscriptScreen>
    with TickerProviderStateMixin {
  ApiCallDetail? _detail;
  CameoApi? _api;
  AudioPlayer? _audio;
  PlaybackController? _playback;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _poll;
  String? _error;
  bool _loading = false, _deleteSheet = false;
  DateTime? _recordingExpiry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _api = SessionScope.read(context).backend;
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    if (_loading) return;
    if (widget.callId == null || _api == null) {
      setState(() => _error = 'invalid_request');
      return;
    }
    _loading = true;
    try {
      final detail = await _api!.call(widget.callId!);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _error = null;
      });
      final duration = detail.call.duration;
      if (detail.recordingUrl != null && duration > 0) {
        if (_audio == null) {
          final audio = _audio = AudioPlayer();
          _playback = PlaybackController(
            vsync: this,
            durationSec: duration,
            externallyDriven: true,
            onPlayingChange: (play) => unawaited(_play(play)),
            onSeekSeconds: (seconds) => unawaited(_seek(seconds)),
          );
          _subscriptions.add(
            audio.positionStream.listen((position) {
              _playback?.syncExternal(
                position.inMilliseconds / 1000,
                audio.playing,
              );
              if (mounted) setState(() {});
            }),
          );
          _subscriptions.add(
            audio.playerStateStream.listen((state) {
              _playback?.syncExternal(
                audio.position.inMilliseconds / 1000,
                state.playing &&
                    state.processingState != ProcessingState.completed,
              );
            }),
          );
          _subscriptions.add(
            audio.errorStream.listen((_) {
              if (mounted) setState(() => _error = 'playback_failed');
            }),
          );
        }
        if (_recordingExpiry == null ||
            _recordingExpiry!.isBefore(
              DateTime.now().add(const Duration(minutes: 1)),
            )) {
          final at = _audio!.position;
          await _audio!.setUrl(
            mediaUri(detail.recordingUrl!).toString(),
            initialPosition: at,
          );
          if (!mounted) return;
          _recordingExpiry = detail.urlExpiresAt;
          setState(() {});
        }
      }
      _poll?.cancel();
      final pending = {
        'pending',
        'processing',
      }.contains(detail.call.transcriptStatus);
      _poll = Timer(
        pending ? const Duration(seconds: 4) : const Duration(minutes: 45),
        () => unawaited(_load()),
      );
    } catch (problem) {
      if (mounted) {
        setState(
          () => _error = problem is ApiException
              ? problem.code
              : 'playback_failed',
        );
      }
    } finally {
      _loading = false;
    }
  }

  Future<void> _play(bool play) async {
    try {
      if (play) {
        if (_recordingExpiry?.isBefore(DateTime.now()) == true) await _load();
        if (_audio?.processingState == ProcessingState.completed) {
          await _audio?.seek(Duration.zero);
        }
        await _audio?.play();
      } else {
        await _audio?.pause();
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'playback_failed');
    }
  }

  Future<void> _seek(double seconds) async {
    try {
      await _audio?.seek(Duration(milliseconds: (seconds * 1000).round()));
    } catch (_) {
      if (mounted) setState(() => _error = 'playback_failed');
    }
  }

  Future<void> _like() async {
    final detail = _detail;
    if (detail == null) return;
    final album = AlbumScope.read(context).remote;
    if (await album.favoriteCall(detail.call.id, !detail.call.favorite)) {
      await _load();
    } else if (mounted) {
      setState(() => _error = album.error);
    }
  }

  Future<void> _delete() async {
    if (_detail == null) return;
    final album = AlbumScope.read(context).remote;
    final ok = await album.deleteCall(_detail!.call.id);
    if (!mounted) return;
    if (ok) {
      CameoNav.pop(context);
    } else {
      setState(() {
        _deleteSheet = false;
        _error = album.error;
      });
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_audio?.dispose());
    _playback?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CameoTheme.colorsOf(context), copy = appContent.v6.backend;
    final detail = _detail, playback = _playback;
    final seconds = playback?.seconds ?? 0;
    final owner = SessionScope.read(context).userId;
    final highlights = <HighlightCardV6Line>[];
    final lines = <Widget>[];
    if (detail != null) {
      for (var i = 0; i < detail.transcript.length; i++) {
        final segment = detail.transcript[i];
        final current = seconds >= segment.start && seconds < segment.end;
        final side = segment.speakerId == owner
            ? LabAlign.right
            : LabAlign.left;
        final highlighted = detail.highlights.any(
          (h) =>
              h.offsetSeconds >= segment.start &&
              h.offsetSeconds <= segment.end,
        );
        if (highlighted) {
          highlights.add((
            id: '$i',
            text: segment.text,
            side: side,
            current: current,
          ));
        } else {
          lines.add(
            TranscriptLineV6(
              id: '$i',
              text: segment.text,
              side: side,
              current: current,
              onPress: playback == null
                  ? null
                  : () => playback.seekTo(segment.start / playback.durationSec),
            ),
          );
        }
      }
    }
    return ColoredBox(
      color: c.backgroundCanvasNeutralStrong,
      child: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            key: const ValueKey('transcript.live'),
            padding: const EdgeInsets.only(
              top: CameoLayout.transcriptV6HeaderHeight,
              bottom: CameoLayout.tabBarV6FullContainerHeight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  BackendNotice(
                    message: '${apiErrorCodeText(_error!)} ${copy.retry}',
                    onRetry: _load,
                  ),
                if (detail == null && _error == null)
                  BackendNotice(message: copy.loading),
                if (detail != null) ...[
                  TranscriptTitleV6(
                    title: detail.call.title ?? copy.callRecord,
                    date: formatAlbumDate(detail.call.createdAt.toLocal()),
                  ),
                  if (detail.call.summary?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.all(
                        CameoLayout.transcriptV6LinePaddingX,
                      ),
                      child: CameoText(
                        detail.call.summary!,
                        style: CameoTextStyles.bodyLg,
                        color: c.foregroundNeutralBase,
                      ),
                    ),
                  if (detail.transcript.isEmpty)
                    BackendNotice(
                      message:
                          {
                            'pending',
                            'processing',
                          }.contains(detail.call.transcriptStatus)
                          ? copy.transcriptPending
                          : copy.transcriptUnavailable,
                    ),
                  ...lines,
                  if (highlights.isNotEmpty)
                    HighlightCardV6(
                      lines: highlights,
                      onLinePress: (line) {
                        if (playback != null) {
                          playback.seekTo(
                            detail.transcript[int.parse(line.id)].start /
                                playback.durationSec,
                          );
                        }
                      },
                    ),
                  for (final photo in detail.photos)
                    Padding(
                      padding: const EdgeInsets.all(
                        CameoLayout.transcriptV6LinePaddingX,
                      ),
                      child: Image.network(
                        photo.url,
                        fit: BoxFit.contain,
                        semanticLabel: appContent.v6.album.shareLabel,
                      ),
                    ),
                  if (detail.recordingUrl == null)
                    BackendNotice(message: copy.recordingUnavailable),
                  Padding(
                    padding: const EdgeInsets.all(
                      CameoLayout.transcriptV6LinePaddingX,
                    ),
                    child: SolidButton(
                      label: copy.delete,
                      icon: CameoIconName.trash,
                      onPress: () => setState(() => _deleteSheet = true),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (playback != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: PlayerBarV6(
                playback: playback,
                markers: [
                  for (final highlight in detail!.highlights)
                    PlayerV5MarkerContent(
                      nodeId: highlight.id,
                      leftPx: 0,
                      widthPx: 0,
                      start: (highlight.offsetSeconds / playback.durationSec)
                          .clamp(0, 1),
                      width: (1 / playback.durationSec).clamp(0, 1),
                    ),
                ],
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: CameoLayout.transcriptV6HeaderHeight,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: c.gradients.topLinear),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: CameoLayout.topNavV6Top,
            child: TranscriptNavV6(
              onClose: () => CameoNav.pop(context),
              onCall: () {
                unawaited(_audio?.pause());
                CameoNav.openCall(context);
              },
              liked: detail?.call.favorite ?? false,
              onToggleLike: _like,
            ),
          ),
          if (_deleteSheet)
            Positioned.fill(
              child: ConfirmSheet(
                visible: true,
                title: copy.callDelete,
                body: '',
                confirmLabel: copy.delete,
                cancelLabel: copy.cancel,
                destructive: true,
                onConfirm: _delete,
                onCancel: () => setState(() => _deleteSheet = false),
              ),
            ),
        ],
      ),
    );
  }
}
