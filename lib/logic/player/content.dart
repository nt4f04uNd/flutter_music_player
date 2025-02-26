import 'dart:async';

import 'package:collection/collection.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
// import 'package:quick_actions/quick_actions.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sweyer/sweyer.dart';
import 'package:sweyer_plugin/sweyer_plugin.dart';

// See content logic overview here
// https://docs.google.com/document/d/1QtF9koBcWuRE1lIYJ45cRMogAprb7xD83ImmI0cn3lQ/edit
// TODO: update it

enum QuickAction {
  search,
  shuffleAll,
  playRecent,
}

/// A [Map] container for the [ContentType] as key, and [V] as value entry.
class ContentMap<V> {
  /// The value for [ContentType.song].
  V songValue;

  /// The value for [ContentType.album].
  V albumValue;

  /// The value for [ContentType.playlist].
  V playlistValue;

  /// The value for [ContentType.artist].
  V artistValue;

  ContentMap({
    required this.songValue,
    required this.albumValue,
    required this.playlistValue,
    required this.artistValue,
  });

  /// Create a content map and initialize it with the values returned by the [factory],
  /// which will be called once with each [ContentType].
  factory ContentMap.fromFactory(V Function(ContentType contentType) factory) {
    return ContentMap(
      songValue: factory(ContentType.song),
      albumValue: factory(ContentType.album),
      playlistValue: factory(ContentType.playlist),
      artistValue: factory(ContentType.artist),
    );
  }

  /// Map values.
  Iterable<V> get values => ContentType.values.map((type) => get(type));

  /// Map entries.
  Iterable<MapEntry<ContentType, V>> get entries => ContentType.values.map((type) => MapEntry(type, get(type)));

  /// Returns the value for the [type] from the map.
  V get(ContentType type) {
    switch (type) {
      case ContentType.song:
        return songValue;
      case ContentType.album:
        return albumValue;
      case ContentType.playlist:
        return playlistValue;
      case ContentType.artist:
        return artistValue;
    }
  }

  /// Puts a [value] for the [key] into the map.
  void set(V value, {required ContentType key}) {
    switch (key) {
      case ContentType.song:
        songValue = value;
        break;
      case ContentType.album:
        albumValue = value;
        break;
      case ContentType.playlist:
        playlistValue = value;
        break;
      case ContentType.artist:
        artistValue = value;
        break;
    }
  }
}

/// A container for list of all content types.
///
/// This is like a [ContentMap] that contains lists and
/// always guarantees to have a value in it for given content type.
class ContentTuple {
  final List<Song> songs;
  final List<Album> albums;
  final List<Playlist> playlists;
  final List<Artist> artists;

  const ContentTuple({
    this.songs = const [],
    this.albums = const [],
    this.playlists = const [],
    this.artists = const [],
  });

  /// Get the list corresponding to the [type].
  List<T> get<T extends Content>(ContentType<T> type) {
    switch (type as ContentType) {
      case ContentType.song:
        return songs as List<T>;
      case ContentType.album:
        return albums as List<T>;
      case ContentType.playlist:
        return playlists as List<T>;
      case ContentType.artist:
        return artists as List<T>;
    }
  }

  /// Get a merged list of all lists for all content types.
  List<Content> get merged => [for (final contentType in ContentType.values) ...get(contentType)];

  /// Whether there is any content in this tuple.
  bool get notEmpty => ContentType.values.any((contentType) => get(contentType).isNotEmpty);

  /// Whether there is no content in this tuple.
  bool get empty => !notEmpty;

  /// Test whether the [test] function evaluates to `true` for any of the content in this tuple.
  bool any(bool Function(Content element) test) {
    for (final contentType in ContentType.values) {
      for (final content in get(contentType)) {
        if (test(content)) {
          return true;
        }
      }
    }
    return false;
  }
}

/// Represents the state in [ContentControl].
@visibleForTesting
class ContentState {
  /// All songs in the application.
  /// This list not should be modified in any way, except for sorting.
  Queue allSongs = Queue([]);
  Map<int, Album> albums = {};
  List<Playlist> playlists = [];
  List<Artist> artists = [];

