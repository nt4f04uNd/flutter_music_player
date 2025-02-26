import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../observer/observer.dart';
import '../test.dart';

void main() {
  group('home_route', () {
    late PermissionsChannelObserver permissionsObserver;
    testAppGoldens('permissions_screen', initialization: () {
      permissionsObserver = PermissionsChannelObserver(TestWidgetsFlutterBinding.ensureInitialized());
      permissionsObserver.setPermission(Permission.storage, PermissionStatus.denied);
      permissionsObserver.setPermission(Permission.audio, PermissionStatus.denied);
    }, (WidgetTester tester) async {
      await tester.tap(find.text(l10n.grant));
      await tester.pumpAndSettle();
    });

    testAppGoldens(
      'searching_screen',
      postInitialization: () {
        ContentControl.instance.dispose();
        final fake = FakeContentControl();
        fake.init();
        // Fake ContentControl.init in a way to trigger the home screen rebuild
        fake.initializing = true;
        fake.stateNullable = ContentState();
        fake.disposed.value = false;
      },
      (WidgetTester tester) async {
        expect(find.byType(Spinner), findsOneWidget);
      },
      customGoldenPump: (WidgetTester tester) => tester.pump(const Duration(milliseconds: 400)),
    );

    testAppGoldens('no_songs_screen', initialization: () {
      FakeSweyerPluginPlatform.instance.songs = [];
    }, (WidgetTester tester) async {
      await tester.pumpAndSettle();
    });
  });

  group('tabs_route', () {
    testAppGoldens('drawer', (WidgetTester tester) async {
      await tester.tap(find.byType(AnimatedMenuCloseButton));
      await tester.pumpAndSettle();
    });

    testAppGoldens('songs_tab', (WidgetTester tester) async {
      await tester.pumpAndSettle();
    });

    testAppGoldens('albums_tab', (WidgetTester tester) async {
      await tester.tap(find.byIcon(ContentType.album.icon));
      await tester.pumpAndSettle();
      expect(find.byType(typeOf<PersistentQueueTile<Album>>()), findsOneWidget);
    });

    testAppGoldens('playlists_tab', (WidgetTester tester) async {
      await tester.tap(find.byIcon(ContentType.playlist.icon));
      await tester.pumpAndSettle();
      expect(find.byType(typeOf<PersistentQueueTile<Playlist>>()), findsOneWidget);
    });

    testAppGoldens('artists_tab', (WidgetTester tester) async {
      await tester.tap(find.byIcon(ContentType.artist.icon));
      await tester.pumpAndSettle();
      expect(find.byType(typeOf<ArtistTile>()), findsOneWidget);
    });

    testAppGoldens('sort_feature_dialog', (WidgetTester tester) async {
      await tester.tap(find.text(
        l10n.sortFeature(
          ContentType.song,
          ContentControl.instance.state.sorts.get(ContentType.song).feature,
        ),
      ));
      await tester.pumpAndSettle();
    });

    testAppGoldens('selection_songs_tab', (WidgetTester tester) async {
      await tester.pumpAndSettle();
      await tester.longPress(find.byType(SongTile));
      await tester.pumpAndSettle();
    });

    final List<Song> songs = List.unmodifiable(List.generate(10, (index) => songWith(id: index)));
    testAppGoldens('selection_deletion_dialog_songs_tab', initialization: () {
      final fake = FakeDeviceInfoControl();
      DeviceInfoControl.instance = fake;
      fake.sdkInt = 29;
      FakeSweyerPluginPlatform.instance.songs = songs.toList();
    }, (WidgetTester tester) async {
      await tester.pumpAndSettle();
      await tester.longPress(find.byType(SongTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SelectAllSelectionAction).last);
      await tester.tap(find.byType(DeleteSongsAppBarAction).last);
      await tester.pumpAndSettle();
    });

    testAppGoldens('scroll_labels', initialization: () {
      FakeSweyerPluginPlatform.instance.songs =
          List.generate(26, (index) => songWith(id: index, title: String.fromCharCode('A'.codeUnitAt(0) + index)));
    }, (WidgetTester tester) async {
      ContentControl.instance.sort(contentType: ContentType.song, sort: const SongSort(feature: SongSortFeature.title));
      await tester.pumpAndSettle();

      final listRect = tester.getRect(find.byType(ContentListView).hitTestable());
      final gesture = await tester.startGesture(Offset(listRect.right - 20, listRect.bottom - 20));
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.moveBy(const Offset(0, -20));
      }
      await tester.pumpAndSettle();
      // Do not end the gesture, otherwise the labels will disappear
    });
  });

  group('persistent_queue_route', () {
    testAppGoldens('album_route', initialization: () {
      FakeSweyerPluginPlatform.instance.songs = [
        songWith(id: 0, track: null, title: 'Null Song 1'),
        songWith(id: 5, track: null, title: 'Null Song 2'),
        songWith(id: 3, track: '1', title: 'First Song'),
        songWith(id: 2, track: '2', title: 'Second Song'),
        songWith(id: 4, track: '3', title: 'Third Song'),
        songWith(id: 1, track: '4', title: 'Fourth Song'),
      ];
    }, (WidgetTester tester) async {
      HomeRouter.instance.goto(HomeRoutes.factory.content(albumWith()));
      await tester.pumpAndSettle();
    });

    testAppGoldens('playlist_route', (WidgetTester tester) async {
      HomeRouter.instance.goto(HomeRoutes.factory.content(playlistWith()));
      await tester.pumpAndSettle();
    });
  });

  group('selection_route', () {
    testAppGoldens('selection_route', (WidgetTester tester) async {
      HomeRouter.instance.goto(HomeRoutes.factory.content(playlistWith()));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();
    });

    testAppGoldens('selection_route_settings', (WidgetTester tester) async {
      HomeRouter.instance.goto(HomeRoutes.factory.content(playlistWith()));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(SelectionActionsBar),
        matching: find.byIcon(Icons.settings_rounded),
      ));
      await tester.pumpAndSettle();
    });
  });

  group('artist_route', () {
    testAppGoldens('artist_route', (WidgetTester tester) async {
      HomeRouter.instance.goto(HomeRoutes.factory.content(artistWith()));
      await tester.pumpAndSettle();
    });
  });

  group('artist_content_route', () {
    testAppGoldens('artist_content_route_songs', (WidgetTester tester) async {
      HomeRouter.instance.goto(HomeRoutes.factory.artistContent<Song>(artistWith(), [songWith()]));
      await tester.pumpAndSettle();
    });
  });

  group('player_route', () {
    testAppGoldens(
      'player_route',
      (WidgetTester tester) async {
        await tester.tap(find.byType(SongTile));
        await tester.pump(); // Flush micro-tasks so to flush handling of the tap.
        // Stop the playback to avoid animations when taking the golden screenshot.
        await MusicPlayer.handler!.stop();
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(playerRouteController.value, 1.0);
      },
      playerInterfaceColorStylesToTest: PlayerInterfaceColorStyle.values.toSet(),
    );

    testAppGoldens('queue_route', (WidgetTester tester) async {
      await tester.openPlayerQueueScreen();
    }, playerInterfaceColorStylesToTest: PlayerInterfaceColorStyle.values.toSet());

    testAppGoldens('queue_route_selection', (WidgetTester tester) async {
      await tester.openPlayerQueueScreen();
      await tester.longPress(find.descendant(
        of: find.byType(PlayerRoute),
        matching: find.byType(SongTile),
      ));
    }, playerInterfaceColorStylesToTest: PlayerInterfaceColorStyle.values.toSet());
  });

  group('search_route', () {
    testAppGoldens('search_suggestions_empty', (WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
    });

    testAppGoldens('search_suggestions', (WidgetTester tester) async {
      SearchHistory.instance.add('entry_1');
      SearchHistory.instance.add('entry_2');
      SearchHistory.instance.add('entry_3');
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
    });

    testAppGoldens('search_suggestions_delete', (WidgetTester tester) async {
      SearchHistory.instance.add('entry_1');
      SearchHistory.instance.add('entry_2');
      SearchHistory.instance.add('entry_3');
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_sweep_rounded));
      await tester.pumpAndSettle();
    });

    testAppGoldens('results', (WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 't');
      await tester.pumpAndSettle();
    });

    testAppGoldens('results_empty', (WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'some_query');
      await tester.pumpAndSettle();
    });
  });

  group('settings_route', () {
    testAppGoldens('settings_route', (WidgetTester tester) async {
      await tester.tap(find.byType(AnimatedMenuCloseButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.settings));
      await tester.pumpAndSettle();
    });

    testAppGoldens('general_settings_route', (WidgetTester tester) async {
      await tester.tap(find.byType(AnimatedMenuCloseButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.general));
      await tester.pumpAndSettle();
    });

    final localFavoriteAndMediaStoreSong = songWith(id: 1, isFavoriteInMediaStore: true);
    final localFavoriteButNotInMediaStoreSong = songWith(id: 2, title: 'Local only favorite');
    final mediaStoreFavoriteButNotLocalSong =
        songWith(id: 3, isFavoriteInMediaStore: true, title: 'MediaStore only favorite');
    testAppGoldens('general_settings_favorite_conflict_dialog', initialization: () {
      FakeSweyerPluginPlatform.instance.songs = [
        songWith(),
        localFavoriteAndMediaStoreSong,
        localFavoriteButNotInMediaStoreSong,
        mediaStoreFavoriteButNotLocalSong,
      ];
    }, (WidgetTester tester) async {
      await Settings.useMediaStoreForFavoriteSongs.set(false);
      await tester.pumpAndSettle(); // Wait for the listener in FavoriteControl to execute
      await FakeFavoritesControl.instance.setFavorite(
        contentTuple: ContentTuple(songs: [localFavoriteAndMediaStoreSong, localFavoriteButNotInMediaStoreSong]),
        value: true,
      );
      await FakeFavoritesControl.instance.setFavorite(
        contentTuple: ContentTuple(songs: [mediaStoreFavoriteButNotLocalSong]),
        value: false,
      );
      await tester.tap(find.byType(AnimatedMenuCloseButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.general));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.useMediaStoreForFavoriteSongsSetting));
      await tester.pumpAndSettle();
    });

    testAppGoldens('theme_settings_route', (WidgetTester tester) async {
      await tester.tap(find.byType(AnimatedMenuCloseButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.theme));
      await tester.pumpAndSettle();
    });

    testAppGoldens('licenses_route', (WidgetTester tester) async {
      await tester.tap(find.byType(AnimatedMenuCloseButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Licenses'));
      await tester.pumpAndSettle();
    });

    testAppGoldens('license_details_route', (WidgetTester tester) async {
      await tester.tap(find.byType(AnimatedMenuCloseButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Licenses'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('test_package'));
      await tester.pumpAndSettle();
    });
  });
}
