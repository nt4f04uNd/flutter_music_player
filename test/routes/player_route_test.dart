import 'package:flutter/material.dart';

import '../test.dart';

void main() {
  setUp(() async {
    await setUpAppTest();
  });

  Future<void> expandPlayerRoute(WidgetTester tester) async {
    await tester.tap(find.byType(TrackPanel));
    await tester.pumpAndSettle();
    expect(playerRouteController.value, 1.0);
  }
  
  /// Navigate to the queue screen in the player route.
  Future<void> openQueueScreen(WidgetTester tester) async {
    await expandPlayerRoute(tester);
    await tester.flingFrom(Offset.zero, const Offset(-400.0, 0.0), 1000.0);
    await tester.pumpAndSettle();
  }

  testWidgets('can expand/collapse by tapping the button', (WidgetTester tester) async {
    await tester.runAppTest(() async {
      // Expand the route
      await expandPlayerRoute(tester);

      // Tap collapse button
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();
      expect(playerRouteController.value, 0.0);
    });
  });

  testWidgets('can expand/collapse by flinging', (WidgetTester tester) async {
    await tester.runAppTest(() async {
      // Expand the route with fling
      await tester.fling(find.byType(TrackPanel), const Offset(0.0, -400.0), 1000.0);
      await tester.pumpAndSettle();
      expect(playerRouteController.value, 1.0);

      // Fling to collapse
      await tester.flingFrom(Offset.zero, const Offset(0.0, 400.0), 1000.0);
      await tester.pumpAndSettle();
      expect(playerRouteController.value, 0.0);
    });
  });

  group('queue screen', () {
    testWidgets('can open by swiping to left', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        QueueControl.instance.resetQueue();
        // Expand the route
        await expandPlayerRoute(tester);

        expect(find.text(l10n.upNext), findsNothing);
        await tester.flingFrom(Offset.zero, const Offset(-400.0, 0.0), 1000.0);
        await tester.pumpAndSettle();
        expect(find.text(l10n.upNext), findsOneWidget);
        expect(find.text(l10n.allTracks), findsOneWidget);
      });
    });

    testWidgets('displays search query correctly', (WidgetTester tester) async {
      const query = 'Query';
      await tester.runAppTest(() async {
        QueueControl.instance.setSearchedQueue(query, [songWith()]);
        await openQueueScreen(tester);
        expect(find.text(l10n.upNext), findsOneWidget);
        expect(find.text(l10n.foundByQuery('"$query"'), findRichText: true), findsOneWidget);
      });
    });

    testWidgets('Allows to open the search query from the title', (WidgetTester tester) async {
      const query = 'Query';
      await tester.runAppTest(() async {
        QueueControl.instance.setSearchedQueue(query, [songWith()]);
        await openQueueScreen(tester);
        await tester.tap(find.byIcon(Icons.chevron_right_rounded));
        await tester.pumpAndSettle();
        expect(find.byType(SearchRoute), findsOneWidget);
        final queryTextField = tester.widget<TextField>(find.descendant(
          of: find.byType(SearchRoute),
          matching: find.byType(TextField),
        ));
        expect(queryTextField.controller!.text, query);
        expect(queryTextField.focusNode!.hasFocus, false);
      });
    });
  });

  testWidgets('shows correct track info', (WidgetTester tester) async {
    await tester.runAppTest(() async {
      // Expand the route
      await expandPlayerRoute(tester);

      /// Expect 3 because:
      /// 1 - from [SongTile]
      /// 2 - from [TrackPanel]
      /// 3 - from [PlayerRoute]

      final currentSong = PlaybackControl.instance.currentSong;
      expect(find.text(currentSong.title), findsNWidgets(3));
      /// Use `textContaining`, because [SongTile] adds duration at the end of the artist
      expect(find.textContaining(currentSong.artist), findsNWidgets(3));
      expect(find.byWidgetPredicate(
        (widget) =>
          widget is ContentArt &&
          widget.source == ContentArtSource.song(currentSong)),
        findsNWidgets(4), // PlayerRoute shows two arts and animates between them
      );
    });
  });

  testWidgets('shuffle button works', (WidgetTester tester) async {
    await tester.runAppTest(() async {
      QueueControl.instance.resetQueue();
      // Expand the route
      await expandPlayerRoute(tester);

      expect(QueueControl.instance.state.shuffled, false);
      await tester.tap(find.byType(ShuffleButton));
      expect(QueueControl.instance.state.shuffled, true);
      await tester.tap(find.byType(ShuffleButton));
      expect(QueueControl.instance.state.shuffled, false);
    });
  });

  testWidgets('loop button works', (WidgetTester tester) async {
    await tester.runAppTest(() async {
      // Expand the route
      await expandPlayerRoute(tester);

      expect(MusicPlayer.instance.looping, false);
      await tester.tap(find.byType(LoopButton));
      expect(MusicPlayer.instance.looping, true);
      await tester.tap(find.byType(LoopButton));
      expect(MusicPlayer.instance.looping, false);
    });
  });

  testWidgets('play previous button works', (WidgetTester tester) async {
    final List<Song> songs = List.unmodifiable([
      songWith(id: 0),
      songWith(id: 1),
      songWith(id: 2),
    ]);
    await tester.runAsync(() async {
      await setUpAppTest(() {
        FakeContentChannel.instance.songs = songs.toList();
      });
    });
    PlaybackControl.instance.changeSong(songs[1]);
    await tester.runAppTest(() async {
      // Expand the route
      await expandPlayerRoute(tester);

      expect(PlaybackControl.instance.currentSong, songs[1]);

      await tester.tap(find.byIcon(Icons.skip_previous_rounded));
      expect(PlaybackControl.instance.currentSong, songs.first);

      await tester.tap(find.byIcon(Icons.skip_previous_rounded));
      expect(PlaybackControl.instance.currentSong, songs.last);
    });
  });

  testWidgets('play next button works', (WidgetTester tester) async {
    final List<Song> songs = List.unmodifiable([
      songWith(id: 0),
      songWith(id: 1),
      songWith(id: 2),
    ]);
    await tester.runAsync(() async {
      await setUpAppTest(() {
        FakeContentChannel.instance.songs = songs.toList();
      });
    });
    PlaybackControl.instance.changeSong(songs[1]);
    await tester.runAppTest(() async {
      // Expand the route
      await expandPlayerRoute(tester);

      expect(PlaybackControl.instance.currentSong, songs[1]);

      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      expect(PlaybackControl.instance.currentSong, songs.last);

      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      expect(PlaybackControl.instance.currentSong, songs.first);
    });
  });

  testWidgets('play/pause button works', (WidgetTester tester) async {
    await tester.runAppTest(() async {
      // Expand the route
      await expandPlayerRoute(tester);

      final button = find.descendant(
        of: find.byType(SharedAxisTabView),
        matching: find.byType(AnimatedPlayPauseButton),
      );

      expect(MusicPlayer.instance.playing, false);
      expect(MusicPlayer.handler!.running, false);

      await tester.tap(button);
      expect(MusicPlayer.instance.playing, true);
      expect(MusicPlayer.handler!.running, true);

      await tester.tap(button);
      expect(MusicPlayer.instance.playing, false);
      expect(MusicPlayer.handler!.running, true,
          reason: 'Handler should only stop when stopped, not when paused');

      await tester.pumpAndSettle();
    });
    expect(MusicPlayer.handler!.running, false);
  });
}
