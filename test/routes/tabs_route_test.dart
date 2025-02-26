import 'package:flutter/material.dart';

import '../test.dart';

void main() {
  testWidgets('tabs - can switch with swipe', (WidgetTester tester) async {
    await tester.runAppTest(() async {
      // Songs tab
      expect(find.byType(SongTile), findsOneWidget);
      expect(find.byType(typeOf<PersistentQueueTile<Album>>()), findsNothing);
      expect(find.byType(typeOf<PersistentQueueTile<Playlist>>()), findsNothing);
      expect(find.byType(ArtistTile), findsNothing);

      await tester.fling(find.byType(TabBarView), const Offset(-400.0, 0.0), 1000.0);
      await tester.pumpAndSettle();

      // Albums tab
      expect(find.byType(SongTile), findsNothing);
      expect(find.byType(typeOf<PersistentQueueTile<Album>>()), findsOneWidget);
      expect(find.byType(typeOf<PersistentQueueTile<Playlist>>()), findsNothing);
      expect(find.byType(ArtistTile), findsNothing);

      await tester.fling(find.byType(TabBarView), const Offset(-400.0, 0.0), 1000.0);
      await tester.pumpAndSettle();

      // Playlists tab
      expect(find.byType(SongTile), findsNothing);
      expect(find.byType(typeOf<PersistentQueueTile<Album>>()), findsNothing);
      expect(find.byType(typeOf<PersistentQueueTile<Playlist>>()), findsOneWidget);
      expect(find.byType(ArtistTile), findsNothing);

      await tester.fling(find.byType(TabBarView), const Offset(-400.0, 0.0), 1000.0);
      await tester.pumpAndSettle();

      // Artists tab
      expect(find.byType(SongTile), findsNothing);
      expect(find.byType(typeOf<PersistentQueueTile<Album>>()), findsNothing);
      expect(find.byType(typeOf<PersistentQueueTile<Playlist>>()), findsNothing);
      expect(find.byType(ArtistTile), findsOneWidget);
    });
  });

  testWidgets('tabs - can switch with buttons', (WidgetTester tester) async {
    await tester.runAppTest(() async {
      // Start from songs tab
      expect(find.byType(SongTile), findsOneWidget);

      // Switch to albums tab
      await tester.tap(find.byIcon(ContentType.album.icon));
      await tester.pumpAndSettle();
      expect(find.byType(typeOf<PersistentQueueTile<Album>>()), findsOneWidget);

      // Switch to playlists tab
      await tester.tap(find.byIcon(ContentType.playlist.icon));
      await tester.pumpAndSettle();
      expect(find.byType(typeOf<PersistentQueueTile<Playlist>>()), findsOneWidget);

      // Switch to artists tab
      await tester.tap(find.byIcon(ContentType.artist.icon));
      await tester.pumpAndSettle();
      expect(find.byType(typeOf<ArtistTile>()), findsOneWidget);

      // Switch back to songs tab
      await tester.tap(find.byIcon(ContentType.song.icon));
      await tester.pumpAndSettle();
      expect(find.byType(typeOf<SongTile>()), findsOneWidget);
    });
  });

  testWidgets('sort order button works', (WidgetTester tester) async {
    final List<Song> songs = List.unmodifiable([
      songWith(id: 0, dateModified: 2),
      songWith(id: 1, dateModified: 1),
      songWith(id: 2, dateModified: 0),
    ]);
    await tester.runAppTest(initialization: () {
      FakeSweyerPluginPlatform.instance.songs = songs.toList();
    }, () async {
      tester.expectSongTiles(songs);

      // Change sort order
      await tester.tap(find.byIcon(Icons.south_rounded));
      await tester.pump();
      tester.expectSongTiles(songs.reversed);
    });
  });

  testWidgets('sort feature button works', (WidgetTester tester) async {
    final List<Song> songs = List.unmodifiable([
      songWith(id: 0, dateModified: 2, title: 'c'),
      songWith(id: 1, dateModified: 1, title: 'b'),
      songWith(id: 2, dateModified: 0, title: 'a'),
    ]);
    await tester.runAppTest(initialization: () {
      FakeSweyerPluginPlatform.instance.songs = songs.toList();
    }, () async {
      tester.expectSongTiles(songs);

      // Change sort feature
      await tester.tap(find.text(l10n.sortFeature(ContentType.song, SongSortFeature.dateModified)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.sortFeature(ContentType.song, SongSortFeature.title)));
      await tester.pump();
      tester.expectSongTiles(songs.reversed);
    });
  });

  testWidgets('displays correct songs length', (WidgetTester tester) async {
    final List<Song> songs = List.unmodifiable([
      songWith(id: 0),
      songWith(id: 1),
      songWith(id: 2),
    ]);
    await tester.runAppTest(initialization: () {
      FakeSweyerPluginPlatform.instance.songs = songs.toList();
    }, () async {
      tester.expectSongTiles(songs);
      expect(find.text(l10n.tracksPlural(3)), findsOneWidget);

      // Change songs length
      ContentControl.instance.state.allSongs.songs.removeLast();
      ContentControl.instance.emitContentChange();
      await tester.pump();

      tester.expectSongTiles(songs.toList()..removeLast());
      expect(find.text(l10n.tracksPlural(2)), findsOneWidget);
    });
  });
}
