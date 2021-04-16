/*---------------------------------------------------------------------------------------------
*  Copyright (c) nt4f04und. All rights reserved.
*  Licensed under the BSD-style license. See LICENSE in the project root for license information.
*--------------------------------------------------------------------------------------------*/

// @dart = 2.12

import 'dart:async';
import 'dart:convert';

import 'package:device_info/device_info.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:nt4f04unds_widgets/nt4f04unds_widgets.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sweyer/sweyer.dart';

/// The description where the [QueueType.arbitrary] originates from.
/// 
/// Can be Cconverted to human readable text with [AppLocalizations.arbitraryQueueOrigin].
enum ArbitraryQueueOrigin {
  /// Correspnods
  allAlbums,
}

extension ArbitraryQueueOriginSerialization on ArbitraryQueueOrigin {
  String get value => EnumToString.convertToString(this);
}

/// Picks some value based on the provided `T` type of [Content].
/// 
/// Instead of `T`, you can explicitly specify [contentType].
/// 
/// The [fallback] can be specified in cases when the type is [Content].
/// Generally, it's better never use it, but in some cases, like selection actions,
/// that can react to [ContentSelectionController]s of mixed types, it is relevant to use it.
V contentPick<T extends Content, V>({
  Type? contentType,
  required V song,
  required V album,
  V? fallback,
}) {
  // TODO: when i fully migrate to safety, remove this assert and allow passing nulls here
  assert(song != null && album != null);
  switch (contentType ?? T) {
    case Song:
      return song;
    case Album:
      return album;
    case Content:
      if (fallback != null)
        return fallback;
      throw UnimplementedError();
    default:
      throw UnimplementedError();
  }
}

/// A [Map] container for the [Content] as key, and `T` as value entry.
class ContentMap<V> {
  /// Creates a content map from initial value [map].
  ///
  /// If none specified, will initialize the map with `null`s.
  ContentMap([Map<Type, V?>? map]) : 
    _map = map ?? {
      Song: null,
      Album: null,
    };

  Map<Type, V?> _map;

  /// Map values.
  Iterable<V?> get values => _map.values;

  /// Returs a [Sort] per `T` [Content] from the map.
  /// 
  /// If [key] was explicitly provided, will use it instead.
  V getValue<T extends Content>([Type? key]) {
    assert(
      Content.enumerate().contains(typeOf<T>()),
      "Specified type must be a subtype of Content",
    );
    return _map[key ?? T]!;
  }

  /// Puts a [Sort] typed with `T` into the map.
  /// 
  /// If [key] was explicitly provided, will use it instead.
  void setValue<T extends Content>(V value, {Type? key}) {
    assert(
      Content.enumerate().contains(typeOf<T>()),
      "Specified type must be a subtype of Content",
    );
    _map[key ?? T] = value;
  }
}


/// Enum used inside this file to have a pool of queues in a state-managment convenient form.
enum _PoolQueueType {
  /// Any queue type to be displayed (searched or album or etc.).
  queue,

  /// This queue is always produced from the other two.
  shuffled,
}

class _QueuePool {
  _QueuePool(Map<_PoolQueueType, Queue> map)
      : _map = map;

  final Map<_PoolQueueType, Queue> _map;

  /// Serializes [_PoolQueueType.queue].
  final QueueSerializer _queueSerializer = const QueueSerializer('queue.json');
  /// Serializes [_PoolQueueType.shuffled].
  final QueueSerializer _shuffledSerializer = const QueueSerializer('shuffled_queue.json');

  Future<void> init() {
    return Future.wait([
      _queueSerializer.init(),
      _shuffledSerializer.init(),
    ]);
  }

  Future<void> _saveCurrentQueue() {
    if (shuffled) {
      return Future.wait([
        _queueSerializer.save(_map[_PoolQueueType.queue]!.songs),
        _shuffledSerializer.save(_map[_PoolQueueType.shuffled]!.songs),
      ]);
    }
    return _queueSerializer.save(current.songs);
  }

  /// Actual type of the queue, that can be displayed to the user.
  QueueType get type => _type;
  QueueType _type = QueueType.all;

  _PoolQueueType get _internalType {
    if (shuffled) {
      return _PoolQueueType.shuffled;
    }
    return _PoolQueueType.queue;
  }

  Queue get current => _map[_internalType]!;
  Queue get _queue => _map[_PoolQueueType.queue]!;
  Queue get _shuffledQueue => _map[_PoolQueueType.shuffled]!;

  /// Current queue for [QueueType.persistent].
  /// If [type] is not [QueueType.persistent], will return `null`.
  PersistentQueue? get persistent => _persistent;
  PersistentQueue? _persistent;

