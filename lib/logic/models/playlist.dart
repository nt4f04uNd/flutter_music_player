/*---------------------------------------------------------------------------------------------
*  Copyright (c) nt4f04und. All rights reserved.
*  Licensed under the BSD-style license. See LICENSE in the project root for license information.
*--------------------------------------------------------------------------------------------*/

import 'package:audio_service/audio_service.dart';
import 'package:sweyer/sweyer.dart';

class Playlist extends PersistentQueue {
  final String data;
  final int dateAdded;
  final int dateModified;
  final String name;
  final List<int> songIds;

  @override
  String get title => name;

  @override
  int get length => songIds.length;

  @override
  bool get playable => songIds.isNotEmpty;

  /// Created and filled automatically each time the [songs] is called.
  late Map<String, int> idMap;

  @override
  List<Song> get songs {
    idMap = {};
    final List<Song> found = [];
    final List<int> notFoundIndices = [];
    for (int i = 0; i < songIds.length; i++) {
      final song = ContentControl.state.allSongs.byId.get(songIds[i]);
      if (song != null) {
        final copiedSong = song.copyWith();
        copiedSong.idMap = idMap;
        found.add(copiedSong);
      } else {
        notFoundIndices.add(songIds[i]);
      }
    }
    for (final song in found) {
      ContentControl.deduplicateSong(
        song,
        inserted: true,
        source: found,
        idMap: idMap,
      );
    }
    for (int i = notFoundIndices.length - 1; i >= 0; i--) {
      songIds.remove(i);
    }
    return found;
  }

  /// Returns content URI of the first item in the album.
  String get firstSong {
    final song = ContentControl.state.allSongs.songs.firstWhere((el) => el.albumId == id);
    return song.contentUri;
  }

  Playlist({
    required int id,
    required this.data,
    required this.dateAdded,
    required this.dateModified,
    required this.name,
    required this.songIds,
  }) : super(id: id);

  @override
  PlaylistCopyWith get copyWith => _PlaylistCopyWith(this);

  @override
  MediaItem toMediaItem() {
    return MediaItem(
      id: id.toString(),
      album: null,
      defaultArtBlendColor: ThemeControl.colorForBlend.value,
      artUri: null,
      title: title,
      artist: null,
      genre: null,
      rating: null,
      extras: null,
      playable: false,
    );
  }

  @override
  SongOriginEntry toSongOriginEntry() {
    return SongOriginEntry(
      type: SongOriginType.playlist,
      id: id,
    );
  }

  factory Playlist.fromMap(Map map) {
    return Playlist(
      id: map['id'] as int,
      data: map['data'] as String,
      dateAdded: map['dateAdded'] as int,
      dateModified: map['dateModified'] as int,
      name: map['name'] as String,
      songIds: (map['songIds'] as List).cast<int>().toList(),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'data': data,
    'dateAdded': dateAdded,
    'dateModified': dateModified,
    'name': name,
    'songIds': songIds,
  };
}

/// The `copyWith` function type for [Playlist].
abstract class PlaylistCopyWith {
  Playlist call({
    int id,
    String data,
    int dateAdded,
    int dateModified,
    String name,
    List<int> songIds,
  });
}

/// The implementation of [Playlist]'s `copyWith` function allowing
/// parameters to be explicitly set to null.
class _PlaylistCopyWith extends PlaylistCopyWith {
  static const _undefined = Object();

  /// The object this function applies to.
  final Playlist value;

  _PlaylistCopyWith(this.value);

  @override
  Playlist call({
    Object id = _undefined,
    Object data = _undefined,
    Object dateAdded = _undefined,
    Object dateModified = _undefined,
    Object name = _undefined,
    Object songIds = _undefined,
  }) {
    return Playlist(
      id: id == _undefined ? value.id : id as int,
      data: data == _undefined ? value.data : data as String,
      dateAdded: dateAdded == _undefined ? value.dateAdded : dateAdded as int,
      dateModified: dateModified == _undefined ? value.dateModified : dateModified as int,
      name: name == _undefined ? value.name : name as String,
      songIds: songIds == _undefined ? value.songIds : songIds as List<int>,
    );
  }
}