  /// Contains various [Sort]s of the application.
  /// Sorts of specific [Queues] like [Album]s are stored separately. // TODO: this is currently not implemented - remove this todo when it will be
  ///
  /// Restored in [ContentControl._restoreSorts].
  late final ContentMap<Sort> sorts;
}

@visibleForTesting
class ContentRepository {
  final songSort = Prefs.songSort;
  final albumSort = Prefs.albumSort;
  final playlistSort = Prefs.playlistSort;
  final artistSort = Prefs.artistSort;
}

// class _WidgetsBindingObserver extends WidgetsBindingObserver {
//   @override
//   void didChangeLocales(List<Locale>? locales) {
//     ContentControl._setQuickActions();
//   }
// }

/// Controls content state and allows to perform related actions, for example:
///
/// * fetch songs
/// * search
/// * sort
/// * create playlist
/// * delete songs
/// * etc.
///
class ContentControl extends Control {
  static ContentControl instance = ContentControl();

  @visibleForTesting
  late final repository = ContentRepository();

  ContentState get state => _state!;
  ContentState? _state;
  ContentState? get stateNullable => _state;
  bool get _empty => stateNullable?.allSongs.isEmpty ?? true;

  /// A stream of changes over content.
  /// Called whenever [Content] (queues, songs, albums, etc. changes).
  Stream<void> get onContentChange => _contentSubject.stream;
  late PublishSubject<void> _contentSubject;

  /// Notifies when active selection controller changes.
  /// Will receive null when selection closes.
  late ValueNotifier<ContentSelectionController?> selectionNotifier;

  /// Emit event to [onContentChange].
  void emitContentChange() {
    if (!disposed.value) {
      _contentSubject.add(null);
    }
  }

  // /// Recently pressed quick action.
  // final quickAction = BehaviorSubject<QuickAction>();
  // final QuickActions _quickActions = QuickActions();
  // final bindingObserver = _WidgetsBindingObserver();

  /// Represents songs fetch on app start.
  bool get initializing => _initializeCompleter != null;
  Completer<void>? _initializeCompleter;

  /// The main data app initialization function, initializes all queues.
  /// Also handles no-permissions situations.
  @override
  Future<void> init() async {
    super.init();
    if (stateNullable == null) {
      _state = ContentState();
      _contentSubject = PublishSubject();
      selectionNotifier = ValueNotifier(null);
    }
    if (Permissions.instance.granted) {
      // TODO: prevent initializing if already initialized
      _initializeCompleter = Completer();
      emitContentChange(); // update UI to show "Searching songs" screen
      _restoreSorts();
      await Future.any([
        _initializeCompleter!.future,
        Future.wait([
          for (final contentType in ContentType.values)
            refetch(contentType, updateQueues: false, emitChangeEvent: false),
        ]),
      ]);
      if (!_empty && _initializeCompleter != null && !_initializeCompleter!.isCompleted) {
        // _initQuickActions();
        await QueueControl.instance.init();
        PlaybackControl.instance.init();
        await MusicPlayer.instance.init();
        await FavoritesControl.instance.init();
        PlayerInterfaceColorStyleControl.instance.init();
        AppWidgetControl.instance.init();
      }
      _initializeCompleter = null;
    }
    // Emit event to track change stream
    emitContentChange();
  }

