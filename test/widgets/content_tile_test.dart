import '../test.dart';

void main() {
  testWidgets('SongTile - tapping opens player route', (WidgetTester tester) async {
    await tester.runAppTest(() async {
      expect(MusicPlayer.handler!.running, false);
      await tester.tap(find.byType(SongTile));
      expect(MusicPlayer.handler!.running, true);
      await tester.pump(); // Flush micro-tasks so to flush handling of the tap.
      // Don't use `pumpAndSettle` because we have animations because we are playing a song.
      await tester.pump(const Duration(seconds: 1));
      expect(playerRouteController.value, 1.0);
      expect(MusicPlayer.handler!.running, true);
    });
  });

  testWidgets('AlbumTile - tapping opens album route', (WidgetTester tester) async {
    await tester.runAppTest(() async {
      // Open albums tab
      await tester.tap(find.byIcon(ContentType.album.icon));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(typeOf<PersistentQueueTile<Album>>()));
      await tester.pumpAndSettle();
      final route = tester.widget<PersistentQueueRoute>(find.byType(typeOf<PersistentQueueRoute>()));
      expect(route.arguments, isA<PersistentQueueArguments<Album>>());
    });
  });

  testWidgets('PlaylistTile - tapping opens playlist route', (WidgetTester tester) async {
    await tester.runAppTest(() async {
      // Open playlists tab
      await tester.tap(find.byIcon(ContentType.playlist.icon));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(typeOf<PersistentQueueTile<Playlist>>()));
      await tester.pumpAndSettle();
      final route = tester.widget<PersistentQueueRoute>(find.byType(typeOf<PersistentQueueRoute>()));
      expect(route.arguments, isA<PersistentQueueArguments<Playlist>>());
    });
  });

  testWidgets('ArtistTile - tapping opens artist route', (WidgetTester tester) async {
    await tester.runAppTest(() async {
      // Open artists tab
      await tester.tap(find.byIcon(ContentType.artist.icon));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(typeOf<ArtistTile>()));
      await tester.pumpAndSettle();
      expect(find.byType(typeOf<ArtistRoute>()), findsOneWidget);
    });
  });
}
