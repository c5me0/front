import 'api_models.dart';

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

class ApiPage<T> {
  const ApiPage(this.items, this.nextCursor);
  final List<T> items;
  final String? nextCursor;
  factory ApiPage.fromJson(JsonObject json, T Function(JsonObject) parse) {
    final more = json['has_more'] as bool;
    final cursor = json['next_cursor'] as String?;
    if (more && (cursor == null || cursor.isEmpty)) {
      throw const FormatException('Missing pagination cursor');
    }
    return ApiPage(
      List.unmodifiable(
        (json['items'] as List).map((value) => parse(jsonObject(value))),
      ),
      more ? cursor : null,
    );
  }
}

class ApiPhoto {
  const ApiPhoto({
    required this.id,
    required this.uploaderId,
    required this.contentType,
    required this.sizeBytes,
    required this.url,
    required this.thumbnailUrl,
    required this.urlExpiresAt,
    required this.createdAt,
    required this.favorite,
    this.callId,
    this.width,
    this.height,
    this.takenAt,
  });
  final String id, uploaderId, contentType, url, thumbnailUrl;
  final String? callId;
  final int sizeBytes;
  final int? width, height;
  final DateTime urlExpiresAt, createdAt;
  final DateTime? takenAt;
  final bool favorite;
  factory ApiPhoto.fromJson(JsonObject json) => ApiPhoto(
    id: json['id'] as String,
    uploaderId: json['uploader_id'] as String,
    callId: json['call_id'] as String?,
    contentType: json['content_type'] as String,
    sizeBytes: json['size_bytes'] as int,
    width: json['width'] as int?,
    height: json['height'] as int?,
    takenAt: _date(json['taken_at']),
    favorite: json['is_favorite'] as bool,
    url: json['url'] as String,
    thumbnailUrl: json['thumbnail_url'] as String,
    urlExpiresAt: DateTime.parse(json['url_expires_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
  );
  ApiPhoto withFavorite(bool value) => _copy(favorite: value);
  ApiPhoto retainingUrlsFrom(ApiPhoto previous) => id != previous.id
      ? this
      : _copy(
          url: previous.url,
          thumbnailUrl: previous.thumbnailUrl,
          urlExpiresAt: previous.urlExpiresAt,
        );
  ApiPhoto _copy({
    bool? favorite,
    String? url,
    String? thumbnailUrl,
    DateTime? urlExpiresAt,
  }) => ApiPhoto(
    id: id,
    uploaderId: uploaderId,
    contentType: contentType,
    sizeBytes: sizeBytes,
    url: url ?? this.url,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    urlExpiresAt: urlExpiresAt ?? this.urlExpiresAt,
    createdAt: createdAt,
    favorite: favorite ?? this.favorite,
    callId: callId,
    width: width,
    height: height,
    takenAt: takenAt,
  );
}

class ApiUpload {
  const ApiUpload(this.photoId, this.url, this.thumbnailUrl, this.expiresAt);
  final String photoId, url, thumbnailUrl;
  final DateTime expiresAt;
  factory ApiUpload.fromJson(JsonObject json) => ApiUpload(
    json['photo_id'] as String,
    json['upload_url'] as String,
    json['thumbnail_upload_url'] as String,
    DateTime.parse(json['expires_at'] as String),
  );
}

class ApiCall {
  const ApiCall({
    required this.id,
    required this.status,
    required this.callerId,
    required this.calleeId,
    required this.transcriptStatus,
    required this.highlightCount,
    required this.favorite,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.title,
    this.summary,
  });
  final String id, status, callerId, calleeId, transcriptStatus;
  final String? title, summary;
  final int highlightCount;
  final bool favorite;
  final DateTime createdAt;
  final DateTime? startedAt, endedAt;
  bool get live => status == 'ringing' || status == 'active';
  double get duration => startedAt == null
      ? 0
      : ((endedAt ?? DateTime.now()).difference(startedAt!).inMilliseconds /
                1000)
            .clamp(0, double.infinity);
  factory ApiCall.fromJson(JsonObject json) => ApiCall(
    id: json['id'] as String,
    status: json['status'] as String,
    callerId: json['caller_id'] as String,
    calleeId: json['callee_id'] as String,
    transcriptStatus: json['transcript_status'] as String,
    highlightCount: json['highlight_count'] as int,
    favorite: json['is_favorite'] as bool,
    createdAt: DateTime.parse(json['created_at'] as String),
    startedAt: _date(json['started_at']),
    endedAt: _date(json['ended_at']),
    title: json['title'] as String?,
    summary: json['summary'] as String?,
  );
  ApiCall withFavorite(bool value) => ApiCall(
    id: id,
    status: status,
    callerId: callerId,
    calleeId: calleeId,
    transcriptStatus: transcriptStatus,
    highlightCount: highlightCount,
    favorite: value,
    createdAt: createdAt,
    startedAt: startedAt,
    endedAt: endedAt,
    title: title,
    summary: summary,
  );
}

class ApiHighlight {
  const ApiHighlight(this.id, this.userId, this.offsetSeconds);
  final String id, userId;
  final double offsetSeconds;
  factory ApiHighlight.fromJson(JsonObject json) => ApiHighlight(
    json['id'] as String,
    json['user_id'] as String,
    (json['offset_seconds'] as num).toDouble(),
  );
}

class ApiSegment {
  const ApiSegment(this.speakerId, this.start, this.end, this.text);
  final String speakerId, text;
  final double start, end;
  factory ApiSegment.fromJson(JsonObject json) => ApiSegment(
    json['speaker_user_id'] as String,
    (json['start'] as num).toDouble(),
    (json['end'] as num).toDouble(),
    json['text'] as String,
  );
}

class ApiCallDetail {
  const ApiCallDetail({
    required this.call,
    required this.highlights,
    required this.transcript,
    required this.photos,
    required this.iceServers,
    this.recordingUrl,
    this.urlExpiresAt,
  });
  final ApiCall call;
  final List<ApiHighlight> highlights;
  final List<ApiSegment> transcript;
  final List<ApiPhoto> photos;
  final List<JsonObject> iceServers;
  final String? recordingUrl;
  final DateTime? urlExpiresAt;
  factory ApiCallDetail.fromJson(JsonObject json) => ApiCallDetail(
    call: ApiCall.fromJson(json),
    highlights: (json['highlights'] as List)
        .map((v) => ApiHighlight.fromJson(jsonObject(v)))
        .toList(),
    transcript: (json['transcript'] as List)
        .map((v) => ApiSegment.fromJson(jsonObject(v)))
        .toList(),
    photos: (json['photos'] as List)
        .map((v) => ApiPhoto.fromJson(jsonObject(v)))
        .toList(),
    iceServers: ((json['ice_servers'] as List?) ?? []).map(jsonObject).toList(),
    recordingUrl: json['recording_url'] as String?,
    urlExpiresAt: _date(json['url_expires_at']),
  );
}

class ApiCreatedCall {
  const ApiCreatedCall(this.call, this.iceServers);
  final ApiCall call;
  final List<JsonObject> iceServers;
  factory ApiCreatedCall.fromJson(JsonObject json) => ApiCreatedCall(
    ApiCall.fromJson(jsonObject(json['call'])),
    ((json['ice_servers'] as List?) ?? []).map(jsonObject).toList(),
  );
}
