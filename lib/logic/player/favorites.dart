import 'dart:async';

import 'package:android_content_provider/android_content_provider.dart';
import 'package:collection/collection.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sweyer/sweyer.dart';

@visibleForTesting
class FavoritesRepository {
  final serializersMap = ContentMap<IntSerializerType>.fromFactory(
    (contentType) => IntListSerializer('favorites_${contentType.name}.json'),
  );
}

class FavoritesControl with Control {
  static FavoritesControl instance = FavoritesControl();

  @visibleForTesting
  final repository = FavoritesRepository();

  final _favoriteSetsMap = ContentMap.fromFactory((contentType) => <int>{});

  bool _useMediaStoreFavorites(ContentType contentType) =>
      contentType == ContentType.song &&
      DeviceInfoControl.instance.useScopedStorageForFileModifications &&
      Settings.useMediaStoreForFavoriteSongs.value;

  MediaStoreContentObserver? _mediaStoreContentObserver;

  @override
  Future<void> init() async {
    super.init();
    _showOnlyFavoritesNotifier.value = false;
    for (final contentType in ContentType.values) {
      await _initContentType(contentType);
    }
    _registerMediaStoreObserver();
    Settings.useMediaStoreForFavoriteSongs.addListener(_useMediaStoreForFavoriteSongsListener);
  }

  @override
  void dispose() {
    for (var element in _favoriteSetsMap.entries) {
      element.value.clear();
    }
    _disposeMediaStoreObserver();
    Settings.useMediaStoreForFavoriteSongs.removeListener(_useMediaStoreForFavoriteSongsListener);
    super.dispose();
  }

  Future<void> _initContentType(ContentType contentType, {bool displayDialogOnConflict = false}) async {
    final Set<int> favoriteSet = {};
    if (_useMediaStoreFavorites(contentType)) {
      for (final song in ContentControl.instance.state.allSongs.songs) {
        if (song.isFavoriteInMediaStore ?? false) {
          favoriteSet.add(song.sourceId);
        }
      }
      if (displayDialogOnConflict && !await _resolveConflictsOnSwitchingToMediaStore(favoriteSet)) {
        return;
      }
    } else {
      final serializer = repository.serializersMap.get(contentType);
      await serializer.init();
      final savedIds = await serializer.read();
      favoriteSet.addAll(savedIds);
    }
    _favoriteSetsMap.set(favoriteSet, key: contentType);
  }

  /// Let the user resolve any conflicts between the current favorite state and the MediaStore state.
  /// The [favoritesInMediaStore] are the source ids of the songs that are currently marked as favorites in the
  /// MediaStore. The list will be updated if the user decides to mark more favorites or un-mark some favorites.
  /// Returns `true` if the conflicts were resolved successfully, `false` if the user decided to cancel.
  Future<bool> _resolveConflictsOnSwitchingToMediaStore(Set<int> favoritesInMediaStore) async {
    final previousFavorites = _favoriteSetsMap.get(ContentType.song);
    final newFavoritesFromMediaStore = favoritesInMediaStore
        .difference(previousFavorites)
        .map((id) =>
            ContentControl.instance.getContent(ContentType.song).firstWhereOrNull((song) => song.sourceId == id))
        .whereType<Song>() // Filter unknown songs
        .toSet();
    final newFavoritesFromLocalStore = previousFavorites
        .difference(favoritesInMediaStore)
        .map((id) =>
            ContentControl.instance.getContent(ContentType.song).firstWhereOrNull((song) => song.sourceId == id))
        .whereType<Song>() // Filter unknown songs
        .toSet();
    if (newFavoritesFromMediaStore.isNotEmpty || newFavoritesFromLocalStore.isNotEmpty) {
      final context = AppRouter.instance.navigatorKey.currentContext;
      if (context != null) {
        final chosenFavorites =
            await _showFavoriteConflictDialog(context, newFavoritesFromLocalStore, newFavoritesFromMediaStore);
        if (chosenFavorites == null) {
          await Settings.useMediaStoreForFavoriteSongs.set(false);
          return false;
        }
        final songsToUnfavor = newFavoritesFromMediaStore.difference(chosenFavorites);
        final songsToFavor = chosenFavorites.difference(newFavoritesFromMediaStore);
        if (songsToUnfavor.isNotEmpty) {
          await ContentControl.instance.setSongsFavorite(songsToUnfavor, false);
          favoritesInMediaStore.removeAll(songsToUnfavor.map((song) => song.sourceId));
        }
        if (songsToFavor.isNotEmpty) {
          await ContentControl.instance.setSongsFavorite(songsToFavor, true);
          favoritesInMediaStore.addAll(songsToFavor.map((song) => song.sourceId));
        }
      }
    }
    return true;
  }