  /// A search query for [QueueType.searched].
  /// If [type] is not [QueueType.searched], will return `null`.
  String? get searchQuery => _searchQuery;
  String? _searchQuery;

  /// A description where the [QueueType.arbitrary] originates from.
  ///
  /// May be `null`, then by default instead of description, in the interface queue should be just
  /// marked as [AppLocalizations.arbitraryQueue].
  ///
  /// If [type] is not [QueueType.arbitrary], will return `null`.
  ArbitraryQueueOrigin? get arbitraryQueueOrigin => _arbitraryQueueOrigin;
  ArbitraryQueueOrigin? _arbitraryQueueOrigin;

  /// Whether the current queue is modified.
  ///
  /// Applied in certain conditions when user adds, removes
  /// or reorders songs in the queue.
  /// [QueueType.custom] cannot be modified.
  bool get modified => _modified;
  bool _modified = false;

  /// Whether the current queue is shuffled.
  bool get shuffled => _shuffled;
  bool _shuffled = false;
}

class _ContentState {
  final _QueuePool queues = _QueuePool({
    _PoolQueueType.queue: Queue([]),
    _PoolQueueType.shuffled: Queue([]),
  });

  /// The path to default album art to show it in notification.
  late String defaultAlbumArtPath;

  /// All songs in the application.
  /// This list should be modified in any way, except for sorting.
  Queue allSongs = Queue([]);

  Map<int, Album> albums = {};

  /// This is a map to store ids of duplicated songs in queue.
  /// Its key is always negative, so when a song has negative id, you must
  /// look up for the mapping of its actual id in here.
  Map<String, int> idMap = {};

  /// Contains various [Sort]s of the application.
  /// Sorts of specific [Queues] like [Album]s are stored separately. // TODO: this is currently not implemented - remove this todo when it will be
  ///
  /// Values are restored in [ContentControl._restoreSorts].
  final ContentMap<Sort> sorts = ContentMap<Sort>();

  /// Get current playing song.
  Song get currentSong {
    return _songSubject.value!;
  }

  /// Get current playing song.
  Song? get currentSongNullable {
    return _songSubject.value;
  }

  /// Returns index of [currentSong] in the current queue.
  ///
  /// If current song cannot be found for some reason, will fallback the state
  /// to the index `0` and return it.
  int get currentSongIndex {
    var index = queues.current.byId.getSongIndex(currentSong.id);
    if (index < 0) {
      final firstSong = queues.current.songs[0];
      changeSong(firstSong);
      index = 0;
    }
    return index;
  }

  /// Currently playing peristent queue when song is added via [ContentControl.playQueueNext]
  /// or [ContentControl.addQueueToQueue].
  ///
  /// Used for showing [CurrentIndicator] for [PersistenQueue]s.
  ///
  /// See [Song.origin] for more info.
  PersistentQueue? get currentSongOrigin => _currentSongOrigin;
  PersistentQueue? _currentSongOrigin;

  /// Changes current song id and emits change event.
  /// This allows to change the current id visually, separately from the player.
  ///
  /// Also, uses [Song.origin] to set [currentSongOrigin].
  void changeSong(Song song) {
    Prefs.songIdInt.set(song.id);
    if (song.origin == null) {
      _currentSongOrigin = null;
    } else {
      _currentSongOrigin = song.origin;
    }
    // Song id saved to prefs in the native play method.
    emitSongChange(song);
  }

  /// A stream of changes over content.
  /// Called whenever [Content] (queues, songs, albums, etc. changes).
  Stream<void> get onContentChange => _contentSubject.stream;
  final PublishSubject<void> _contentSubject = PublishSubject();

  /// A stream of changes on song.
  Stream<Song> get onSongChange => _songSubject.stream;
  final BehaviorSubject<Song> _songSubject = BehaviorSubject();

  /// Notifies when active selection controller changes.
  /// Will receive null when selection closes.
  ValueNotifier<ContentSelectionController?> selectionNotifier = ValueNotifier(null);

  /// Emit event to [onContentChange].
  ///
  /// Includes updates to queue and any other song list.
  void emitContentChange() {
    assert(!_disposed);
    _contentSubject.add(null);
  }

  /// Emits song change event.
  void emitSongChange(Song song) {
    assert(!_disposed);
    _songSubject.add(song);
  }

  bool _disposed = false;
  void dispose() {
    assert(!_disposed);
    _disposed = true;
    selectionNotifier.dispose();
    // TODO: this might still deliver some pedning events to listeneres, see https://github.com/dart-lang/sdk/issues/45653
    _contentSubject.close();
    _songSubject.close();
  }
}

