import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:sweyer_plugin/sweyer_plugin.dart';
import '../test.dart';

/// An Entry in the [FakeContentChannel.favoriteRequestLog].
class FavoriteLogEntry {
  /// The set of songs that were modified.
  final Set<Song> songs;

  /// `true` if a request was made to make the songs favorite, `false` if the request was made to unfavor them.
  final bool setFavorite;

  const FavoriteLogEntry(this.songs, this.setFavorite);

  @override
  String toString() => '${runtimeType.toString()}(songs=$songs, setFavorite=$setFavorite)';

  @override
  bool operator ==(Object other) =>
      other is FavoriteLogEntry && setFavorite == other.setFavorite && setEquals(songs, other.songs);

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(songs), setFavorite);
}

class FakeSweyerPluginPlatform extends SweyerPluginPlatform {
  FakeSweyerPluginPlatform(TestWidgetsFlutterBinding binding) {
    instance = this;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('content_channel'), (call) {
      /// Ignore [CancellationSignal] calls
      if (call.method == 'cancelAlbumArtLoading') {
        return null;
      }
      throw UnimplementedError('method is not mocked');
    });
  }
  static late FakeSweyerPluginPlatform instance;

  set songs(List<Song> value) => songsFactory = () => value.map((song) => song.toMap());
  Iterable<Map<String, dynamic>> Function() songsFactory = () => [songWith().toMap()];
  set albums(List<Album> value) => albumsFactory = () => value.map((album) => album.toMap());
  Iterable<Map<String, dynamic>> Function() albumsFactory = () => [albumWith().toMap()];
  set playlists(List<Playlist> value) => playlistsFactory = () => value.map((playlist) => playlist.toMap());
  Iterable<Map<String, dynamic>> Function() playlistsFactory = () => [playlistWith().toMap()];
  set artists(List<Artist> value) => artistsFactory = () => value.map((artist) => artist.toMap());
  Iterable<Map<String, dynamic>> Function() artistsFactory = () => [artistWith().toMap()];

  @override
  Future<void> createPlaylist(String name) async {}

  @override
  Future<bool> deleteSongs(List<Map<String, dynamic>> songs) async {
    return true;
  }

  @override
  Future<void> fixAlbumArt(int albumId) async {}

  @override
  Future<void> insertSongsInPlaylist({
    required int index,
    required List<int> songIds,
    required int playlistId,
  }) async {
    final playlists = playlistsFactory().toList();
    final playlist = playlists.firstWhere((playlist) => playlist['id'] == playlistId);
    (playlist.putIfAbsent('songIds', () => []) as List).insertAll(index, songIds);
    playlistsFactory = () => playlists;
  }

  @override
  Future<bool> isIntentActionView() async {
    return false;
  }

  @override
  Future<Uint8List?> loadAlbumArt({
    required String uri,
    required Size size,
    required String cancellationSignalId,
  }) async {
    return Uint8List.fromList(kBlueSquarePng);
  }

  @override
  Future<void> cancelAlbumArtLoad({required String id}) async {}

  @override
  Future<bool> moveSongInPlaylist({required int playlistId, required int from, required int to}) async {
    return true;
  }

  @override
  Future<void> removeFromPlaylistAt({required List<int> indexes, required int playlistId}) async {}

  @override
  Future<void> removePlaylists(List<int> playlistIds) async {}

  @override
  Future<void> renamePlaylist(int playlistId, String name) async {}

  @override
  Future<Iterable<Map<String, dynamic>>> retrieveAlbums() async {
    return albumsFactory();
  }

  @override
  Future<Iterable<Map<String, dynamic>>> retrieveArtists() async {
    return artistsFactory();
  }

  @override
  Future<Iterable<Map<String, dynamic>>> retrieveGenres() async {
    return [];
  }

  @override
  Future<Iterable<Map<String, dynamic>>> retrievePlaylists() async {
    return playlistsFactory();
  }

  @override
  Future<Iterable<Map<String, dynamic>>> retrieveSongs() async {
    return songsFactory();
  }

  /// The log of all recorded [setSongsFavorite] calls.
  List<FavoriteLogEntry> get favoriteRequestLog => UnmodifiableListView(_favoriteRequestLog);
  final List<FavoriteLogEntry> _favoriteRequestLog = [];

  @override
  Future<bool> setSongsFavorite(List<int> songIds, bool value) async {
    _favoriteRequestLog.add(FavoriteLogEntry(songIds.map((id) => _songById(id)!).toSet(), value));
    return true;
  }

  /// Get a song by its [id].
  Song? _songById(int id) => ContentControl.instance.state.allSongs.songs.firstWhere((song) => song.id == id);
}