  /// Disposes the [state] and stops the currently going [init] process,
  /// if any.
  @override
  void dispose() {
    if (!disposed.value) {
      // WidgetsBinding.instance!.removeObserver(bindingObserver);
      // _quickActions.clearShortcutItems();
      _initializeCompleter?.complete();
      _initializeCompleter = null;
      // TODO: This might still deliver some pending events to listeners, see https://github.com/dart-lang/sdk/issues/45653
      _contentSubject.close();
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        selectionNotifier.dispose();
      });
      _state = null;
      QueueControl.instance.dispose();
      PlaybackControl.instance.dispose();
      MusicPlayer.instance.dispose();
      FavoritesControl.instance.dispose();
      PlayerInterfaceColorStyleControl.instance.dispose();
      AppWidgetControl.instance.dispose();
    }
    super.dispose();
  }

  /// Restores [sorts] from [Prefs].
  Future<void> _restoreSorts() async {
    state.sorts = ContentMap(
      songValue: repository.songSort.get(),
      albumValue: repository.albumSort.get(),
      playlistValue: repository.playlistSort.get(),
      artistValue: repository.artistSort.get(),
    );
  }

  // void _initQuickActions() {
  //   WidgetsBinding.instance!.addObserver(bindingObserver);
  //   _quickActions.initialize((stringAction) {
  //     final action = EnumToString.fromString(QuickAction.values, stringAction)!;
  //     quickAction.add(action);
  //     // switch (action) {
  //     //   case QuickAction.search:
  //     //     break;
  //     //   case QuickAction.shuffleAll:
  //     //     break;
  //     //   case QuickAction.playRecent:
  //     //     break;
  //     //   default:
  //     //     throw UnimplementedError();
  //     // }
  //   });
  //   _setQuickActions();
  // }

  // Future<void> _setQuickActions() {
  //   return _quickActions.setShortcutItems(<ShortcutItem>[
  //     ShortcutItem(type: QuickAction.search.value, localizedTitle: staticl10n.search, icon: 'round_search_white_36'),
  //     ShortcutItem(type: QuickAction.shuffleAll.value, localizedTitle: staticl10n.shuffleAll, icon: 'round_shuffle_white_36'),
  //     ShortcutItem(type: QuickAction.playRecent.value, localizedTitle: staticl10n.playRecent, icon: 'round_play_arrow_white_36')
  //   ]);
  // }

  /// Returns content of specified [contentType].
  List<T> getContent<T extends Content>(
    ContentType<T> contentType, {
    bool filterFavorite = false,
  }) {
    final List<T> contentList;
    switch (contentType as ContentType) {
      case ContentType.song:
        contentList = state.allSongs.songs as List<T>;
        break;
      case ContentType.album:
        contentList = state.albums.values.toList() as List<T>;
        break;
      case ContentType.playlist:
        contentList = state.playlists as List<T>;
        break;
      case ContentType.artist:
        contentList = state.artists as List<T>;
        break;
    }
    if (filterFavorite) {
      return ContentUtils.filterFavorite(contentList).toList();
    }
    return contentList;
  }

  /// Returns content of specified type with ID.
  T? getContentById<T extends Content>(int id, ContentType<T> contentType) {
    if (contentType == ContentType.album) {
      return state.albums[id] as T?;
    }
    return getContent(contentType).firstWhereOrNull((el) => el.id == id);
  }

  /// Refetches all the content.
  Future<void> refetchAll() async {
    await Future.wait([
      for (final contentType in ContentType.values) refetch(contentType),
    ]);
    if (!disposed.value) {
      await MusicPlayer.instance.restoreLastSong();
    }
  }

  /// Refetches content by the [contentType].
  ///
  /// When [updateQueues] is `true`, checks checks the queues for obsolete songs by calling
  /// [QueueControl.removeObsolete] (only works with [Song]s).
  Future<void> refetch(
    ContentType contentType, {
    bool updateQueues = true,
    bool emitChangeEvent = true,
  }) async {
    if (disposed.value) {
      return;
    }
    try {
      switch (contentType) {
        case ContentType.song:
          state.allSongs.setSongs((await SweyerPlugin.instance.retrieveSongs(Song.fromMap)).toList());
          if (_empty) {
            dispose();
            return;
          }
          sort(emitChangeEvent: false, contentType: contentType);
          if (updateQueues) {
            QueueControl.instance.removeObsolete(emitChangeEvent: false);
          }
          break;
        case ContentType.album:
          state.albums = await SweyerPlugin.instance.retrieveAlbums(Album.fromMap);
          if (disposed.value) {
            return;
          }
          final origin = QueueControl.instance.state.origin;
          if (origin is Album && state.albums[origin.id] == null) {
            QueueControl.instance.resetQueueAsFallback();
          }
          sort(emitChangeEvent: false, contentType: contentType);
          break;
        case ContentType.playlist:
          state.playlists = (await SweyerPlugin.instance.retrievePlaylists(Playlist.fromMap)).toList();
          if (disposed.value) {
            return;
          }
          final origin = QueueControl.instance.state.origin;
          if (origin is Playlist && state.playlists.firstWhereOrNull((el) => el == origin) == null) {
            QueueControl.instance.resetQueueAsFallback();
          }
          sort(emitChangeEvent: false, contentType: contentType);
          break;
        case ContentType.artist:
          state.artists = (await SweyerPlugin.instance.retrieveArtists(Artist.fromMap)).toList();
          if (disposed.value) {
            return;
          }
          final origin = QueueControl.instance.state.origin;
          if (origin is Artist && state.artists.firstWhereOrNull((el) => el == origin) == null) {
            QueueControl.instance.resetQueueAsFallback();
          }
          sort(emitChangeEvent: false, contentType: contentType);
          break;
      }
      if (emitChangeEvent) {
        emitContentChange();
      }
    } on SweyerPluginException catch (ex, stack) {
      FirebaseCrashlytics.instance.recordError(
        ex,
        stack,
        reason: 'in re-fetch ${contentType.name}',
      );
      ShowFunctions.instance.showToast(msg: staticl10n.oopsErrorOccurred);
    }
  }

  /// Searches for content by given [query] and the [contentType].
  List<T> search<T extends Content>(String query, {required ContentType<T> contentType}) {
    // Lowercase to bring strings to one format
    query = query.toLowerCase();
    final words = query.split(' ');

    // TODO: add filter by year, and perhaps make a whole filter system, so it would be easy to filter by any parameter
    // this should be some option in the UI like "Search by year",
    // i disabled it because it filtered out searches like "28 days later soundtrack".
    //
    // final year = int.tryParse(words[0]);

    /// Splits string by spaces, or dashes, or bar, or parenthesis
    final abbreviationRegexp = RegExp(r'[\s\-|()]');
    final l10n = staticl10n;

    /// Checks whether a [string] is abbreviation for the [query].
    /// For example: "big baby tape - bbt"
    bool isAbbreviation(String string) {
      return string
          .toLowerCase()
          .split(abbreviationRegexp)
          .map((word) => word.isNotEmpty ? word[0] : '')
          .join()
          .contains(query);
    }

    switch (contentType as ContentType) {
      case ContentType.song:
        return state.allSongs.songs
            .where((song) {
              // Exact query search
              final wordsTest = words
                  .map<bool>(
                    (word) =>
                        song.title.toLowerCase().contains(word) ||
                        ContentUtils.localizedArtist(song.artist, l10n).toLowerCase().contains(word) ||
                        (song.album?.toLowerCase().contains(word) ?? false),
                  )
                  .toList();
              final fullQuery = wordsTest.every((e) => e);
              // Abbreviation search
              final abbreviation = isAbbreviation(song.title);
              return fullQuery || abbreviation;
            })
            .cast<T>()
            .toList();
      case ContentType.album:
        return state.albums.values
            .where((album) {
              // Exact query search
              final wordsTest = words
                  .map<bool>(
                    (word) =>
                        ContentUtils.localizedArtist(album.artist, l10n).toLowerCase().contains(word) ||
                        album.album.toLowerCase().contains(word),
                  )
                  .toList();
              final fullQuery = wordsTest.every((e) => e);
              // Abbreviation search
              final abbreviation = isAbbreviation(album.album);
              return fullQuery || abbreviation;
            })
            .cast<T>()
            .toList();
      case ContentType.playlist:
        return state.playlists
            .where((playlist) {
              // Exact query search
              final wordsTest = words
                  .map<bool>(
                    (word) => playlist.name.toLowerCase().contains(word),
                  )
                  .toList();
              final fullQuery = wordsTest.every((e) => e);
              // Abbreviation search
              final abbreviation = isAbbreviation(playlist.name);
              return fullQuery || abbreviation;
            })
            .cast<T>()
            .toList();
      case ContentType.artist:
        return state.artists
            .where((artist) {
              // Exact query search
              final wordsTest = words
                  .map<bool>(
                    (word) => artist.artist.toLowerCase().contains(word),
                  )
                  .toList();
              final fullQuery = wordsTest.every((e) => e);
              // Abbreviation search
              final abbreviation = isAbbreviation(artist.artist);
              return fullQuery || abbreviation;
            })
            .cast<T>()
            .toList();
    }
  }

  /// Sorts songs, albums, etc.
  /// See [ContentState.sorts].
  void sort<T extends Content>({
    required ContentType<T> contentType,
    Sort<T>? sort,
    bool emitChangeEvent = true,
  }) {
    final sorts = state.sorts;
    sort ??= sorts.get(contentType) as Sort<T>;
    switch (contentType as ContentType) {
      case ContentType.song:
        final castedSort = sort as SongSort;
        sorts.set(castedSort, key: contentType);
        repository.songSort.set(castedSort);
        final comparator = castedSort.comparator;
        state.allSongs.songs.sort(comparator);
        break;
      case ContentType.album:
        final castedSort = sort as AlbumSort;
        sorts.set(castedSort, key: contentType);
        repository.albumSort.set(castedSort);
        final comparator = castedSort.comparator;
        state.albums = Map.fromEntries(state.albums.entries.toList()
          ..sort((a, b) {
            return comparator(a.value, b.value);
          }));
        break;
      case ContentType.playlist:
        final castedSort = sort as PlaylistSort;
        sorts.set(castedSort, key: contentType);
        repository.playlistSort.set(castedSort);
        final comparator = castedSort.comparator;
        state.playlists.sort(comparator);
        break;
      case ContentType.artist:
        final castedSort = sort as ArtistSort;
        sorts.set(castedSort, key: contentType);
        repository.artistSort.set(castedSort);
        final comparator = castedSort.comparator;
        state.artists.sort(comparator);
        break;
    }
    // Emit event to track change stream
    if (emitChangeEvent) {
      emitContentChange();
    }
  }

  /// Filters out non-source songs (with negative IDs), and asserts that.
  ///
  /// That ensures invalid items are never passed to platform and allows to catch
  /// invalid states in debug mode.
  Set<Song> _ensureSongsAreSource(Set<Song> songs) {
    return songs.fold<Set<Song>>({}, (prev, el) {
      if (el.id >= 0) {
        prev.add(el);
      } else {
        assert(false, "All IDs must be source (non-negative)");
      }
      return prev;
    }).toSet();
  }

  /// Sets songs' favorite flag to [value].
  ///
  /// The songs must have a source ID (non-negative).
  Future<void> setSongsFavorite(Set<Song> songs, bool value) async {
    if (DeviceInfoControl.instance.useScopedStorageForFileModifications) {
      try {
        final result = await SweyerPlugin.instance.setSongsFavorite(songs, value);
        if (result) {
          await refetch(ContentType.song);
        }
      } catch (ex, stack) {
        FirebaseCrashlytics.instance.recordError(
          ex,
          stack,
          reason: 'in setSongsFavorite',
        );
        ShowFunctions.instance.showToast(
          msg: staticl10n.oopsErrorOccurred,
        );
        debugPrint('setSongsFavorite error: $ex');
      }
    }
  }

  /// Deletes a set of songs.
  ///
  /// The songs must have a source ID (non-negative).
  Future<void> deleteSongs(Set<Song> songs) async {
    songs = _ensureSongsAreSource(songs);

    void removeFromState() {
      for (final song in songs) {
        state.allSongs.byId.remove(song.id);
      }
      if (songs.isEmpty) {
        dispose();
      } else {
        QueueControl.instance.removeObsolete();
      }
    }

    // On Android R the deletion is performed with OS dialog.
    if (DeviceInfoControl.instance.sdkInt < 30) {
      removeFromState();
    }

    try {
      final result = await SweyerPlugin.instance.deleteSongs(songs);
      await refetchAll();
      if (DeviceInfoControl.instance.useScopedStorageForFileModifications && result) {
        removeFromState();
      }
    } catch (ex, stack) {
      FirebaseCrashlytics.instance.recordError(
        ex,
        stack,
        reason: 'in deleteSongs',
      );
      ShowFunctions.instance.showToast(
        msg: staticl10n.deletionError,
      );
      debugPrint('deleteSongs error: $ex');
    }
  }

  /// When playlists are being updated in any way, there's a chance
  /// that after refetching a playlist, it will contain a song with
  /// ID that we don't know yet.
  ///
  /// To avoid this, both songs and playlists should be refetched.
  Future<void> refetchSongsAndPlaylists() async {
    await Future.wait([
      refetch(ContentType.song, emitChangeEvent: false),
      refetch(ContentType.playlist, emitChangeEvent: false),
    ]);
    emitContentChange();
  }

  /// Checks if there's are playlists with names like "name" and "name (1)" and:
  /// * if yes, increases the number by one from the max and returns string with it
  /// * else returns the string unmodified.
  Future<String> correctPlaylistName(String name) async {
    // Update the playlist in case they are outdated
    await refetch(ContentType.playlist, emitChangeEvent: false);

    // If such name already exists, find the max duplicate number and make the name
    // "name (max + 1)" instead.
    if (state.playlists.firstWhereOrNull((el) => el.name == name) != null) {
      // Regexp to search for names like "name" and "name (1)"
      // Things like "name (1)(1)" will not be matched
      //
      // Part of it is taken from https://stackoverflow.com/a/17779833/9710294
      //
      // Explanation:
      // * `name`: playlist name
      // * `(`: begin optional capturing group, because we need to match the name without parentheses
      // * ` `: match space
      // * `\(`: match an opening parentheses
      // * `(`: begin capturing group
      // * `[^)]+`: match one or more non ) characters
      // * `)`: end capturing group
      // * `\)` : match closing parentheses
      // * `)?`: close optional capturing group\
      // * `$`: match string end
      final regexp = RegExp(name.toString() + r'( \(([^)]+)\))?$');
      int? max;
      for (final el in state.playlists) {
        final match = regexp.firstMatch(el.name);
        if (match != null) {
          final capturedNumber = match.group(2);
          final number = capturedNumber == null ? 0 : int.tryParse(capturedNumber);
          if (number != null && (max == null || max < number)) {
            max = number;
          }
        }
      }
      if (max != null) {
        name = '$name (${max + 1})';
      }
    }

    return name;
  }

  /// Creates a playlist with a given name and returns a corrected with [correctPlaylistName] name.
  Future<String> createPlaylist(String name) async {
    name = await correctPlaylistName(name);
    await SweyerPlugin.instance.createPlaylist(name);
    await refetchSongsAndPlaylists();
    return name;
  }

  /// Renames a playlist and:
  /// * if operation was successful returns a corrected with [correctPlaylistName] name
  /// * else returns null
  Future<String?> renamePlaylist(Playlist playlist, String name) async {
    try {
      name = await correctPlaylistName(name);
      await SweyerPlugin.instance.renamePlaylist(playlist, name);
      await refetchSongsAndPlaylists();
      return name;
    } on PlaylistNotExistException {
      return null;
    }
  }

  /// Inserts songs in the playlist at the given [index].
  Future<void> insertSongsInPlaylist({
    required int index,
    required List<Song> songs,
    required Playlist playlist,
  }) async {
    await SweyerPlugin.instance.insertSongsInPlaylist(index: index, songs: songs, playlist: playlist);
    await refetchSongsAndPlaylists();
  }

  /// Moves song in playlist, returned value indicates whether the operation was successful.
  Future<void> moveSongInPlaylist({
    required Playlist playlist,
    required int from,
    required int to,
    bool emitChangeEvent = true,
  }) async {
    if (from != to) {
      await SweyerPlugin.instance.moveSongInPlaylist(playlist: playlist, from: from, to: to);
      if (emitChangeEvent) {
        await refetchSongsAndPlaylists();
      }
    }
  }

  /// Removes songs from playlist at given [indexes].
  Future<void> removeFromPlaylistAt({
    required List<int> indexes,
    required Playlist playlist,
  }) async {
    await SweyerPlugin.instance.removeFromPlaylistAt(indexes: indexes, playlist: playlist);
    await refetchSongsAndPlaylists();
  }

  /// Deletes playlists.
  Future<void> deletePlaylists(List<Playlist> playlists) async {
    try {
      await SweyerPlugin.instance.removePlaylists(playlists);
      await refetchSongsAndPlaylists();
    } catch (ex, stack) {
      FirebaseCrashlytics.instance.recordError(
        ex,
        stack,
        reason: 'in deletePlaylists',
      );
      ShowFunctions.instance.showToast(
        msg: staticl10n.deletionError,
      );
      debugPrint('deletePlaylists error: $ex');
    }
  }
}

