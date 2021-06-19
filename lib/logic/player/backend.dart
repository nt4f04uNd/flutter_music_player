/*---------------------------------------------------------------------------------------------
*  Copyright (c) nt4f04und. All rights reserved.
*  Licensed under the BSD-style license. See LICENSE in the project root for license information.
*--------------------------------------------------------------------------------------------*/

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// [Backend.getArtistInfo] response.
class GetArtistInfoResponse {
  /// Artist image url.
  final String? imageUrl;

  GetArtistInfoResponse({required this.imageUrl});

  factory GetArtistInfoResponse.fromMap(Map map) {
    return GetArtistInfoResponse(imageUrl: map['imageUrl']);
  }
}

/// A namespace for connection methods with the backend.
///
/// Backend source code is avilable here https://github.com/nt4f04uNd/sweyer-backend.
abstract class Backend {
  static const _version = 1;
  static const _cacheKey = 'backend';

  static final _cacheManager = CacheManager(
    Config(
      _cacheKey,
      maxNrOfCacheObjects: 500,
      fileService: _ArtistInfoFileService(version: _version),
    ),
  );

  /// Calls to the backend to find the info about artist.
  static Future<GetArtistInfoResponse> getArtistInfo(String name) async {
    final file = await _cacheManager.getSingleFile(name);
    if (!file.existsSync())
      return GetArtistInfoResponse(imageUrl: null);
    return GetArtistInfoResponse.fromMap(jsonDecode(await file.readAsString()));
  }
}

class _ArtistInfoFileService extends FileService {
  _ArtistInfoFileService({required this.version});
  final int version;

  @override
  Future<FileServiceResponse> get(String url, {Map<String, String>? headers}) async {
    final function = FirebaseFunctions.instance.httpsCallable('getArtistInfo');
    try {
      final result = await function.call({
        'version': version,
        'name': url,
      });
      return _ArtistInfoServiceResponse(result.data);
    } on FirebaseFunctionsException catch (ex) {
      if (ex.code == 'unknown') {
        return _ArtistInfoServiceResponse(null);
      } else {
        rethrow;
      }
    }
  }
}

class _ArtistInfoServiceResponse extends FileServiceResponse {
  _ArtistInfoServiceResponse(this.data);
  final Map? data;

  final DateTime _receivedTime = clock.now();

  @override
  Stream<List<int>> get content => Stream.value(utf8.encode(jsonEncode(data)));

  @override
  int? get contentLength => null;

  @override
  String? get eTag => null;

  @override
  String get fileExtension => '';

  @override
  int get statusCode => data == null ? 404 : 200;

  @override
  DateTime get validTill => _receivedTime.add(const Duration(days: 3));

}