/// A class to any content-related actions, e.g.:
/// 1. Fetch songs
/// 2. Control queue json
/// 3. Manage queues
/// 4. Search in queues
///
/// etc.
abstract class ContentControl {
  /// Content state.
  ///
  /// This getter only can be called when it's known for sure
  /// that this will be not `null`,  otherwise it will throw.
  static _ContentState get state => _stateSubject.value!;
  /// Same as [state], but can be `null`, which means that the state was disposed.
  static _ContentState? get stateNullable => _stateSubject.value;

  /// Notifies when [state] is changed created or disposed.
  static Stream<_ContentState?> get onStateCreateRemove => _stateSubject.stream;
  static final BehaviorSubject<_ContentState?> _stateSubject = BehaviorSubject();

  static IdMapSerializer idMapSerializer = IdMapSerializer.instance;

  /// Represents songs fetch on app start
  static bool get initializing => _initializeCompleter != null;
  static Completer<void>? _initializeCompleter;

  static bool get _empty => stateNullable?.allSongs.isEmpty ?? true;
  static bool get _disposed => stateNullable == null;

  /// Android SDK integer.
  static late int _sdkInt;
  static int get sdkInt => _sdkInt;

  static ValueNotifier<bool> get devMode => _devMode;
  static late ValueNotifier<bool> _devMode;
  /// Sets dev mode.
  static void setDevMode(bool value) {
    devMode.value = value;
    Prefs.devModeBool.set(value);
  }

  /// The main data app initialization function, inits all queues.
  /// Also handles no-permissions situations.
  static Future<void> init() async {
    if (stateNullable == null) {
      _stateSubject.add(_ContentState());
    }
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    _sdkInt = androidInfo.version.sdkInt;
    _devMode = ValueNotifier(await Prefs.devModeBool.get());
    if (Permissions.granted) {
      _initializeCompleter = Completer();
      state.emitContentChange(); // update ui to show "Searching songs screen"
      await Future.wait([
        state.queues.init(),
        idMapSerializer.init(),
        _restoreSorts(),
      ]);
      await Future.any([
        _initializeCompleter!.future,
        Future.wait([
          for (final contentType in Content.enumerate())
            refetch(contentType: contentType, updateQueues: false, emitChangeEvent: false),
        ]),
      ]);
      if (!_empty && _initializeCompleter != null && !_initializeCompleter!.isCompleted) {
        await _restoreQueue();
        await MusicPlayer.instance.init();
      }
      _initializeCompleter = null;
    }
    // Emit event to track change stream
    stateNullable?.emitContentChange();
  }

  /// Diposes the [state] and stops the currently going [init] process,
  /// if any.
  static void dispose() {
    if (!_disposed) {
      _initializeCompleter?.complete();
      _initializeCompleter = null;
      stateNullable?.dispose();
      _stateSubject.add(null);
      MusicPlayer.instance.dispose();
    }
  }

  /// Should be called if played song is duplicated in the current queue.
  static void handleDuplicate(Song song) {
    final originalSong = state.allSongs.getSong(song)!;
    if (identical(originalSong, song))
      return;
    final map = state.idMap;
    final newId = -(map.length + 1);
    map[newId.toString()] = originalSong.id;
    song.id = newId;
    state.queues._saveCurrentQueue();
    idMapSerializer.save(state.idMap);
  }

  //****************** Queue manipulation methods *****************************************************

  /// Marks queues modified and traverses it to be unshuffled, preseving the shuffled
  /// queue contents.
  static void _unshuffle() {
    setQueue(
      emitChangeEvent: false,
      modified: true,
      shuffled: false,
      songs: state.queues._shuffled
          ? List.from(state.queues._shuffledQueue.songs)
          : null,
    );
  }

  /// Cheks if current queue is persistent, if yes, adds this queue as origin
  /// to all its songs. This is a required actions for each addition to the queue. 
  static void _setOrigins() {
    // Adding origin to the songs in the current persistent playlist.
    if (state.queues.type == QueueType.persistent) {
      final persistentQueue = state.queues.persistent;
      for (final song in persistentQueue!.songs) {
        song.origin = persistentQueue;
      }
      state._currentSongOrigin = persistentQueue;
    }
  }