class ContentUtils {
  ContentUtils._();

  /// Android unknown artist.
  static const unknownArtist = '<unknown>';

  /// If artist is unknown returns localized artist.
  /// Otherwise returns artist as is.
  static String localizedArtist(String artist, AppLocalizations l10n) {
    return artist != unknownArtist ? artist : l10n.artistUnknown;
  }

  static const String dot = '•';

  /// Joins list with the [dot].
  static String joinDot(List<Object?> list) {
    return list.where((item) => item != null && item.toString().isNotEmpty).join(' $dot ');
  }

  /// Returns a default icon for the playlist art.
  ///
  /// This is needed to show the playlist icon with the empty playlist,
  /// and the song with non-empty, because non-empty playlist
  /// shows arts of the first 4 songs in it.
  static IconData defaultIconForPlaylistArt(PersistentQueue queue) {
    switch (queue.type) {
      case ContentType.song:
      case ContentType.artist:
        // (This is unreachable)
        throw ArgumentError();
      case ContentType.album:
        return queue.type.icon;
      case ContentType.playlist:
        return queue.length > 0 ? ContentType.song.icon : queue.icon;
    }
  }

  /// Appends dot and year to [string].
  static String appendYearWithDot(String string, int? year) {
    if (year == null) {
      return string;
    }
    return '$string $dot $year';
  }