  /// Show a dialog to allow the user to choose which of the given songs should be marked as favorites.
  /// The [favorites] will be marked as favorites in the beginning, the [unfavored] will not.
  /// Returns the set of songs that the user has chosen as favorites.
  Future<Set<Song>?> _showFavoriteConflictDialog(
      BuildContext context, Iterable<Song> favorites, Iterable<Song> unfavored) async {
    final l10n = getl10n(context);
    final theme = Theme.of(context);
    Set<Song> chosenFavorites = favorites.toSet();
    final didChoose = await ShowFunctions.instance.showDialog<bool>(
          context,
          ui: theme.systemUiThemeExtension.modalOverGrey,
          title: Text(l10n.resolveConflict),
          titlePadding: defaultAlertTitlePadding.copyWith(top: 20.0),
          contentPadding: const EdgeInsets.only(top: 5.0, bottom: 10.0),
          acceptButton: AppButton.pop(
            text: l10n.accept,
            popResult: true,
          ),
          content: StatefulBuilder(builder: (context, setState) {
            void toggleSong(Song song) => setState(() {
                  chosenFavorites.contains(song) ? chosenFavorites.remove(song) : chosenFavorites.add(song);
                });
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(l10n.conflictExplanation),
                  ),
                  for (final song in favorites.followedBy(unfavored))
                    SongTile(
                      song: song,
                      enableDefaultOnTap: false,
                      onTap: () => toggleSong(song),
                      showFavoriteIndicator: false,
                      trailing: HeartButton(active: chosenFavorites.contains(song), onPressed: () => toggleSong(song)),
                    ),
                ],
              ),
            );
          }),
        ) ??
        false;
    return didChoose ? chosenFavorites : null;
  }

  Future<void> _useMediaStoreForFavoriteSongsListener() async {
    final useMediaStore = Settings.useMediaStoreForFavoriteSongs.value;
    if (useMediaStore) {
      _registerMediaStoreObserver();
    } else {
      _disposeMediaStoreObserver();
      await _saveRepository(ContentType.song);
    }
    await _initContentType(ContentType.song, displayDialogOnConflict: useMediaStore);
    ContentControl.instance.emitContentChange();
  }

  /// Save the [newFavorites] of the [contentType] to the local database.
  /// If [newFavorites] is omitted, save the current state of the favorite map to the database.
  Future<void> _saveRepository(ContentType contentType, {List<int>? newFavorites}) async {
    newFavorites ??= _favoriteSetsMap.get(contentType).toList(growable: false);
    final serializer = repository.serializersMap.get(contentType);
    await serializer.save(newFavorites);
  }

  void _registerMediaStoreObserver() {
    if (!_useMediaStoreFavorites(ContentType.song)) {
      return;
    }
    _mediaStoreContentObserver = MediaStoreContentObserver(ContentType.song)
      ..onChangeStream.listen(_handleMediaStoreSongsChange)
      ..register();
  }

  void _disposeMediaStoreObserver() {
    _endMediaStoreUpdate();
    _mediaStoreContentObserver?.dispose();
    _mediaStoreContentObserver = null;
  }

  static const _mediaStoreUpdateDebounceInterval = Duration(milliseconds: 200);
  Timer? _mediaStoreUpdateTimer;
  void _endMediaStoreUpdate() {
    _mediaStoreUpdateTimer?.cancel();
    _mediaStoreUpdateTimer = null;
  }

  void _handleMediaStoreSongsChange(MediaStoreContentChangeEvent event) {
    if (event.flags & AndroidContentResolver.NOTIFY_UPDATE != 0) {
      _mediaStoreUpdateTimer?.cancel();
      _mediaStoreUpdateTimer = Timer(_mediaStoreUpdateDebounceInterval, () async {
        _endMediaStoreUpdate();
        await ContentControl.instance.refetch(ContentType.song);
        final favoriteSet = _favoriteSetsMap.get(ContentType.song);
        for (final song in ContentControl.instance.state.allSongs.songs) {
          if ((song.isFavoriteInMediaStore ?? false) && !favoriteSet.contains(song.id)) {
            favoriteSet.add(song.id);
          } else if (!(song.isFavoriteInMediaStore ?? false) && favoriteSet.contains(song.id)) {
            favoriteSet.remove(song.id);
          }
        }
      });
    }
  }

  ValueListenable<bool> get onShowOnlyFavorites => _showOnlyFavoritesNotifier;
  final ValueNotifier<bool> _showOnlyFavoritesNotifier = ValueNotifier(false);

  /// Whether tabs route currently should filter and only show favorite content.
  bool get showOnlyFavorites => _showOnlyFavoritesNotifier.value;

  void toggleShowOnlyFavorites() {
    _showOnlyFavoritesNotifier.value = !_showOnlyFavoritesNotifier.value;
  }

  /// Whether the given [content] is favorite.
  bool isFavorite<T extends Content>(T content) {
    final favoriteSet = _favoriteSetsMap.get(content.type);
    if (content is Song) {
      return favoriteSet.contains(content.sourceId);
    }
    return favoriteSet.contains(content.id);
  }

  /// Sets whether a given tuple of content is favorite.
  Future<void> setFavorite({
    required ContentTuple contentTuple,
    required bool value,
  }) async {
    for (final contentType in ContentType.values) {
      final contentList = contentTuple.get(contentType);
      final newFavoriteSet = _favoriteSetsMap.get(contentType).toSet();
      Iterable<int> ids;
      if (contentType == ContentType.song) {
        ids = (contentList as List<Song>).map((el) => el.sourceId);
      } else {
        ids = contentList.map((el) => el.id);
      }

      if (ids.isEmpty) {
        continue;
      }

      if (value) {
        newFavoriteSet.addAll(ids);
      } else {
        newFavoriteSet.removeAll(ids);
      }

      try {
        if (_useMediaStoreFavorites(contentType)) {
          final songs = (contentList as List<Song>).toSet();
          await ContentControl.instance.setSongsFavorite(songs, value);
        } else {
          _saveRepository(contentType, newFavorites: newFavoriteSet.toList());
        }
        _favoriteSetsMap.set(newFavoriteSet, key: contentType);
        ContentControl.instance.emitContentChange();
        QueueControl.instance.emitQueueChange();
      } catch (ex, stack) {
        FirebaseCrashlytics.instance.recordError(
          ex,
          stack,
          reason: 'in setFavorite',
        );
        ShowFunctions.instance.showToast(
          msg: staticl10n.oopsErrorOccurred,
        );
        debugPrint('setFavorite error: $ex');
      }
    }
  }

  /// Switches current song favorite status.
  Future<void> toggleFavoriteCurrentSong() {
    final currentSong = PlaybackControl.instance.currentSong;
    return FavoritesControl.instance.setFavorite(
      contentTuple: ContentTuple(
        songs: [currentSong],
      ),
      value: !currentSong.isFavorite,
    );
  }
}
