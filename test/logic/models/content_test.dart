import 'package:collection/collection.dart';

import '../../observer/observer.dart';
import '../../test.dart';

extension TestMap on Map<String, dynamic> {
  Map<String, dynamic> copyWith(Map<String, dynamic> overwrites) {
    return Map.of(this)..addAll(overwrites);
  }

  Map<String, dynamic> copyWithout(List<String> keysToRemove) {
    var map = Map.of(this);
    keysToRemove.forEach(map.remove);
    return map;
  }

  Iterable<Map<String, dynamic>> subSets() sync* {
    var subSets = [[]];
    yield {};
    for (final key in keys) {
      for (var subSet in subSets.toList()) {
        var newSubSet = subSet + [key];
        if (newSubSet.length >= keys.length) {
          continue;
        }
        yield Map.fromEntries(entries.where((entry) => newSubSet.contains(entry.key)));
        subSets.add(newSubSet);
      }
    }
  }

  Iterable<Map<String, dynamic>> withWrongTypes() sync* {
    Iterable<dynamic> createVariations<T>(T value) sync* {
      yield value;
      yield [value];
      yield {value};
      yield {value: null};
      yield {null: value};
      yield {value: true};
      yield {true: value};
      yield {value: 0};
      yield {0: value};
      yield {value: double.nan};
      yield {double.nan: value};
      yield {value: ""};
      yield {"": value};
    }

    final wrongTypeValues = [
      ...createVariations(null),
      ...createVariations(true),
      ...createVariations(0),
      ...createVariations(double.nan),
      ...createVariations(""),
    ];
    for (final key in keys) {
      for (final wrongTypeValue in wrongTypeValues) {
        if (this[key].runtimeType != wrongTypeValue.runtimeType) {
          yield Map.of(this)..[key] = wrongTypeValue;
        }
      }
    }
  }
}

extension TestListMap on List<Map<String, dynamic>> {
  List<Map<String, dynamic>> assignUniqueIds({required int startId}) {
    for (var element in this) {
      if (element['id'] is int) {
        element['id'] = startId++;
      }
    }
    return this;
  }
}

extension StringIterable on Iterable<String> {
  bool containsAll(List<String> elements) => elements.every(this.contains);
}