  /// Checks whether a [Song] is currently playing.
  /// Compares by [Song.sourceId].
  static bool songIsCurrent(Song song) {
    return song.sourceId == PlaybackControl.instance.currentSong.sourceId;
  }

  /// Checks whether a song origin is currently playing.
  static bool originIsCurrent(SongOrigin origin) {
    final queues = QueueControl.instance.state;
    return queues.type == QueueType.origin && origin == queues.origin ||
        queues.type != QueueType.origin && origin == PlaybackControl.instance.currentSongOrigin;
  }

  /// Computes the duration of multiple [songs] and returns it as formatted string.
  static String bulkDuration(Iterable<Song> songs) {
    final duration = Duration(milliseconds: songs.fold(0, (prev, el) => prev + el.duration));
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    final buffer = StringBuffer();
    if (hours > 0) {
      if (hours.toString().length < 2) {
        buffer.write(0);
      }
      buffer.write(hours);
      buffer.write(':');
    }
    if (minutes > 0) {
      if (minutes.toString().length < 2) {
        buffer.write(0);
      }
      buffer.write(minutes);
      buffer.write(':');
    }
    if (seconds > 0) {
      if (seconds.toString().length < 2) {
        buffer.write(0);
      }
      buffer.write(seconds);
    }
    return buffer.toString();
  }

