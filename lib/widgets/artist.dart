import 'package:sweyer/sweyer.dart';
import 'package:flutter/material.dart';

/// Component to show artist, or automatically show 'Unknown artist' instead of '<unknown>'
class ArtistWidget extends StatelessWidget {
  const ArtistWidget({
    Key? key,
    required this.artist,
    this.trailingText,
    this.overflow = TextOverflow.ellipsis,
    this.textStyle,
  }) : super(key: key);

  final String artist;
  /// If not null, this text will be shown after appended dot.
  final String? trailingText;
  final TextOverflow overflow;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final l10n = getl10n(context);
    final localizedArtist = ContentUtils.localizedArtist(artist, l10n);
    final style = Theme.of(context).textTheme.subtitle2!.merge(textStyle);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            localizedArtist,
            overflow: overflow,
            style: style,
          ),
        ),
        if (trailingText != null)
          Text(
            ' ${ContentUtils.dot} $trailingText',
            style: style,
          ),
      ],
    );
  }
}