void main() {
  group('Handles invalid or incomplete values from the media store', () {
    test('Handles invalid or incomplete albums', () async {
      final validAlbum = albumWith().toMap();
      final validAlbums = [
        (validAlbum.copyWith({'id': 1}), albumWith(id: 1)),
        (validAlbum.copyWith({'id': 2, 'album': ''}), albumWith(id: 2, album: '')),
        (validAlbum.copyWith({'id': 3, 'albumArt': ''}), albumWith(id: 3, albumArt: '')),
        (validAlbum.copyWith({'id': 4, 'albumArt': null}), albumWith(id: 4, albumArt: null)),
        (validAlbum.copyWith({'id': 5}).copyWithout(['albumArt']), albumWith(id: 5, albumArt: null)),
        (validAlbum.copyWith({'id': 6, 'artist': ''}), albumWith(id: 6, artist: '')),
        (validAlbum.copyWith({'id': 7, 'artistId': -1}), albumWith(id: 7, artistId: -1)),
        (validAlbum.copyWith({'id': 8, 'artistId': null}), albumWith(id: 8, artistId: null)),
        (validAlbum.copyWith({'id': 9}).copyWithout(['artistId']), albumWith(id: 9, artistId: null)),
        (validAlbum.copyWith({'id': 10, 'firstYear': -1}), albumWith(id: 10, firstYear: -1)),
        (validAlbum.copyWith({'id': 11, 'firstYear': null}), albumWith(id: 11, firstYear: null)),
        (validAlbum.copyWith({'id': 12}).copyWithout(['firstYear']), albumWith(id: 12, firstYear: null)),
        (validAlbum.copyWith({'id': 13, 'lastYear': -1}), albumWith(id: 13, lastYear: -1)),
        (validAlbum.copyWith({'id': 14, 'lastYear': null}), albumWith(id: 14, lastYear: null)),
        (validAlbum.copyWith({'id': 15}).copyWithout(['lastYear']), albumWith(id: 15, lastYear: null)),
        (validAlbum.copyWith({'id': 16, 'numberOfSongs': -1}), albumWith(id: 16, numberOfSongs: -1)),
        (
          validAlbum.copyWith({'id': 17, 'lastYear': 2000, 'firstYear': 3000}), // Last year before first year
          albumWith(id: 17, lastYear: 2000, firstYear: 3000),
        ),
      ];
      final invalidAlbums = [
        ...validAlbum.copyWithout(['albumArt', 'artistId', 'firstYear', 'lastYear']).subSets(),
        ...validAlbum.withWrongTypes().whereNot(
              (map) =>
                  map['albumArt'] == null ||
                  map['artistId'] == null ||
                  map['firstYear'] == null ||
                  map['lastYear'] == null,
            ),
      ].assignUniqueIds(startId: validAlbums.last.$1['id'] + 1);
      late CrashlyticsObserver crashlyticsObserver;
      await setUpAppTest(() {
        crashlyticsObserver = CrashlyticsObserver(TestWidgetsFlutterBinding.ensureInitialized());
        FakeSweyerPluginPlatform.instance.rawAlbums = validAlbums.map((element) => element.$1).toList()
          ..addAll(invalidAlbums);
      });
      expect(
        ContentControl.instance.state.albums.values.sorted((item1, item2) => item1.id.compareTo(item2.id)),
        validAlbums.map((element) => element.$2).toList(),
      );
      expect(crashlyticsObserver.nonFatalErrorCount, 523);
    });

    test('Handles invalid or incomplete artists', () async {
      final validArtist = artistWith().toMap();
      final validArtists = [
        (validArtist.copyWith({'id': 1}), artistWith(id: 1)),
        (validArtist.copyWith({'id': 2, 'artist': ''}), artistWith(id: 2, artist: '')),
        (validArtist.copyWith({'id': 3, 'numberOfAlbums': -1}), artistWith(id: 3, numberOfAlbums: -1)),
        (validArtist.copyWith({'id': 4, 'numberOfTracks': -1}), artistWith(id: 4, numberOfTracks: -1)),
        (
          validArtist.copyWith({'id': 5, 'numberOfAlbums': 1, 'numberOfTracks': 0}), // No track but one album
          artistWith(id: 5, numberOfAlbums: 1, numberOfTracks: 0),
        ),
      ];
      final invalidArtists = [
        ...validArtist.subSets(),
        ...validArtist.withWrongTypes(),
      ].assignUniqueIds(startId: validArtists.last.$1['id'] + 1);
      late CrashlyticsObserver crashlyticsObserver;
      await setUpAppTest(() {
        crashlyticsObserver = CrashlyticsObserver(TestWidgetsFlutterBinding.ensureInitialized());
        FakeSweyerPluginPlatform.instance.rawArtists = validArtists.map((element) => element.$1).toList()
          ..addAll(invalidArtists);
      });
      expect(
        ContentControl.instance.state.artists.sorted((item1, item2) => item1.id.compareTo(item2.id)),
        validArtists.map((element) => element.$2).toList(),
      );
      expect(crashlyticsObserver.nonFatalErrorCount, 271);
    });

    test('Handles invalid or incomplete playlists', () async {
      final validPlaylist = playlistWith().toMap();
      final validPlaylists = [
        (validPlaylist.copyWith({'id': 1}), playlistWith(id: 1)),
        (validPlaylist.copyWith({'id': 2, 'filesystemPath': ''}), playlistWith(id: 2, fileSystemPath: '')),
        (validPlaylist.copyWith({'id': 3, 'dateAdded': -1}), playlistWith(id: 3, dateAdded: -1)),
        (validPlaylist.copyWith({'id': 4, 'dateModified': -1}), playlistWith(id: 4, dateModified: -1)),
        (validPlaylist.copyWith({'id': 5, 'name': ''}), playlistWith(id: 5, name: '')),
        (validPlaylist.copyWith({'id': 6, 'songIds': []}), playlistWith(id: 6, songIds: [])),
        (
          validPlaylist.copyWith({'id': 7, 'dateAdded': 42, 'dateModified': null}),
          playlistWith(id: 7, dateAdded: 42, dateModified: 42),
        ),
        (
          validPlaylist.copyWith({'id': 8, 'dateAdded': 42}).copyWithout(['dateModified']),
          playlistWith(id: 8, dateAdded: 42, dateModified: 42),
        ),
        (
          validPlaylist.copyWith({
            'id': 9,
            'songIds': [-1], // Invalid song id.
          }),
          playlistWith(id: 9, songIds: [-1]),
        ),
      ];
      final invalidPlaylists = [
        ...validPlaylist.subSets().whereNot((map) => [
              {'id', 'filesystemPath', 'dateAdded', 'name', 'songIds'},
            ].any((keys) => const SetEquality().equals(keys, map.keys.toSet()))),
        ...validPlaylist.withWrongTypes().whereNot((map) => map['dateModified'] == null || map['songIds'] == []),
        validPlaylist.copyWith({'dateAdded': null, 'dateModified': null}),
      ].assignUniqueIds(startId: validPlaylists.last.$1['id'] + 1);
      late CrashlyticsObserver crashlyticsObserver;
      await setUpAppTest(() {
        crashlyticsObserver = CrashlyticsObserver(TestWidgetsFlutterBinding.ensureInitialized());
        FakeSweyerPluginPlatform.instance.rawPlaylists = validPlaylists.map((element) => element.$1).toList()
          ..addAll(invalidPlaylists);
      });
      expect(
        ContentControl.instance.state.playlists.sorted((item1, item2) => item1.id.compareTo(item2.id)),
        validPlaylists.map((element) => element.$2).toList(),
      );
      expect(crashlyticsObserver.nonFatalErrorCount, 446);
    });

    test('Handles invalid or incomplete songs', () async {
      final validSong = songWith().toMap();
      final validSongs = [
        (validSong.copyWith({'id': 1}), songWith(id: 1)),
        (validSong.copyWith({'id': 2, 'album': ''}), songWith(id: 2, album: '')),
        (validSong.copyWith({'id': 3, 'album': null}), songWith(id: 3, album: null)),
        (validSong.copyWith({'id': 4}).copyWithout(['album']), songWith(id: 4, album: null)),
        (validSong.copyWith({'id': 5, 'albumId': -1}), songWith(id: 5, albumId: -1)),
        (validSong.copyWith({'id': 6, 'albumId': null}), songWith(id: 6, albumId: null)),
        (validSong.copyWith({'id': 7}).copyWithout(['albumId']), songWith(id: 7, albumId: null)),
        (validSong.copyWith({'id': 8, 'artist': ''}), songWith(id: 8, artist: '')),
        (validSong.copyWith({'id': 9, 'artistId': -1}), songWith(id: 9, artistId: -1)),
        (validSong.copyWith({'id': 10, 'genre': ''}), songWith(id: 10, genre: '')),
        (validSong.copyWith({'id': 11, 'genre': null}), songWith(id: 11, genre: null)),
        (validSong.copyWith({'id': 12}).copyWithout(['genre']), songWith(id: 12, genre: null)),
        (validSong.copyWith({'id': 13, 'genreId': -1}), songWith(id: 13, genreId: -1)),
        (validSong.copyWith({'id': 14, 'genreId': null}), songWith(id: 14, genreId: null)),
        (validSong.copyWith({'id': 15}).copyWithout(['genreId']), songWith(id: 15, genreId: null)),
        (validSong.copyWith({'id': 16, 'title': ''}), songWith(id: 16, title: '')),
        (validSong.copyWith({'id': 17, 'track': ''}), songWith(id: 17, track: '')),
        (validSong.copyWith({'id': 18, 'track': null}), songWith(id: 18, track: null)),
        (validSong.copyWith({'id': 19}).copyWithout(['track']), songWith(id: 19, track: null)),
        (validSong.copyWith({'id': 20, 'dateAdded': -1}), songWith(id: 20, dateAdded: -1)),
        (validSong.copyWith({'id': 21, 'dateModified': -1}), songWith(id: 21, dateModified: -1)),
        (validSong.copyWith({'id': 22, 'duration': -1}), songWith(id: 22, duration: -1)),
        (validSong.copyWith({'id': 23, 'size': -1}), songWith(id: 23, size: -1)),
        (validSong.copyWith({'id': 24, 'filesystemPath': ''}), songWith(id: 24, filesystemPath: '')),
        (validSong.copyWith({'id': 25, 'filesystemPath': null}), songWith(id: 25, filesystemPath: null)),
        (validSong.copyWith({'id': 26}).copyWithout(['filesystemPath']), songWith(id: 26, filesystemPath: null)),
        (
          validSong.copyWith({'id': 27, 'isFavoriteInMediaStore': null}),
          songWith(id: 27, isFavoriteInMediaStore: false),
        ),
        (
          validSong.copyWith({'id': 28}).copyWithout(['isFavoriteInMediaStore']),
          songWith(id: 28, isFavoriteInMediaStore: false),
        ),
        (validSong.copyWith({'id': 29, 'generationAdded': -1}), songWith(id: 29, generationAdded: -1)),
        (validSong.copyWith({'id': 30, 'generationAdded': null}), songWith(id: 30, generationAdded: null)),
        (validSong.copyWith({'id': 31}).copyWithout(['generationAdded']), songWith(id: 31, generationAdded: null)),
        (validSong.copyWith({'id': 32, 'generationModified': -1}), songWith(id: 32, generationModified: -1)),
        (validSong.copyWith({'id': 33, 'generationModified': null}), songWith(id: 33, generationModified: null)),
        (
          validSong.copyWith({'id': 34}).copyWithout(['generationModified']),
          songWith(id: 34, generationModified: null),
        ),
      ];
      final invalidSongs = [
        ...validSong.copyWithout([
          'album',
          'albumId',
          'genre',
          'genreId',
          'track',
          'filesystemPath',
          'isFavoriteInMediaStore',
          'generationAdded',
          'generationModified',
        ]).subSets(),
        ...validSong.withWrongTypes().whereNot(
              (map) =>
                  map['album'] == null ||
                  map['albumId'] == null ||
                  map['genre'] == null ||
                  map['genreId'] == null ||
                  map['track'] == null ||
                  map['filesystemPath'] == null ||
                  map['isFavoriteInMediaStore'] == null ||
                  map['generationAdded'] == null ||
                  map['generationModified'] == null,
            ),
      ].assignUniqueIds(startId: validSongs.last.$1['id'] + 1);
      late CrashlyticsObserver crashlyticsObserver;
      await setUpAppTest(() {
        crashlyticsObserver = CrashlyticsObserver(TestWidgetsFlutterBinding.ensureInitialized());
        FakeSweyerPluginPlatform.instance.rawSongs = validSongs.map((element) => element.$1).toList()
          ..addAll(invalidSongs);
      });
      expect(
        ContentControl.instance.state.allSongs.songs.sorted((item1, item2) => item1.id.compareTo(item2.id)),
        validSongs.map((element) => element.$2).toList(),
      );
      expect(crashlyticsObserver.nonFatalErrorCount, 1334);
    });
  });
}
