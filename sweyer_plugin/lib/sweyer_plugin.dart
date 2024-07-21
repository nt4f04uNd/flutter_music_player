import 'dart:typed_data';
import 'dart:ui';

import 'package:uuid/uuid.dart';

import 'sweyer_plugin_platform_interface.dart';

export 'sweyer_plugin_platform_interface.dart';

/// A song from the native platform.
abstract class PlatformSong {
  /// The id of this song in the native platform.
  int get sourceId;

  /// Absolute filesystem path to the media item on disk.
  String? get filesystemPath;
}

/// An album from the native platform.
abstract class PlatformAlbum {
  /// The id of this album in the native platform.
  int get id;
}

/// An artist from the native platform.
abstract class PlatformArtist {}

/// A playlist from the native platform.
abstract class PlatformPlaylist {
  /// The id of this playlist in the native platform.
  int get id;

  /// A list of ids of songs that this playlist contains.
  List<int> get songIds;
}

/// A genre from the native platform.
abstract class PlatformGenre {}

const _uuid = Uuid();

/// Class to cancel the [ContentChannel.loadAlbumArt].
class CancellationSignal {
  CancellationSignal() : _id = _uuid.v4();
  final String _id;

  /// Cancel loading of an album art.
  Future<void> cancel() => SweyerPluginPlatform.instance.cancelAlbumArtLoad(id: _id);
}

/// A factory to load an implementation from the raw data describing a platform item.
typedef DataFactory<T> = T? Function(Map<String, dynamic> data);

// TODO: Remove this extension once we switch to Dart3.
extension NullableIterableExtensions<T extends Object> on Iterable<T?> {
  /// The non-`null` elements of this iterable.
  ///
  /// The same elements as this iterable, except that `null` values are omitted.
  Iterable<T> get nonNulls sync* {
    for (final element in this) {
      if (element != null) {
        yield element;
      }
    }
  }
}

class SweyerPlugin {
  static const instance = SweyerPlugin();

  const SweyerPlugin();

  Future<Uint8List?> loadAlbumArt({
    required String uri,
    required Size size,
    required CancellationSignal signal,
  }) async =>
      await SweyerPluginPlatform.instance.loadAlbumArt(uri: uri, size: size, cancellationSignalId: signal._id);

  /// Tries to tell the system to recreate album art by [albumId].
  ///
  /// Sometimes `MediaStore` tells that there's an album art for some song, but the actual file
  /// by some path doesn't exist. Supposedly, what happens is that Android detects reads on this
  /// entry from something like `InputStream` in Java and regenerates album thumbs if they do not exist
  /// (because this is just a caches that system tends to clear out if it thinks it should),
  /// but (yet again, supposedly) this is not the case when Flutter accesses this file. System cannot
  /// detect it and does not recreate the thumb, so we do this instead.
  ///
  /// See https://stackoverflow.com/questions/18606007/android-image-files-deleted-from-com-android-providers-media-albumthumbs-on-rebo
  Future<void> fixAlbumArt(int albumId) async => await SweyerPluginPlatform.instance.fixAlbumArt(albumId);

  Future<Iterable<T>> retrieveSongs<T extends PlatformSong>(DataFactory<T> factory) async =>
      (await SweyerPluginPlatform.instance.retrieveSongs()).map(factory).nonNulls;

  Future<Map<int, T>> retrieveAlbums<T extends PlatformAlbum>(DataFactory<T> factory) async => Map.fromIterable(
        (await SweyerPluginPlatform.instance.retrieveAlbums()).map(factory).nonNulls,
        key: (album) => album.id,
      );

  Future<Iterable<T>> retrievePlaylists<T extends PlatformPlaylist>(DataFactory<T> factory) async =>
      (await SweyerPluginPlatform.instance.retrievePlaylists()).map(factory).nonNulls;

  Future<Iterable<T>> retrieveArtists<T extends PlatformArtist>(DataFactory<T> factory) async =>
      (await SweyerPluginPlatform.instance.retrieveArtists()).map(factory).nonNulls;

  Future<Iterable<T>> retrieveGenres<T extends PlatformGenre>(DataFactory<T> factory) async =>
      (await SweyerPluginPlatform.instance.retrieveGenres()).map(factory).nonNulls;

  /// Sets the songs favorite flag to [value].
  ///
  /// The returned value indicates the success of the operation.
  ///
  /// Throws:
  ///  * [SweyerPluginChannelException.sdk] when it's called below Android 30
  ///  * [SweyerPluginChannelException.intentSender]
  Future<bool> setSongsFavorite(Set<PlatformSong> songs, bool value) =>
      SweyerPluginPlatform.instance.setSongsFavorite(songs.map((song) => song.sourceId).toList(), value);

  /// Deletes a set of songs.
  ///
  /// The returned value indicates the success of the operation.
  ///
  /// Throws:
  ///  * [SweyerPluginChannelException.intentSender]
  Future<bool> deleteSongs(Set<PlatformSong> songs) => SweyerPluginPlatform.instance.deleteSongs(
      songs.map((song) => {'id': song.sourceId, 'filesystemPath': song.filesystemPath}).toList(growable: false));

  Future<void> createPlaylist(String name) => SweyerPluginPlatform.instance.createPlaylist(name);

  /// Throws:
  ///  * [SweyerPluginChannelException.playlistNotExists] when the playlist doesn't exist.
  Future<void> renamePlaylist(PlatformPlaylist playlist, String name) =>
      SweyerPluginPlatform.instance.renamePlaylist(playlist.id, name);

  Future<void> removePlaylists(List<PlatformPlaylist> playlists) =>
      SweyerPluginPlatform.instance.removePlaylists(playlists.map((playlist) => playlist.id).toList());

  /// Throws:
  ///  * [SweyerPluginChannelException.playlistNotExists] when the playlist doesn't exist.
  Future<void> insertSongsInPlaylist({
    required int index,
    required List<PlatformSong> songs,
    required PlatformPlaylist playlist,
  }) {
    assert(songs.isNotEmpty);
    assert(index >= 0 && index <= playlist.songIds.length);
    return SweyerPluginPlatform.instance.insertSongsInPlaylist(
      index: index,
      songIds: songs.map((song) => song.sourceId).toList(),
      playlistId: playlist.id,
    );
  }

  /// Moves the song at the index [from] in the [playlist] to the index [to].
  /// The returned value indicates whether the operation was successful.
  Future<bool> moveSongInPlaylist({required PlatformPlaylist playlist, required int from, required int to}) {
    assert(from >= 0);
    assert(to >= 0);
    assert(from != to);
    return SweyerPluginPlatform.instance.moveSongInPlaylist(playlistId: playlist.id, from: from, to: to);
  }

  /// Throws:
  ///  * [SweyerPluginChannelException.playlistNotExists] when the playlist doesn't exist.
  Future<void> removeFromPlaylistAt({required List<int> indexes, required PlatformPlaylist playlist}) {
    assert(indexes.isNotEmpty);
    return SweyerPluginPlatform.instance.removeFromPlaylistAt(indexes: indexes, playlistId: playlist.id);
  }

  /// Checks if the intent that started the app is a view intent
  /// (indicating that the user tried to open a file with app).
  Future<bool> isIntentActionView() => SweyerPluginPlatform.instance.isIntentActionView();
}
