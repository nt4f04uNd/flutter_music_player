/*---------------------------------------------------------------------------------------------
*  Copyright (c) nt4f04und. All rights reserved.
*  Licensed under the BSD-style license. See LICENSE in the project root for license information.
*--------------------------------------------------------------------------------------------*/

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'package:sweyer/sweyer.dart';
import 'package:sweyer/constants.dart' as Constants;

class Seekbar extends StatefulWidget {
  const Seekbar({
    Key? key,
    this.color,
    this.player,
    this.duration,
  }) : super(key: key);

  /// Color of the actove slider part.
  /// 
  /// If non specified [ColorScheme.primary] color will be used.
  final Color? color;

  /// Player to use instead of [MusicPlayer], which is used by default.
  final AudioPlayer? player;

  /// Predefined duration to use.
  final Duration? duration;

  @override
  _SeekbarState createState() => _SeekbarState();
}

class _SeekbarState extends State<Seekbar> {
  // Duration of playing track.
  Duration _duration = Duration.zero;

  /// Actual track position value.
  double _value = 0.0;

  /// Value to perform drag.
  late double _localValue;

  /// Is user dragging slider right now.
  bool _isDragging = false;

  /// Value to work with.
  double? get workingValue => _isDragging ? _localValue : _value;

  late StreamSubscription<Duration> _positionSubscription;
  StreamSubscription<Song>? _songChangeSubscription;

  AudioPlayer get player => widget.player ?? MusicPlayer.instance;

  @override
  void initState() {
    super.initState();
    final duration = widget.duration ?? player.duration;
    if (duration != null) {
      _duration = duration;
    }
    _value = _positionToValue(player.position);
    // Handle track position movement
    _positionSubscription = player.positionStream.listen((position) {
      if (!_isDragging) {
        setState(() {
          _value = _positionToValue(position);
        });
      }
    });
    if (widget.player == null) {
      // Handle track switch
      _songChangeSubscription = ContentControl.state.onSongChange.listen((song) {
        setState(() {
          _isDragging = false;
          _localValue = 0.0;
          // Not setting to 0, because even though I'm intializing player in proper order, i.e.
          // set song and then seek to needed position, it still fires in reverse, not sure why.
          _value = _positionToValue(MusicPlayer.instance.position);
          _duration = Duration(milliseconds: song.duration);
        });
      });
    }
  }

  @override
  void dispose() {
    _positionSubscription.cancel();
    _songChangeSubscription?.cancel();
    super.dispose();
  }

  double _positionToValue(Duration position) {
    return (position.inMilliseconds / math.max(_duration.inMilliseconds, 1)).clamp(0.0, 1.0);
  }

  // Drag functions
  void _handleChangeStart(double newValue) {
    setState(() {
      _isDragging = true;
      _localValue = newValue;
    });
  }

  void _handleChanged(double newValue) {
    setState(() {
      if (!_isDragging)
        _isDragging = true;
      _localValue = newValue;
    });
  }

  /// TODO: https://github.com/nt4f04uNd/sweyer/issues/6
  Future<void> _handleChangeEnd(double newValue) async {
    await player.seek(_duration * newValue);
    if (mounted) {
      setState(() {
        _isDragging = false;
        _value = newValue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? ThemeControl.theme.colorScheme.primary;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    final scaleFactor = textScaleFactor == 1.0 ? 1.0 : textScaleFactor * 1.1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 36.0 * scaleFactor,
            transform: Matrix4.translationValues(5.0, 0.0, 0.0),
            child: Text(
              formatDuration(_duration * workingValue!),
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w700,
                color: ThemeControl.theme.textTheme.headline6!.color,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2.0,
                thumbColor: color,
                overlayColor: color.withOpacity(0.12),
                activeTrackColor:color,
                inactiveTrackColor: Constants.Theme.sliderInactiveColor.auto,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7.5,
                ),
              ),
              child: Slider(
                value: _isDragging ? _localValue : _value,
                onChangeStart: _handleChangeStart,
                onChanged: _handleChanged,
                onChangeEnd: _handleChangeEnd,
              ),
            ),
          ),
          Container(
            width: 36.0 * scaleFactor,
            transform: Matrix4.translationValues(-5.0, 0.0, 0.0),
            child: Text(
              formatDuration(_duration),
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w700,
                color: ThemeControl.theme.textTheme.headline6!.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