  /// If the [song] is next (or currently playing), will duplicate it and queue it to be played next,
  /// else will move it to be next. After that it can be duplicated to be played more.
  ///
  /// Same as for [addToQueue]:
  /// * if current queue is [QueueType.persistent] and the added [song] is present in it, will mark the queue as modified,
  /// else will traverse it into [QueueType.arbitrary]. All the other queues will be just marked as modified.
  /// * if current queue is shuffled, it will copy all songs (thus saving the order of shuffled songs), go back to be unshuffled,
  /// and add the [songs] there.
  static void playNext(List<Song> songs) {
    assert(songs.isNotEmpty);
    final queues = state.queues;
    // Save queue order
    _unshuffle();
    _setOrigins();
    final currentQueue = queues.current;
    if (songs.length == 1) {
      final song = songs[0];
      if (song != state.currentSong &&
          song != currentQueue.getNextSong(state.currentSong) &&
          state.currentSongIndex != currentQueue.length - 1) {
        currentQueue.removeSong(song);
      }
    }
    bool contains = true;
    for (int i = 0; i < songs.length; i++) {
      currentQueue.insert(state.currentSongIndex + i + 1, songs[i]);
      if (queues._type == QueueType.persistent && contains) {
        final persistentSongs = queues.persistent!.songs;
        final index = persistentSongs.indexWhere((el) => el.sourceId == songs[i].sourceId);
        contains = index >= 0;
      }
    }
    setQueue(type: contains ? null : QueueType.arbitrary);
  }

  /// Queues the [song] to the last position in queue.
  ///
  /// Same as for [playNext]:
  /// * if current queue is [QueueType.persistent] and the added [song] is present in it, will mark the queue as modified,
  /// else will traverse it into [QueueType.arbitrary]. All the other queues will be just marked as modified.
  /// * if current queue is shuffled, it will copy all songs (thus saving the order of shuffled songs), go back to be unshuffled,
  /// and add the [songs] there.
  static void addToQueue(List<Song> songs) {
    assert(songs.isNotEmpty);
    final queues = state.queues;
    // Save queue order
    _unshuffle();
    _setOrigins();
    bool contains = true;
    for (final song in songs) {
      state.queues.current.add(song);
      if (queues._type == QueueType.persistent && contains) {
        final persistentSongs = queues.persistent!.songs;
        final index = persistentSongs.indexWhere((el) => el.sourceId == song.sourceId);
        contains = index >= 0;
      }
    }
    setQueue(type: contains ? null : QueueType.arbitrary);
  }

  /// Queues the persistent [queue] to be played next.
  ///
  /// Saves it to [Song.origin] in its items, and so when the item is played,
  /// this peristent queue will be also shown as playing.
  ///
  /// If currently some persistent queue is already playing, will first save the current queue to
  /// [Song.origin] in its items.
  /// 
  /// In difference with [playNext], always traverses the playlist into [QueueType.arbitrary].
  static void playQueueNext(PersistentQueue queue) {
    final songs = queue.songs;
    assert(songs.isNotEmpty);
    // Save queue order
    _unshuffle();
    _setOrigins();
    final currentQueue = state.queues.current;
    final currentIndex = state.currentSongIndex;
    int i = 0;
    for (final song in songs) {
      song.origin = queue;
      currentQueue.insert(currentIndex + i + 1, song);
      i++;
    }
    setQueue(type: QueueType.arbitrary);
  }

  /// Queues the persistent [queue] to the last position in queue.
  ///
  /// Saves it to [Song.origin] in its items, and so when the item is played,
  /// this peristent queue will be also shown as playing.
  ///
  /// If currently some persistent queue is already playing, will first save the current queue to
  /// [Song.origin] in its items.
  ///
  /// In difference with [addToQueue], always traverses the playlist into [QueueType.arbitrary].
  static void addQueueToQueue(PersistentQueue queue) {
    final songs = queue.songs;
    assert(songs.isNotEmpty);
    // Save queue order
    _unshuffle();
    _setOrigins();
    for (final song in songs) {
      song.origin = queue;
      state.queues.current.add(song);
    }
    setQueue(type: QueueType.arbitrary);
  }

  /// Inserts [song] at [index] in the queue.
  static void insertToQueue(int index, Song song) {
    // Save queue order
    _unshuffle();
    final queues = state.queues;
    bool contains = true;
    if (queues._type == QueueType.persistent) {
      final persistentSongs = queues.persistent!.songs;
      final index = persistentSongs.indexWhere((el) => el.sourceId == song.sourceId);
      contains = index >= 0;
    }
    setQueue(type: contains ? null : QueueType.arbitrary);
  }

  /// Removes the [song] from the queue.
  ///
  /// If this was the last item in current queue, will:
  /// * fall back to the first song in [QueueType.all]
  /// * fall back to [QueueType.all]
  /// * stop the playback
  static void removeFromQueue(Song song) {
    final queues = state.queues;
    if (queues.current.length == 1) {
      resetQueue();
      MusicPlayer.instance.pause();
    } else {
      queues.current.removeSong(song);
      setQueue(modified: true);
    }
  }

