import 'dart:io';
import 'dart:ui' as ui;

import 'package:exif/exif.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/file_utils.dart';
import '../models/photo_model.dart';
import '../repositories/photo_repository.dart';

class PhotoImportResult {
  final int successCount;
  final int failCount;
  final List<String> errors;

  const PhotoImportResult({
    required this.successCount,
    required this.failCount,
    required this.errors,
  });
}

class PhotoImportService {
  static const _imageCompatibilityChannel =
      MethodChannel('com.photostorer.photo_storer/image_compat');
  final PhotoRepository _photoRepository = PhotoRepository();

  /// Import multiple photos into a theme.
  /// Each photo is processed sequentially: copy file → read EXIF → insert DB.
  /// Failures on individual photos do not abort the entire batch.
  Future<PhotoImportResult> importPhotos({
    required List<String> sourcePaths,
    required int themeId,
    Iterable<int> additionalThemeIds = const [],
    void Function(int current, int total)? onProgress,
  }) async {
    int successCount = 0;
    int failCount = 0;
    final errors = <String>[];

    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = p.join(appDir.path, AppConstants.photosDirName);
    await FileUtils.ensureDirectory(photosDir);

    for (int i = 0; i < sourcePaths.length; i++) {
      final sourcePath = sourcePaths[i];
      String? importedPath;
      onProgress?.call(i + 1, sourcePaths.length);

      try {
        final sourceFile = File(sourcePath);
        if (!await sourceFile.exists()) {
          failCount++;
          errors.add('文件不存在: ${p.basename(sourcePath)}');
          continue;
        }

        final uniqueName =
            FileUtils.generateUniqueFileName(p.basename(sourcePath));
        importedPath = p.join(photosDir, uniqueName);

        await sourceFile.copy(importedPath);
        importedPath = await _ensureFlutterCompatible(importedPath, photosDir);

        // Try to read EXIF DateTimeOriginal. Fail gracefully.
        final takenAt = await _readExifTakenAt(importedPath);

        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        final photo = PhotoModel(
          themeId: themeId,
          localPath: importedPath,
          originalName: p.basename(sourcePath),
          takenAt: takenAt,
          importedAt: now,
          sourceType: PhotoSourceType.imported,
        );

        await _photoRepository.addPhoto(
          photo,
          additionalCategoryIds: additionalThemeIds,
        );
        successCount++;
      } catch (e) {
        if (importedPath != null) {
          await FileUtils.deleteFileIfExists(importedPath);
        }
        failCount++;
        errors.add('导入失败: ${p.basename(sourcePath)} — $e');
      }
    }

    return PhotoImportResult(
      successCount: successCount,
      failCount: failCount,
      errors: errors,
    );
  }

  /// Some editing apps produce JPEG/HEIF variants that Android can read but
  /// Flutter's image codec cannot render directly. Keep ordinary files byte
  /// for byte; only ask Android to normalize a file after a real codec failure.
  Future<String> _ensureFlutterCompatible(
      String sourcePath, String photosDirectory) async {
    if (await _canFlutterDecode(sourcePath)) return sourcePath;

    final normalizedPath = p.join(
      photosDirectory,
      FileUtils.generateUniqueFileName('normalized.jpg'),
    );
    final converted = await _imageCompatibilityChannel.invokeMethod<bool>(
          'normalizeImage',
          {'inputPath': sourcePath, 'outputPath': normalizedPath},
        ) ??
        false;
    if (!converted || !await _canFlutterDecode(normalizedPath)) {
      await FileUtils.deleteFileIfExists(normalizedPath);
      throw const FormatException('当前图片格式无法解析');
    }
    await FileUtils.deleteFileIfExists(sourcePath);
    return normalizedPath;
  }

  Future<bool> _canFlutterDecode(String filePath) async {
    ui.Codec? codec;
    try {
      final bytes = await File(filePath).readAsBytes();
      codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 64,
        targetHeight: 64,
      );
      await codec.getNextFrame();
      return true;
    } catch (_) {
      return false;
    } finally {
      codec?.dispose();
    }
  }

  /// Read the EXIF DateTimeOriginal tag from a photo file.
  /// Returns a Unix timestamp (seconds) or null if unavailable.
  Future<int?> _readExifTakenAt(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final exifData = await readExifFromBytes(bytes);

      final dateStr = exifData['EXIF DateTimeOriginal']?.printable;
      if (dateStr == null || dateStr.isEmpty) return null;

      // EXIF DateTimeOriginal format: "YYYY:MM:DD HH:MM:SS"
      final dateTime = DateTime.tryParse(
        dateStr.replaceAll(':', '-').replaceFirst(' ', 'T'),
      );
      if (dateTime == null) return null;

      return dateTime.millisecondsSinceEpoch ~/ 1000;
    } catch (_) {
      // EXIF reading is best-effort. Never fail an import because of it.
      return null;
    }
  }
}