  /// Joins and returns a list of all songs of specified [origins] list.
  static List<Song> joinSongOrigins(Iterable<SongOrigin> origins) {
    final List<Song> songs = [];
    for (final origin in origins) {
      for (final song in origin.songs) {
        song.origin = origin;
        songs.add(song);
      }
    }
    return songs;
  }

  /// Joins specified [origins] list and returns a list of all songs and a
  /// shuffled variant of it.
  static ShuffleResult shuffleSongOrigins(Iterable<SongOrigin> origins) {
    final List<Song> songs = joinSongOrigins(origins);
    final List<Song> shuffledSongs = [];
    for (final origin in List<SongOrigin>.from(origins)..shuffle()) {
      for (final song in origin.songs) {
        song.origin = origin;
        shuffledSongs.add(song);
      }
    }
    return ShuffleResult(
      songs,
      shuffledSongs,
    );
  }

  /// Accepts a collection of content, extracts songs from each entry
  /// and returns a one flattened array of songs.
  static List<Song> flatten(Iterable<Content> collection) {
    final List<Song> songs = [];
    for (final content in collection) {
      switch (content.type) {
        case ContentType.song:
          songs.add(content as Song);
          break;
        case ContentType.album:
          songs.addAll((content as Album).songs);
          break;
        case ContentType.playlist:
          songs.addAll((content as Playlist).songs);
          break;
        case ContentType.artist:
          songs.addAll((content as Artist).songs);
          break;
      }
    }
    return songs;
  }

