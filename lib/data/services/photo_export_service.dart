import 'dart:io';

import 'package:gal/gal.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/photo_model.dart';

class PhotoExportResult {
  final int successCount;
  final int failCount;

  const PhotoExportResult({
    required this.successCount,
    required this.failCount,
  });
}

class PhotoExportService {
  Future<bool> exportPhoto(PhotoModel photo,
      {required String albumName}) async {
    try {
      File? source;
      if (photo.mediaId != null) {
        final entity = await AssetEntity.fromId(photo.mediaId!);
        source = entity == null ? null : await entity.file;
      } else if (photo.localPath.isNotEmpty) {
        final file = File(photo.localPath);
        if (await file.exists()) source = file;
      }
      if (source == null) return false;
      await Gal.putImage(source.path, album: _safeAlbumName(albumName));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<PhotoExportResult> exportPhotos({
    required List<PhotoModel> photos,
    required String albumName,
    void Function(int current, int total)? onProgress,
  }) async {
    var successCount = 0;
    var failCount = 0;
    for (var i = 0; i < photos.length; i++) {
      final success = await exportPhoto(photos[i], albumName: albumName);
      success ? successCount++ : failCount++;
      onProgress?.call(i + 1, photos.length);
    }
    return PhotoExportResult(
      successCount: successCount,
      failCount: failCount,
    );
  }

  String _safeAlbumName(String value) {
    final safe = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return safe.isEmpty ? '相册分类' : '相册分类-$safe';
  }
}
