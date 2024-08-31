import 'package:audio_service/audio_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:sweyer/sweyer.dart';
import 'package:sweyer_plugin/sweyer_plugin.dart';

class Artist extends SongOrigin implements PlatformArtist {
  @override
  ContentType get type => ContentType.artist;

  @override
  final int id;
  final String artist;
  final int numberOfAlbums;
  final int numberOfTracks;

  @override
  List<Object> get props => [id];

  @override
  String get title => artist;

  /// Returns songs for this artist.
  @override
  List<Song> get songs {
    return ContentControl.instance.state.allSongs.songs.fold<List<Song>>([], (prev, el) {
      if (el.artistId == id) {
        prev.add(el.copyWith(origin: this));
      }
      return prev;
    }).toList();
  }

  @override
  int get length => numberOfTracks;

  /// Returns albums for this artist.
  List<Album> get albums {
    return ContentControl.instance.state.albums.values.where((el) => el.artistId == id).toList();
  }

  /// Whether this artist represents an unknown artist.
  bool get isUnknown => artist == ContentUtils.unknownArtist;

  Future<GetArtistInfoResponse> fetchInfo() => Backend.instance.getArtistInfo(artist);

  const Artist({
    required this.id,
    required this.artist,
    required this.numberOfAlbums,
    required this.numberOfTracks,
  });

  @override
  ArtistCopyWith get copyWith => _ArtistCopyWith(this);

  @override
  MediaItem toMediaItem() {
    return MediaItem(
      id: id.toString(),
      album: null,
      defaultArtBlendColor: staticTheme.appThemeExtension.artColorForBlend.value,
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
      type: SongOriginType.artist,
      id: id,
    );
  }

  static Artist? fromMap(Map<String, dynamic> map) {
    try {
      return Artist(
        id: map['id'] as int,
        artist: map['artist'] as String,
        numberOfAlbums: map['numberOfAlbums'] as int,
        numberOfTracks: map['numberOfTracks'] as int,
      );
    } on TypeError catch (error, stack) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: 'trying to parse an artist',
        fatal: false,
      );
      return null;
    }
  }

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'artist': artist,
        'numberOfAlbums': numberOfAlbums,
        'numberOfTracks': numberOfTracks,
      };
}

/// The `copyWith` function type for [Artist].
abstract class ArtistCopyWith {
  Artist call({
    int id,
    String artist,
    int numberOfAlbums,
    int numberOfTracks,
  });
}

/// The implementation of [Artist]'s `copyWith` function allowing
/// parameters to be explicitly set to null.
class _ArtistCopyWith extends ArtistCopyWith {
  static const _undefined = Object();

  /// The object this function applies to.
  final Artist value;

  _ArtistCopyWith(this.value);

  @override
  Artist call({
    Object id = _undefined,
    Object artist = _undefined,
    Object numberOfAlbums = _undefined,
    Object numberOfTracks = _undefined,
  }) {
    return Artist(
      id: id == _undefined ? value.id : id as int,
      artist: artist == _undefined ? value.artist : artist as String,
      numberOfAlbums: numberOfAlbums == _undefined ? value.numberOfAlbums : numberOfAlbums as int,
      numberOfTracks: numberOfTracks == _undefined ? value.numberOfTracks : numberOfTracks as int,
    );
  }
}
