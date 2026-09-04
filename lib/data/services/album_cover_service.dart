import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/file_utils.dart';

class AlbumCoverService {
  Future<String> saveCover(String sourcePath, {String? previousPath}) async {
    final source = File(sourcePath);
    if (!await source.exists()) throw const FileSystemException('封面图片不存在');

    final appDir = await getApplicationDocumentsDirectory();
    final coversDir = p.join(appDir.path, AppConstants.coversDirName);
    await FileUtils.ensureDirectory(coversDir);
    final extension =
        p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final fileName = FileUtils.generateUniqueFileName('cover$extension');
    final savedPath = p.join(coversDir, fileName);
    await source.copy(savedPath);

    if (previousPath != null && previousPath != savedPath) {
      final normalizedDir = p.normalize(p.absolute(coversDir));
      final normalizedPrevious = p.normalize(p.absolute(previousPath));
      if (p.isWithin(normalizedDir, normalizedPrevious)) {
        await FileUtils.deleteFileIfExists(normalizedPrevious);
      }
    }
    return savedPath;
  }
}
