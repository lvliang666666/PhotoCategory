import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AlbumArchiveResult {
  final String path;
  final int includedCount;
  final int skippedCount;

  const AlbumArchiveResult({
    required this.path,
    required this.includedCount,
    required this.skippedCount,
  });
}

class AlbumArchiveService {
  static const _channel = MethodChannel('com.photostorer.photo_storer/archive');

  Future<AlbumArchiveResult> createArchive({
    required String albumName,
    required List<String> photoPaths,
  }) async {
    final readablePaths = <String>[];
    for (final path in photoPaths) {
      if (path.isNotEmpty && await File(path).exists()) readablePaths.add(path);
    }
    if (readablePaths.isEmpty) {
      throw const FileSystemException('相册中的照片文件均不可用');
    }

    final tempDirectory = await getTemporaryDirectory();
    final safeName = albumName
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = p.join(
      tempDirectory.path,
      '相册分类-${safeName.isEmpty ? '相册' : safeName}-$timestamp.zip',
    );
    final response = await _channel.invokeMapMethod<String, dynamic>(
      'createZip',
      {'paths': readablePaths, 'outputPath': outputPath},
    );
    if (response == null || response['path'] is! String) {
      throw const FileSystemException('创建压缩包失败');
    }
    return AlbumArchiveResult(
      path: response['path'] as String,
      includedCount: (response['includedCount'] as num?)?.toInt() ?? 0,
      skippedCount: (response['skippedCount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> shareArchive(AlbumArchiveResult archive, String albumName) {
    return SharePlus.instance.share(
      ShareParams(
        files: [XFile(archive.path, mimeType: 'application/zip')],
        title: '导出相册「$albumName」',
        text: '相册「$albumName」压缩包',
      ),
    );
  }
}