  /// Removes a song at given [index] from the queue.
  ///
  /// If this was the last item in current queue, will:
  /// * fall back to the first song in [QueueType.all]
  /// * fall back to [QueueType.all]
  /// * stop the playback
  static void removeFromQueueAt(int index) {
    final queues = state.queues;
    if (queues.current.length == 1) {
      resetQueue();
      MusicPlayer.instance.pause();
    } else {
      queues.current.removeSongAt(index);
      setQueue(modified: true);
    }
  }

  /// Removes all items at given [indexes] from the queue.
  ///
  /// If the [indexes] list has length bigger than or equal to current queue
  /// length, will:
  /// * fall back to the first song in [QueueType.all]
  /// * fall back to [QueueType.all]
  /// * stop the playback
  static void removeAllFromQueueAt(List<int> indexes) {
    final queues = state.queues;
    if (indexes.length >= queues.current.length) {
      resetQueue();
      MusicPlayer.instance.pause();
    } else {
      for (int i = indexes.length - 1; i >= 0; i--) {
        queues.current.removeSongAt(indexes[i]);
      }
      setQueue(modified: true);
    }
  }

  /// A shorthand for setting [QueueType.searched].
  static void setSearchedQueue(String query, List<Song> songs) {
     ContentControl.setQueue(
      type: QueueType.searched,
      searchQuery: query,
      modified: false,
      shuffled: false,
      songs: songs,
    );
  }

  /// A shorthand for setting [QueueType.persistent].
  /// 
  /// By default sets [shuffled] queue.
  static void setPersistentQueue({
    required PersistentQueue queue,
    required List<Song> songs,
    bool shuffled = false,
  }) {
    List<Song>? shuffledSongs;
    if (shuffled) {
      shuffledSongs = Queue.shuffleSongs(songs);
    }
    ContentControl.setQueue(
      type: QueueType.persistent,
      persistentQueue: queue,
      modified: false,
      shuffled: shuffled,
      songs: shuffledSongs ?? songs,
      shuffleFrom: songs,
    );
  }

  /// Resets queue to all songs.
  static void resetQueue() {
    setQueue(
      type: QueueType.all,
      modified: false,
      shuffled: false,
    );
  }