  /// Filter content collection by favorite.
  static Iterable<T> filterFavorite<T extends Content>(Iterable<T> content) {
    return content.where((el) => el.isFavorite);
  }

  /// Receives a selection data set, extracts all types of contents,
  /// and returns the result.
  static ContentTuple selectionPack(Set<SelectionEntry<Content>> data) {
    return _selectionPack(
      data: data,
      sort: false,
    );
  }

  /// Receives a selection data set, extracts all types of contents,
  /// sorts them by index in ascending order and returns the result.
  ///
  /// See also discussion in [SelectionEntry].
  static ContentTuple selectionPackAndSort(Set<SelectionEntry<Content>> data) {
    return _selectionPack(
      data: data,
      sort: true,
    );
  }

  static ContentTuple _selectionPack({
    required Set<SelectionEntry<Content>> data,
    required bool sort,
  }) {
    final List<SelectionEntry<Song>> songs = [];
    final List<SelectionEntry<Album>> albums = [];
    final List<SelectionEntry<Playlist>> playlists = [];
    final List<SelectionEntry<Artist>> artists = [];
    for (final entry in data) {
      switch (entry.data.type) {
        case ContentType.song:
          songs.add(entry as SelectionEntry<Song>);
          break;
        case ContentType.album:
          albums.add(entry as SelectionEntry<Album>);
          break;
        case ContentType.playlist:
          playlists.add(entry as SelectionEntry<Playlist>);
          break;
        case ContentType.artist:
          artists.add(entry as SelectionEntry<Artist>);
          break;
      }
    }
    if (sort) {
      songs.sort((a, b) => a.index.compareTo(b.index));
      albums.sort((a, b) => a.index.compareTo(b.index));
      playlists.sort((a, b) => a.index.compareTo(b.index));
      artists.sort((a, b) => a.index.compareTo(b.index));
    }
    return ContentTuple(
      songs: songs.map((el) => el.data).toList(),
      albums: albums.map((el) => el.data).toList(),
      playlists: playlists.map((el) => el.data).toList(),
      artists: artists.map((el) => el.data).toList(),
    );
  }

