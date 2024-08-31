import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:sweyer/sweyer.dart';
import 'package:equatable/equatable.dart';

/// A type of a content.
enum ContentType<T extends Content> {
  /// A song.
  song<Song>(Icons.music_note_rounded),

  /// A collection of songs by their creator.
  album<Album>(Icons.album_rounded),

  /// A collection of songs by the user.
  playlist<Playlist>(Icons.queue_music_rounded),

  /// A creator of songs.
  artist<Artist>(Icons.person_rounded);

  const ContentType(this.icon);

  /// The icon representing this content type.
  final IconData icon;
}

/// Represents some content in the app (songs, album, etc).
///
/// Each type of content have an appropriate [Sort]s implemented.
abstract class Content with EquatableMixin {
  const Content();

  // The type of this content.
  ContentType get type;

  /// A unique ID of the content.
  int get id;

  /// Title of the content.
  String get title;

  /// Creates a copy of this content with the given fields replaced with new values.
  dynamic get copyWith;

  /// Converts the content to media item.
  MediaItem toMediaItem();

  /// Converts the content to map.
  Map<String, dynamic> toMap();

  /// An icon for this content type.
  IconData get icon => type.icon;

  /// Whether the content was marked as favorite by the user.
  bool get isFavorite => FavoritesControl.instance.isFavorite(this);
}

/// Content that can contain other songs inside it.
///
/// This class represents not duplicating, a.k.a. `true source` song origins.
/// For origins to allow duplication, see a protocol in [DuplicatingSongOriginMixin].
///
/// The [songs] getter must set the [Song.origin]s.
///
/// Examples:
///  * [Album]
///  * [Artist]
abstract class SongOrigin extends Content {
  const SongOrigin();

  /// List of songs.
  List<Song> get songs;

  /// Length of the queue.
  int get length;

  /// Used to serialize the origin.
  SongOriginEntry toSongOriginEntry();

  /// Creates origin from map.
  static SongOrigin? originFromEntry(SongOriginEntry? entry) {
    if (entry == null) {
      return null;
    }
    switch (entry.type) {
      case SongOriginType.album:
        return ContentControl.instance.getContentById(entry.id, ContentType.album);
      case SongOriginType.playlist:
        return ContentControl.instance.getContentById(entry.id, ContentType.playlist);
      case SongOriginType.artist:
        return ContentControl.instance.getContentById(entry.id, ContentType.artist);
      default:
        throw UnimplementedError();
    }
  }
}

/// Song origin that allows duplication within the [songs].
///
/// Classes that are mixed in with this should in [songs] getter:
/// * set the [Song.origin]
/// * set a [Song.duplicationIndex]
/// * create, fill and set a [Song.idMap]
/// * call [debugAssertSongsAreValid] at the end of the getter, to check
///   that everything is set correctly.
///
/// Examples:
///  * [Playlist]
mixin DuplicatingSongOriginMixin on SongOrigin {
  /// Must be created and filled automatically each time the [songs] is called.
  IdMap? get idMap;

  /// Ensures that [idMap] is initialized and received [Song.idMap]
  /// and the [Song.origin].
  bool debugAssertSongsAreValid(List<Song> songs) {
    // Check that new valid idMap is created.
    // ignore: unused_local_variable
    final value = idMap;

    for (final song in songs) {
      if (song.origin != this || song.idMap != idMap) {
        return false;
      }
    }
    return true;
  }
}

/// Model used to serialize song origin type.
class SongOriginType {
  const SongOriginType._(this._value);
  final String _value;

  static const album = SongOriginType._('album');
  static const playlist = SongOriginType._('playlist');
  static const artist = SongOriginType._('artist');

  static List<SongOriginType> get values => const [
        album,
        playlist,
        artist,
      ];
}

/// Model used to serialize song origin.
@immutable
class SongOriginEntry {
  const SongOriginEntry({
    required this.type,
    required this.id,
  });

  final SongOriginType type;
  final int id;

  /// Will return null if map is not valid.
  static SongOriginEntry? fromMap(Map map) {
    final rawType = map['origin_type'];
    if (rawType == null) {
      return null;
    }
    final id = map['origin_id'];
    assert(id != null);
    return SongOriginEntry(
      type: SongOriginType.values.firstWhere((el) => el._value == rawType),
      id: id,
    );
  }

  Map<String, dynamic> toMap() => {
        'origin_type': type._value,
        'origin_id': id,
      };

  @override
  int get hashCode => Object.hash(type, id);

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is SongOriginEntry && other.type == type && other.id == id;
  }
}

/// See [ContentUtils.deduplicateSong].
typedef IdMap = Map<IdMapKey, int>;

/// The key used in [IdMap]s.
@immutable
class IdMapKey {
  const IdMapKey({
    required this.id,
    required this.originEntry,
  }) : assert(id < 0);

  /// The id of song, this map key is associated with.
  /// Must be negative per the ID map rules.
  final int id;

  /// The origin entry of song, this map key is associated with.
  final SongOriginEntry? originEntry;

  /// Will return null if map is not valid.
  static IdMapKey? fromMap(Map map) {
    final id = map['id'];
    if (id == null) {
      return null;
    }
    SongOriginEntry? originEntry;
    if (map.length > 1) {
      final rawOriginEntry = map['origin'];
      if (rawOriginEntry != null) {
        originEntry = SongOriginEntry.fromMap(rawOriginEntry);
      }
    }
    return IdMapKey(
      id: id,
      originEntry: originEntry,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        if (originEntry != null) 'origin': originEntry!.toMap(),
      };

  @override
  int get hashCode => Object.hash(id, originEntry);

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is IdMapKey && other.id == id && other.originEntry == originEntry;
  }
}