  /// Sets the queue with specified [type] and other parameters.
  /// Most of the parameters are updated separately and almost can be omitted,
  /// unless differently specified:
  ///
  /// * [shuffled] can be used to shuffle / unshuffle the queue
  /// * [modified] can be used to mark current queue as modified
  /// * [songs] is the songs list to set to the queue.
  ///   This array will be copied (unless [copied] is true) and set
  ///   as a source to queue, that function is switching to.
  ///   For example that way when [shuffled] is `true`, this array
  ///   will be used as new queue, without being shuffled.
  /// * [shuffleFrom] is a list of songs to fall back when [shuffle]
  ///   thereafter will be set to `false`.
  ///   
  ///   By default it will also be shuffled and set to shuffled queue,
  ///   unless [songs] are specified, which will override this value.
  ///
  ///   If both [songs] and [shuffleFrom] is not specified, will shuffle
  ///   from current queue.
  /// * [persistentQueue] is the persistent queue being set,
  ///   only applied when [type] is [QueueType.persistent].
  ///   When [QueueType.persistent] is set and currently it's not persistent, this parameter is required.
  ///   Otherwise it can be omitted and for updating other paramters only.
  /// * [searchQuery] is the search query the playlist was searched by,
  ///   only applied when [type] is [QueueType.searched].
  ///   Similarly as for [persistentQueue], when [QueueType.searched] is set and currently it's not searched,
  ///   this parameter is required. Otherwise it can be omitted for updating other paramters only.
  /// * [arbitraryQueueOrigin] is the description where the [QueueType.arbitrary] originates from,
  ///   ignored with other types of queues. If none specified, by default instead of description,
  ///   queue is just marked as [AppLocalizations.arbitraryQueue].
  ///   It always must be localized, so [AppLocalizations] getter must be returned from this function.
  /// 
  ///   Because this parameter can be null with [QueueType.arbitrary], to reset to back to `null`
  ///   after it's set, you need to pass [type] explicitly.
  /// * [emitChangeEvent] is whether to emit a song list change event
  /// * [save] parameter can be used to disable redundant writing to JSONs when,
  ///   for example, when we restore the queue from this exact json.
  /// * [copied] indicates that [songs] was already copied,
  ///   by default set to `false` and will copy it with [List.from]
  static void setQueue({
    QueueType? type,
    bool? shuffled,
    bool? modified,
    List<Song>? songs,
    List<Song>? shuffleFrom,
    PersistentQueue? persistentQueue,
    String? searchQuery,
    ArbitraryQueueOrigin? arbitraryQueueOrigin,
    bool save = true,
    bool copied = false,
    bool emitChangeEvent = true,
  }) {
    final queues = state.queues;

    @pragma('vm:prefer-inline')
    List<Song> copySongs(List<Song> _songs) {
      return copied ? _songs : List.from(_songs);
    }

    assert(
      songs == null || songs.isNotEmpty,
      "It's invalid to set empty songs queue",
    );
    assert(
      type != QueueType.persistent ||
      queues._persistent != null ||
      persistentQueue != null,
      "When you set `persistent` queue and currently none set, you must provide the `persistentQueue` paramenter",
    );
    assert(
      type != QueueType.searched ||
      queues._searchQuery != null ||
      searchQuery != null,
      "When you set `searched` queue and currently none set, you must provide the `searchQuery` paramenter",
    );

    final typeArg = type;
    type ??= queues._type;
    if (type == QueueType.arbitrary) {
      modified = false;
      if (arbitraryQueueOrigin != null) {
        // Set once and don't change thereafter until type is passed explicitly.
        state.queues._arbitraryQueueOrigin = arbitraryQueueOrigin;
        Prefs.arbitraryQueueOrigin.set(arbitraryQueueOrigin.value);
      }
    }
    if (type != QueueType.arbitrary ||
        // Reset when queue type is passed explicitly.
        typeArg == QueueType.arbitrary && arbitraryQueueOrigin == null) {  
      state.queues._arbitraryQueueOrigin = null;
      Prefs.arbitraryQueueOrigin.delete();
    }

    if (type == QueueType.persistent) {
      if (persistentQueue != null) {
        queues._persistent = persistentQueue;
        Prefs.persistentQueueId.set(persistentQueue.id);
      }
    } else {
      queues._persistent = null;
      Prefs.persistentQueueId.delete();
    }

    if (type == QueueType.searched) {
      if (searchQuery != null) {
        queues._searchQuery = searchQuery;
        Prefs.searchQueryString.set(searchQuery);
      }
    } else {
      queues._searchQuery = null;
      Prefs.searchQueryString.delete();
    }

    modified ??= queues._modified;
    shuffled ??= queues._shuffled;

    queues._type = type;
    Prefs.queueTypeString.set(type.value);

    queues._modified = modified;
    Prefs.queueModifiedBool.set(modified);

    if (shuffled) {
      queues._shuffledQueue.setSongs(
        songs != null
          ? copySongs(songs)
          : Queue.shuffleSongs(shuffleFrom ?? queues.current.songs),
      );
      if (shuffleFrom != null) {
        queues._queue.setSongs(copySongs(shuffleFrom));
      }
    } else {
      queues._shuffledQueue.clear();
      if (songs != null) {
        queues._queue.setSongs(copySongs(songs));
      } else if (type == QueueType.all && !modified) {
        queues._queue.setSongs(List.from(state.allSongs.songs));
      }
    }

    queues._shuffled = shuffled;
    Prefs.queueShuffledBool.set(shuffled);

    if (save) {
      state.queues._saveCurrentQueue();
    }

    if (state.idMap.isNotEmpty &&
        !modified &&
        !shuffled &&
        type != QueueType.persistent &&
        type != QueueType.arbitrary) {
      state.idMap.clear();
      idMapSerializer.save(state.idMap);
    }

    if (emitChangeEvent) {
      state.emitContentChange();
    }
  }

  /// Checks queue pool and removes obsolete songs - that are no longer on all songs data.
  static void removeObsolete({ bool emitChangeEvent = true }) {
    state.queues._queue.compareAndRemoveObsolete(state.allSongs);
    state.queues._shuffledQueue.compareAndRemoveObsolete(state.allSongs);

    if (state.queues.current.isEmpty) {
      //  Set queue to global if searched or shuffled are happened to be zero-length
      setQueue(
        type: QueueType.all,
        modified: false,
        shuffled: false,
        emitChangeEvent: false,
      );
    } else {
      state.queues._saveCurrentQueue();
    }

    // Update current song
    if (state.queues.current.isNotEmpty &&
        state.currentSongIndex < 0) {
      final player = MusicPlayer.instance;
      if (player.playing) {
        player.pause();
        player.setSong(state.queues.current.songs[0]);
      }
    }

    if (emitChangeEvent) {
      state.emitContentChange();
    }
  }

  //****************** Content manipulation methods *****************************************************
  
