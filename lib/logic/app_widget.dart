import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:home_widget/home_widget.dart';

import '../sweyer.dart';

/// Controller for native app widgets.
class AppWidgetControl extends Control {
  static AppWidgetControl instance = AppWidgetControl();
  @visibleForTesting
  static const appWidgetName = 'MusicPlayerAppWidget';
  static const _songUriKey = 'song';
  static const _playingKey = 'playing';

  StreamSubscription<Song>? _currentSongListener;
  StreamSubscription<bool>? _playingStateListener;

  /// The last song content uri sent to the widget.
  String? _lastSongContentUri;

  /// The last playing state sent to the widget.
  bool? _lastPlayingState;

  @override
  void init() {
    super.init();
    _lastSongContentUri = null;
    _lastPlayingState = null;
    _currentSongListener =
        PlaybackControl.instance.onSongChange.listen((song) => update(song, MusicPlayer.instance.playing));
    _playingStateListener =
        MusicPlayer.instance.playingStream.listen((playing) => update(PlaybackControl.instance.currentSong, playing));
  }

  @override
  void dispose() {
    _currentSongListener?.cancel();
    _playingStateListener?.cancel();
    super.dispose();
  }

  /// Update the widgets with the current [song] and [playing] state.
  Future<void> update(Song song, bool playing) async {
    if (playing == _lastPlayingState && song.contentUri == _lastSongContentUri) {
      return;
    }
    _lastSongContentUri = song.contentUri;
    _lastPlayingState = playing;
    await HomeWidget.saveWidgetData(_songUriKey, song.contentUri);
    await HomeWidget.saveWidgetData(_playingKey, playing);
    await HomeWidget.updateWidget(name: appWidgetName);
  }
}
