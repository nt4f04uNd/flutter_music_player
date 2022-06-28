import 'dart:typed_data';
import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:sweyer_plugin/sweyer_plugin_method_channel.dart';
import 'package:uuid/uuid.dart';

import 'sweyer_plugin_platform_interface.dart';

abstract class MediaStoreSong {
  int get sourceId;

  Map<String, dynamic> toMap();
}

abstract class MediaStoreAlbum {}

abstract class MediaStoreArtist {}

abstract class MediaStorePlaylist {
  int get id;
  List<int> get songIds;
}

abstract class MediaStoreGenre {}

abstract class SweyerPluginException with EquatableMixin {
  const SweyerPluginException();
  String get value;

  @override
  List<Object?> get props => [value];

  /// Generic error.
  static const unexpected = SweyerMethodChannelException.unexpected;

  /// On Android 30 requests like `MediaStore.createDeletionRequest` require
  /// calling `startIntentSenderForResult`, which might throw this exception.
  static const intentSender = SweyerMethodChannelException.intentSender;

  static const io = SweyerMethodChannelException.io;

  /// API is unavailable on current SDK level.
  static const sdk = SweyerMethodChannelException.sdk;

  /// Operation cannot be performed because there's no such playlist.
  static const playlistNotExists = SweyerMethodChannelException.playlistNotExists;
}

const _uuid = Uuid();

/// Class to cancel the [ContentChannel.loadAlbumArt].
class CancellationSignal {
  CancellationSignal() : _id = _uuid.v4();
  final String _id;

  /// Cancel loading of an album art.
  Future<void> cancel() => SweyerPluginPlatform.instance.cancelAlbumArtLoad(id: _id);
}

abstract class SweyerPlugin {
  static Future<Uint8List?> loadAlbumArt({
    required String uri,
    required Size size,
    required CancellationSignal signal,
  }) async =>
      await SweyerPluginPlatform.instance.loadAlbumArt(uri: uri, size: size, cancellationSignalId: signal._id);

  /// Tries to tell system to recreate album art by [albumId].
  ///
  /// Sometimes `MediaStore` tells that there's an album art for some song, but the actual file
  /// by some path doesn't exist. Supposedly, what happens is that Android detects reads on this
  /// entry from something like `InputStream` in Java and regenerates album thumbs if they do not exist
  /// (because this is just a caches that system tends to clear out if it thinks it should),
  /// but (yet again, supposedly) this is not the case when Flutter accesses this file. System cannot
  /// detect it and does not recreate the thumb, so we do this instead.
  ///
  /// See https://stackoverflow.com/questions/18606007/android-image-files-deleted-from-com-android-providers-media-albumthumbs-on-rebo
  static Future<void> fixAlbumArt(int albumId) async => await SweyerPluginPlatform.instance.fixAlbumArt(albumId);

  static Future<Iterable<T>> retrieveSongs<T extends MediaStoreSong>(
    T Function(Map<String, dynamic> data) factory,
  ) async =>
      (await SweyerPluginPlatform.instance.retrieveSongs()).map(factory);

  static Future<Map<int, T>> retrieveAlbums<T extends MediaStoreAlbum>(
    T Function(Map<String, dynamic> data) factory,
  ) async {
    final maps = await SweyerPluginPlatform.instance.retrieveAlbums();
    final Map<int, T> albums = {};
    for (final map in maps) {
      albums[map['id'] as int] = factory(map);
    }
    return albums;
  }

  static Future<Iterable<T>> retrievePlaylists<T extends MediaStorePlaylist>(
    T Function(Map<String, dynamic> data) factory,
  ) async =>
      (await SweyerPluginPlatform.instance.retrievePlaylists()).map(factory);

  static Future<Iterable<T>> retrieveArtists<T extends MediaStoreArtist>(
    T Function(Map<String, dynamic> data) factory,
  ) async =>
      (await SweyerPluginPlatform.instance.retrieveArtists()).map(factory);

  static Future<Iterable<T>> retrieveGenres<T extends MediaStoreGenre>(
    T Function(Map<String, dynamic> data) factory,
  ) async =>
      (await SweyerPluginPlatform.instance.retrieveGenres()).map(factory);

  /// Sets songs' favorite flag to [value].
  ///
  /// The returned value indicates the success of the operation.
  ///
  /// Throws:
  ///  * [SweyerMethodChannelException.sdk] when it's called below Android 30
  ///  * [SweyerMethodChannelException.intentSender]
  static Future<bool> setSongsFavorite(Set<MediaStoreSong> songs, bool value) =>
      SweyerPluginPlatform.instance.setSongsFavorite(songs.map((song) => song.sourceId).toList(), value);

  /// Deletes a set of songs.
  ///
  /// The returned value indicates the success of the operation.
  ///
  /// Throws:
  ///  * [SweyerMethodChannelException.intentSender]
  static Future<bool> deleteSongs(Set<MediaStoreSong> songs) =>
      SweyerPluginPlatform.instance.deleteSongs(songs.map((song) => song.toMap()).toList());

  static Future<void> createPlaylist(String name) => SweyerPluginPlatform.instance.createPlaylist(name);

  /// Throws:
  ///  * [SweyerMethodChannelException.playlistNotExists] when playlist doesn't exist.
  static Future<void> renamePlaylist(MediaStorePlaylist playlist, String name) =>
      SweyerPluginPlatform.instance.renamePlaylist(playlist.id, name);

  static Future<void> removePlaylists(List<MediaStorePlaylist> playlists) =>
      SweyerPluginPlatform.instance.removePlaylists(playlists.map((playlist) => playlist.id).toList());

  /// Throws:
  ///  * [SweyerMethodChannelException.playlistNotExists] when playlist doesn't exist.
  static Future<void> insertSongsInPlaylist({
    required int index,
    required List<MediaStoreSong> songs,
    required MediaStorePlaylist playlist,
  }) {
    assert(songs.isNotEmpty);
    assert(index >= 0 && index <= playlist.songIds.length + 1);
    return SweyerPluginPlatform.instance.insertSongsInPlaylist(
        index: index, songIds: songs.map((song) => song.sourceId).toList(), playlistId: playlist.id);
  }

  /// Moves song in playlist, returned value indicates whether the operation was successful.
  static Future<bool> moveSongInPlaylist({required MediaStorePlaylist playlist, required int from, required int to}) {
    assert(from >= 0);
    assert(to >= 0);
    assert(from != to);
    return SweyerPluginPlatform.instance.moveSongInPlaylist(playlistId: playlist.id, from: from, to: to);
  }

  /// Throws:
  ///  * [SweyerMethodChannelException.playlistNotExists] when playlist doesn't exist.
  static Future<void> removeFromPlaylistAt({required List<int> indexes, required MediaStorePlaylist playlist}) {
    assert(indexes.isNotEmpty);
    return SweyerPluginPlatform.instance.removeFromPlaylistAt(indexes: indexes, playlistId: playlist.id);
  }

  /// Checks if open intent is view (user tried to open file with app).
  static Future<bool> isIntentActionView() => SweyerPluginPlatform.instance.isIntentActionView();
}
