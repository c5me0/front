import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import '../../api/api_error_text.dart';
import '../../api/cameo_api.dart';
import '../../api/media_models.dart';
import '../../components/backend_notice.dart';
import '../../components/confirm_sheet.dart';
import '../../components/playback_controller.dart';
import '../../components/transcript_reader.dart';
import '../instant_viewer/instant_subject.dart';
import '../../content/app.g.dart';
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
    final copy = AppContent.of(context).v6.backend;
    final detail = _detail;
    final owner = SessionScope.read(context).userId;
    final entries = <TranscriptEntry>[];
    if (detail != null) {
      for (var i = 0; i < detail.transcript.length; i++) {
        final segment = detail.transcript[i];
        // Highlights preserve the 15 seconds preceding the user's mark.
        final highlight = detail.highlights
            .where(
              (mark) =>
                  segment.end > mark.offsetSeconds - 15 &&
                  segment.start <= mark.offsetSeconds,
            )
            .firstOrNull;
        entries.add(
          TranscriptEntry(
            id: '$i',
            text: segment.text,
            start: segment.start,
            end: segment.end,
            right: segment.speakerId == owner,
            highlight: highlight?.id,
          ),
        );
      }
    }
    final notice = _error != null
        ? '${apiErrorCodeText(_error!, copy: AppContent.of(context))} ${copy.retry}'
        : detail == null
        ? copy.loading
        : detail.transcript.isEmpty
        ? ({'pending', 'processing'}.contains(detail.call.transcriptStatus)
              ? copy.transcriptPending
              : copy.transcriptUnavailable)
        : detail.recordingUrl == null
        ? copy.recordingUnavailable
        : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        TranscriptReader(
          title: detail?.call.title ?? copy.callRecord,
          subtitle: detail == null
              ? ''
              : formatAlbumDate(
                  detail.call.createdAt.toLocal(),
                  languageCode: Localizations.localeOf(context).languageCode,
                ),
          entries: entries,
          playback: _playback,
          liked: detail?.call.favorite ?? false,
          onClose: () => CameoNav.pop(context),
          onCall: () => CameoNav.openCall(context),
          onLike: () => unawaited(_like()),
          onDelete: () => setState(() => _deleteSheet = true),
          notice: notice == null
              ? null
              : BackendNotice(
                  message: notice,
                  onRetry: _error == null ? null : _load,
                ),
          media: [
            for (final photo in detail?.photos ?? const <ApiPhoto>[])
              Padding(
                padding: const EdgeInsets.all(18),
                child: PressScale(
                  accessibilityLabel: AppContent.of(context).v6.storage.media,
                  onPress: () {
                    _playback?.pause();
                    AlbumScope.read(context).remote.receivedPhoto(photo);
                    setInstantSubject(
                      InstantSubject(
                        image: NetworkImage(
                          photo.isVideo ? photo.thumbnailUrl : photo.url,
                        ),
                        share: photo.url,
                        albumPhotoId: photo.id,
                        video: photo.isVideo,
                        aspectRatio: (photo.height ?? 0) > 0
                            ? (photo.width ?? 0) / photo.height!
                            : 3 / 4,
                      ),
                    );
                    CameoNav.openInstant(context);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(CameoRadius.xl),
                    child: Image.network(
                      photo.thumbnailUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
          ],
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
    );
  }
}
