/*---------------------------------------------------------------------------------------------
*  Copyright (c) nt4f04und. All rights reserved.
*  Licensed under the BSD-style license. See LICENSE in the project root for license information.
*--------------------------------------------------------------------------------------------*/

import 'package:sweyer/sweyer.dart';

/// Represents some content in the app (songs, album, etc).
///
/// Each type of content have an approprate [Sort]s implemented.
///
/// See also:
/// * [ContentType], a list of all content types.
abstract class Content {
  /// Enumerates all the types of content (derived from this class).
  static List<Type> enumerate() => [Song, Album];
}