  /// Returns content of specified type.
  static List<T> getContent<T extends Content>([Type? contentType]) {
    return contentPick<T, List<T> Function()>(
      contentType: contentType,
      song: () => ContentControl.state.allSongs.songs as List<T>,
      album: () => ContentControl.state.albums.values.toList() as List<T>,
    )();
  }

  /// Refetches all the content.
  static Future<void> refetchAll() async {
    await Future.wait([
      for (final contentType in Content.enumerate())
        refetch(contentType: contentType),
    ]);
    return MusicPlayer.instance.restoreLastSong();
  }

  /// Refetches content by the `T` content type.
  ///
  /// Instead of `T`, you can explicitly specify [contentType].
  ///
  /// When [updateQueues] is `true`, checks checks the queues for obsolete songs by calling [removeObsolete].
  /// (only works with [Song]s).
  static Future<void> refetch<T extends Content>({
    Type? contentType,
    bool updateQueues = true,
    bool emitChangeEvent = true,
  }) async {
    await contentPick<T, AsyncCallback>(
      contentType: contentType,
      song: () async {
        state.allSongs.setSongs(await ContentChannel.retrieveSongs());
        if (_empty) {
          dispose();
          return;
        }
        sort<Song>(emitChangeEvent: false);
        if (updateQueues) {
          removeObsolete(emitChangeEvent: false);
        }
      },
      album: () async {
        if (_disposed) {
          return;
        }
        state.albums = await ContentChannel.retrieveAlbums();
        sort<Album>(emitChangeEvent: false);
      }
    )();
    if (emitChangeEvent) {
      stateNullable?.emitContentChange();
    }
  }

  /// Searches for content by given [query] and the `T` content type.
  ///
  /// Instead of `T`, you can explicitly specify [contentType]..
  static List<T> search<T extends Content>(String query, { Type? contentType }) {
    // Lowercase to bring strings to one format
    query = query.toLowerCase();
    final words = query.split(' ');
    // TODO: add filter by year
    // this should be some option in the UI like "Search by year",
    // i disabled it because it filtered out searches like "28 days later soundtrack".
    //
    // final year = int.tryParse(words[0]);
    const year = null;
    /// Splits string by spaces, or dashes, or bar, or paranthesis
    final abbreviationRegexp = RegExp(r'[\s\-\|\(\)]');
    final l10n = staticl10n;
    /// Checks whether a [string] is abbreviation.
    /// For example: "big baby tape - bbt"
    bool isAbbreviation(String string) {
      return string.toLowerCase()
            .split(abbreviationRegexp)
            .map((word) => word.isNotEmpty ? word[0] : '')
            .join()
            .contains(query);
    }
    final contentInterable = contentPick<T, Iterable<T> Function()>(
      contentType: contentType,
      song: () {
        return state.allSongs.songs.where((song) {
          // Exact query search
          bool fullQuery;
          final wordsTest = words.map<bool>((word) =>
            song.title.toLowerCase().contains(word) ||
            formatArtist(song.artist, l10n).toLowerCase().contains(word) ||
            song.album.toLowerCase().contains(word)
          ).toList();
          // Exclude the year from query word tests
          if (year != null) {
            wordsTest.removeAt(0);
          }
          fullQuery = wordsTest.every((e) => e);
          final abbreviation = isAbbreviation(song.title);
          // Filter by year
          if (year != null && year != song.getAlbum().year)
            return false;
          return fullQuery || abbreviation;
        }).cast<T>();
      },
      album: () {
        return state.albums.values.where((album) {
          // Exact query search
          bool fullQuery;
          final wordsTest = words.map<bool>((word) =>
            formatArtist(album.artist, l10n).toLowerCase().contains(word) ||
            album.album.toLowerCase().contains(word),
          ).toList();
          // Exclude the year from query word tests
          if (year != null) {
            wordsTest.removeAt(0);
          }
          fullQuery = wordsTest.every((e) => e);
          final abbreviation = isAbbreviation(album.album);
          // Filter by year
          if (year != null && year != album.year)
            return false;
          return fullQuery || abbreviation;
        }).cast<T>();
      },
    )();
    return contentInterable.toList();
  }

