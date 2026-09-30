// Account-scoped profile, membership, and relationship archives. Match former partners
// by stable ID rather than a potentially rotated invitation code.

import 'album_store.dart';

class RelationshipArchive {
  const RelationshipArchive({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    required this.partnerAvatar,
    required this.album,
  });

  final String id;
  final String partnerId;
  final String partnerName;
  final String partnerAvatar;
  final AlbumSnapshot album;

  Map<String, Object?> toJson() => {
    'id': id,
    'partnerId': partnerId,
    'partnerName': partnerName,
    'partnerAvatar': partnerAvatar,
    'album': album.toJson(),
  };

  factory RelationshipArchive.fromJson(Map<String, dynamic> json) =>
      RelationshipArchive(
        id: json['id'] as String,
        partnerId: json['partnerId'] as String,
        partnerName: json['partnerName'] as String,
        partnerAvatar: json['partnerAvatar'] as String,
        album: AlbumSnapshot.fromJson(json['album'] as Map<String, dynamic>),
      );
}

class AccountRecord {
  AccountRecord({
    required Map<String, Object?> profile,
    this.album,
    this.monthlyUntil,
    Map<String, RelationshipArchive> archives = const {},
  }) : profile = Map.unmodifiable(profile),
       archives = Map.unmodifiable(archives);

  final Map<String, Object?> profile;
  final AlbumSnapshot? album;
  final DateTime? monthlyUntil;
  final Map<String, RelationshipArchive> archives;

  AccountRecord copyWith({
    Map<String, Object?>? profile,
    AlbumSnapshot? album,
    bool clearAlbum = false,
    DateTime? monthlyUntil,
    Map<String, RelationshipArchive>? archives,
  }) => AccountRecord(
    profile: profile ?? this.profile,
    album: clearAlbum ? null : album ?? this.album,
    monthlyUntil: monthlyUntil ?? this.monthlyUntil,
    archives: archives ?? this.archives,
  );

  Map<String, Object?> toJson() => {
    'profile': profile,
    'album': album?.toJson(),
    'monthlyUntil': monthlyUntil?.toIso8601String(),
    'archives': {
      for (final entry in archives.entries) entry.key: entry.value.toJson(),
    },
  };

  factory AccountRecord.fromJson(Map<String, dynamic> json) => AccountRecord(
    profile: json['profile'] as Map<String, dynamic>,
    album: json['album'] == null
        ? null
        : AlbumSnapshot.fromJson(json['album'] as Map<String, dynamic>),
    monthlyUntil: json['monthlyUntil'] == null
        ? null
        : DateTime.parse(json['monthlyUntil'] as String),
    archives: {
      for (final entry in (json['archives'] as Map<String, dynamic>).entries)
        entry.key: RelationshipArchive.fromJson(
          entry.value as Map<String, dynamic>,
        ),
    },
  );
}

class RecoveryRequired implements Exception {
  const RecoveryRequired(this.archive);
  final RelationshipArchive archive;
}
