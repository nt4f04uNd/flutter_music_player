import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:home_widget/home_widget.dart';

import '../sweyer.dart';

/// Controller for native app widgets.
class AppWidgetControl extends Control {
  static AppWidgetControl instance = AppWidgetControl();
  @visibleForTesting
  static const appWidgetName = 'MusicPlayerAppWidget';

  StreamSubscription<Song>? currentSongListener;
  StreamSubscription<bool>? playingStateListener;
  /// The last song content uri sent to the widget.
  String? lastSongContentUri;
  /// The last playing state sent to the widget.
  bool? lastPlayingState;

  @override
  void init() {
    super.init();
    lastSongContentUri = null;
    lastPlayingState = null;
    currentSongListener = PlaybackControl.instance.onSongChange
        .listen((song) => update(song, MusicPlayer.instance.playing));
    playingStateListener = MusicPlayer.instance.playingStream.listen(
        (playing) => update(PlaybackControl.instance.currentSong, playing));
  }
  
  @override
  void dispose() {
    currentSongListener?.cancel();
    playingStateListener?.cancel();
    super.dispose();
  }

  /// Update the widgets with the current [song] and [playing] state.
  Future<void> update(Song song, bool playing) async {
    if (playing == lastPlayingState && song.contentUri == lastSongContentUri) {
      return;
    }
    lastSongContentUri = song.contentUri;
    lastPlayingState = playing;
    await HomeWidget.saveWidgetData('song', song.contentUri);
    await HomeWidget.saveWidgetData('playing', playing);
    await HomeWidget.updateWidget(name: appWidgetName);
  }
}