  /// Sorts songs, albums, etc.
  /// See [ContentState.sorts].
  static void sort<T extends Content>({ Sort<T>? sort, bool emitChangeEvent = true }) {
    final sorts = state.sorts;
    sort ??= sorts.getValue<T>() as Sort<T>;
    contentPick<T, VoidCallback>(
      song: () {
        final _sort = sort! as SongSort;
        sorts.setValue<Song>(_sort);
        Prefs.songSortString.set(jsonEncode(sort.toJson()));
        final comparator = _sort.comparator;
        state.allSongs.songs.sort(comparator);
      },
      album: () {
        final _sort = sort! as AlbumSort;
        sorts.setValue<Album>(_sort);
        Prefs.albumSortString.set(jsonEncode(_sort.toJson()));
        final comparator = _sort.comparator;
        state.albums = Map.fromEntries(state.albums.entries.toList()
          ..sort((a, b) {
            return comparator(a.value, b.value);
          }));
      }
    )();
    // Emit event to track change stream
    if (emitChangeEvent) {
      state.emitContentChange();
    }
  }

  /// Deletes songs by specified [idSet].
  ///
  /// Ids must be source (not negative).
  static Future<void> deleteSongs(Set<int> idSet) async {
    final Set<Song> songsSet = {};
    // On Android R the deletion is performed with OS dialog.
    if (_sdkInt >= 30) {
      for (final id in idSet) {
        final song = state.allSongs.byId.getSong(id);
        if (song != null) {
          songsSet.add(song);
        }
      }
    } else {
      for (final id in idSet) {
        final song = state.allSongs.byId.getSong(id);
        if (song != null) {
          songsSet.add(song);
        }
        state.allSongs.byId.removeSong(id);
      }
      removeObsolete();
    }

    try {
      final result = await ContentChannel.deleteSongs(songsSet);
      if (sdkInt >= 30 && result) {
        idSet.forEach(state.allSongs.byId.removeSong);
        removeObsolete();
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
      print('Deletion error: $ex');
    }
  }

  //****************** Private methods for restoration *****************************************************

  /// Restores [sorts] from [Prefs].
  static Future<void> _restoreSorts() async {
    state.sorts._map = {
      Song: SongSort.fromJson(jsonDecode(await Prefs.songSortString.get())),
      Album: AlbumSort.fromJson(jsonDecode(await Prefs.albumSortString.get())),
    };
  }

  /// Restores saved queues.
  ///
  /// * If stored queue becomes empty after restoration (songs do not exist anymore), will fall back to not modified [QueueType.all].
  /// * If saved persistent queue songs are restored successfully, but the playlist itself cannot be found, will fall back to [QueueType.arbitrary].
  /// * In all other cases it will restore as it was.
  static Future<void> _restoreQueue() async {
    final shuffled = await Prefs.queueShuffledBool.get();
    final modified = await Prefs.queueModifiedBool.get();
    final persistentQueueId = await Prefs.persistentQueueId.get();
    final type = EnumToString.fromString(
      QueueType.values,
      await Prefs.queueTypeString.get(),
    )!;
    state.idMap = await idMapSerializer.read();

    final List<Song> queueSongs = [];
    final queueIds = await state.queues._queueSerializer.read();
    for (final id in queueIds) {
      final song = state.allSongs.byId.getSong(Song.getSourceId(id));
      if (song != null) {
        queueSongs.add(song.copyWith(id: id));
      }
    }

    final List<Song> shuffledSongs = [];
    if (shuffled == true) {
      final shuffledIds = await state.queues._shuffledSerializer.read();
      for (final id in shuffledIds) {
        final song = state.allSongs.byId.getSong(Song.getSourceId(id));
        if (song != null) {
          shuffledSongs.add(song.copyWith(id: id));
        }
      }
    }

    final songs = shuffled && shuffledSongs.isNotEmpty ? shuffledSongs : queueSongs;

    if (songs.isEmpty) {
      setQueue(
        type: QueueType.all,
        modified: false,
        // we must save it, so do not `save: false`
      );
    } else if (type == QueueType.persistent) {
      if (persistentQueueId != null &&
          state.albums[persistentQueueId] != null) {
        setQueue(
          type: type,
          modified: modified,
          shuffled: shuffled,
          songs: songs,
          shuffleFrom: queueSongs,
          persistentQueue: state.albums[persistentQueueId],
          save: false,
        );
      } else {
        setQueue(
          type: QueueType.arbitrary,
          shuffled: shuffled,
          songs: songs,
          shuffleFrom: queueSongs,
          save: false,
        );
      }
    } else {
      final arbitraryQueueOrigin = await Prefs.arbitraryQueueOrigin.get();
      setQueue(
        type: type,
        shuffled: shuffled,
        modified: modified,
        songs: songs,
        shuffleFrom: queueSongs,
        searchQuery: await Prefs.searchQueryString.get(),
        arbitraryQueueOrigin: arbitraryQueueOrigin == null
          ? null
          : EnumToString.fromString(
              ArbitraryQueueOrigin.values,
              arbitraryQueueOrigin,
            ),
        save: false,
      );
    }
  }
}