  /// Returns the source song ID based of the provided id map.
  ///
  /// If [idMap] is null, [ContentState.idMap] will be used.
  static int getSourceId(int id, {required SongOrigin? origin, IdMap? idMap}) {
    return id < 0
        ? (idMap ?? QueueControl.instance.state.idMap)[IdMapKey(id: id, originEntry: origin?.toSongOriginEntry())]!
        : id;
  }

  /// Checks the [song] for being a duplicate within the [origin], and if
  /// it is, changes its ID and saves the mapping to the original source ID to
  /// an [idMap].
  ///
  /// The [list] is the list of songs contained in this origin.
  ///
  /// This must be called before the song is inserted to the queue, otherwise
  /// the song might be considered as a duplicate of itself, which will be incorrect.
  /// The function asserts that.
  ///
  /// Marks the queue as dirty, so the next [setQueue] will save it.
  ///
  /// The returned value indicates whether the duplicate song was found and
  /// [source] was changed.
  static bool deduplicateSong({
    required Song song,
    required List<Song> list,
    required IdMap idMap,
  }) {
    assert(() {
      final sourceSong = ContentControl.instance.state.allSongs.byId.get(song.sourceId);
      if (identical(sourceSong, song)) {
        throw ArgumentError(
          "Tried to handle duplicate on the source song in `allSongs`. This may lead "
          "to that the source song ID is lost, copy the song first",
        );
      }
      return true;
    }());
    assert(() {
      final sameSong = list.firstWhereOrNull((el) => identical(el, song));
      if (identical(sameSong, song)) {
        throw ArgumentError(
          "The provided `song` is contained in the given `list`. This is incorrect "
          "usage of this function, it should be called before the song is inserted to "
          "the `list`",
        );
      }
      return true;
    }());
    final candidates = list.where((el) => el.id == song.id);
    if (candidates.isNotEmpty) {
      final map = idMap;
      final newId = -(map.length + 1);
      map[IdMapKey(
        id: newId,
        originEntry: song.origin?.toSongOriginEntry(),
      )] = song.sourceId;
      song.id = newId;
      return true;
    }
    return false;
  }
}

/// Result of [ContentUtils.shuffleSongOrigins].
class ShuffleResult {
  const ShuffleResult(this.songs, this.shuffledSongs);
  final List<Song> songs;
  final List<Song> shuffledSongs;
}
