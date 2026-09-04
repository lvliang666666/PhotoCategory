package com.photostorer.photo_storer

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

class MainActivity : FlutterActivity() {
    private val archiveChannel = "com.photostorer.photo_storer/archive"
    private val secureStorageChannel = "com.photostorer.photo_storer/secure_storage"
    private val imageCompatibilityChannel = "com.photostorer.photo_storer/image_compat"
    private var pendingBackupPicker: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, archiveChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "createZip" -> {
                        val paths = call.argument<List<String>>("paths").orEmpty()
                        val outputPath = call.argument<String>("outputPath")
                        if (paths.isEmpty() || outputPath.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENTS", "没有可打包的照片", null)
                            return@setMethodCallHandler
                        }
                        runArchiveTask(result, "ZIP_FAILED", "创建压缩包失败") {
                            createZip(paths, outputPath)
                        }
                    }

                    "createBackupZip" -> {
                        val entries =
                            call.argument<List<Map<String, Any?>>>("entries").orEmpty()
                        val outputPath = call.argument<String>("outputPath")
                        if (entries.isEmpty() || outputPath.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENTS", "备份内容为空", null)
                            return@setMethodCallHandler
                        }
                        runArchiveTask(result, "BACKUP_FAILED", "创建完整备份失败") {
                            createStructuredZip(entries, outputPath)
                        }
                    }

                    "extractBackupZip" -> {
                        val inputPath = call.argument<String>("inputPath")
                        val outputDirectory = call.argument<String>("outputDirectory")
                        if (inputPath.isNullOrBlank() || outputDirectory.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENTS", "备份文件路径无效", null)
                            return@setMethodCallHandler
                        }
                        runArchiveTask(result, "RESTORE_FAILED", "解压备份失败") {
                            extractBackupZip(inputPath, outputDirectory)
                        }
                    }

                    "pickBackupZip" -> openBackupPicker(result)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, secureStorageChannel)
            .setMethodCallHandler { call, result ->
                val key = call.argument<String>("key")
                if (key.isNullOrBlank()) {
                    result.error("INVALID_KEY", "安全存储键不能为空", null)
                    return@setMethodCallHandler
                }
                try {
                    when (call.method) {
                        "write" -> {
                            val value = call.argument<String>("value")
                            if (value == null) {
                                result.error("INVALID_VALUE", "安全存储内容不能为空", null)
                            } else {
                                securePreferences().edit().putString(key, encrypt(value)).apply()
                                result.success(null)
                            }
                        }
                        "read" -> {
                            val encrypted = securePreferences().getString(key, null)
                            result.success(encrypted?.let(::decrypt))
                        }
                        "delete" -> {
                            securePreferences().edit().remove(key).apply()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("SECURE_STORAGE_FAILED", error.message ?: "安全存储操作失败", null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, imageCompatibilityChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "normalizeImage") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val inputPath = call.argument<String>("inputPath")
                val outputPath = call.argument<String>("outputPath")
                if (inputPath.isNullOrBlank() || outputPath.isNullOrBlank()) {
                    result.error("INVALID_ARGUMENTS", "图片路径无效", null)
                    return@setMethodCallHandler
                }
                Thread {
                    try {
                        val converted = normalizeImage(inputPath, outputPath)
                        runOnUiThread { result.success(converted) }
                    } catch (error: Exception) {
                        runOnUiThread {
                            result.error(
                                "IMAGE_NORMALIZE_FAILED",
                                error.message ?: "图片兼容处理失败",
                                null,
                            )
                        }
                    }
                }.start()
            }
    }

    private fun normalizeImage(inputPath: String, outputPath: String): Boolean {
        val source = File(inputPath)
        if (!source.isFile || !source.canRead()) return false
        val decoded = BitmapFactory.decodeFile(inputPath) ?: return false
        val orientation = try {
            ExifInterface(inputPath).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        } catch (_: Exception) {
            ExifInterface.ORIENTATION_NORMAL
        }
        val matrix = Matrix().apply {
            when (orientation) {
                ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> setScale(-1f, 1f)
                ExifInterface.ORIENTATION_ROTATE_180 -> setRotate(180f)
                ExifInterface.ORIENTATION_FLIP_VERTICAL -> {
                    setRotate(180f)
                    postScale(-1f, 1f)
                }
                ExifInterface.ORIENTATION_TRANSPOSE -> {
                    setRotate(90f)
                    postScale(-1f, 1f)
                }
                ExifInterface.ORIENTATION_ROTATE_90 -> setRotate(90f)
                ExifInterface.ORIENTATION_TRANSVERSE -> {
                    setRotate(-90f)
                    postScale(-1f, 1f)
                }
                ExifInterface.ORIENTATION_ROTATE_270 -> setRotate(-90f)
            }
        }
        val normalized = if (matrix.isIdentity) {
            decoded
        } else {
            Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
        }
        val output = File(outputPath)
        output.parentFile?.mkdirs()
        val success = FileOutputStream(output).use { stream ->
            normalized.compress(Bitmap.CompressFormat.JPEG, 95, stream)
        }
        if (normalized !== decoded) normalized.recycle()
        decoded.recycle()
        if (!success) output.delete()
        return success
    }

    private fun securePreferences() =
        getSharedPreferences("secure_ai_settings", MODE_PRIVATE)

    private fun getOrCreateSecretKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (keyStore.getKey(secureKeyAlias, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            "AndroidKeyStore",
        )
        generator.init(
            KeyGenParameterSpec.Builder(
                secureKeyAlias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build(),
        )
        return generator.generateKey()
    }

    private fun encrypt(value: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateSecretKey())
        val iv = Base64.encodeToString(cipher.iv, Base64.NO_WRAP)
        val payload = Base64.encodeToString(
            cipher.doFinal(value.toByteArray(Charsets.UTF_8)),
            Base64.NO_WRAP,
        )
        return "$iv:$payload"
    }

    private fun decrypt(value: String): String {
        val parts = value.split(':', limit = 2)
        require(parts.size == 2) { "安全存储内容已损坏" }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(
            Cipher.DECRYPT_MODE,
            getOrCreateSecretKey(),
            GCMParameterSpec(128, Base64.decode(parts[0], Base64.NO_WRAP)),
        )
        return String(
            cipher.doFinal(Base64.decode(parts[1], Base64.NO_WRAP)),
            Charsets.UTF_8,
        )
    }

    private fun runArchiveTask(
        result: MethodChannel.Result,
        errorCode: String,
        fallbackMessage: String,
        task: () -> Map<String, Any>,
    ) {
        Thread {
            try {
                val value = task()
                runOnUiThread { result.success(value) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error(errorCode, error.message ?: fallbackMessage, null)
                }
            }
        }.start()
    }

    private fun openBackupPicker(result: MethodChannel.Result) {
        if (pendingBackupPicker != null) {
            result.error("PICKER_BUSY", "文件选择器正在使用", null)
            return
        }
        pendingBackupPicker = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/zip"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("application/zip", "application/x-zip-compressed", "application/octet-stream"),
            )
        }
        try {
            startActivityForResult(intent, backupPickerRequestCode)
        } catch (error: Exception) {
            pendingBackupPicker = null
            result.error("PICKER_FAILED", error.message ?: "无法打开文件选择器", null)
        }
    }

    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != backupPickerRequestCode) return
        val pending = pendingBackupPicker ?: return
        pendingBackupPicker = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            pending.success(null)
            return
        }
        val uri = data.data!!
        Thread {
            try {
                val target = File(cacheDir, "album-backup-${System.currentTimeMillis()}.zip")
                contentResolver.openInputStream(uri).use { input ->
                    requireNotNull(input) { "无法读取所选备份文件" }
                    BufferedOutputStream(FileOutputStream(target)).use { output ->
                        input.copyTo(output)
                    }
                }
                runOnUiThread { pending.success(target.absolutePath) }
            } catch (error: Exception) {
                runOnUiThread {
                    pending.error("PICKER_READ_FAILED", error.message ?: "读取备份文件失败", null)
                }
            }
        }.start()
    }

    private fun createZip(paths: List<String>, outputPath: String): Map<String, Any> {
        val usedNames = mutableSetOf<String>()
        val entries = paths.map { path ->
            mapOf<String, Any?>(
                "sourcePath" to path,
                "entryName" to uniqueEntryName(File(path).name, usedNames),
            )
        }
        val summary = createStructuredZip(entries, outputPath)
        if ((summary["includedCount"] as Int) == 0) {
            File(outputPath).delete()
            throw IllegalStateException("相册中的照片文件均不可用")
        }
        return summary
    }

    private fun createStructuredZip(
        entries: List<Map<String, Any?>>,
        outputPath: String,
    ): Map<String, Any> {
        val output = File(outputPath)
        output.parentFile?.mkdirs()
        var included = 0
        var skipped = 0
        val usedNames = mutableSetOf<String>()

        ZipOutputStream(BufferedOutputStream(FileOutputStream(output))).use { zip ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            entries.forEach { item ->
                val path = item["sourcePath"] as? String
                val requestedName = item["entryName"] as? String
                if (path.isNullOrBlank() || requestedName.isNullOrBlank()) {
                    skipped++
                    return@forEach
                }
                val source = File(path)
                if (!source.isFile || !source.canRead()) {
                    skipped++
                    return@forEach
                }
                val entryName = safeEntryName(requestedName)
                if (!usedNames.add(entryName)) {
                    throw IllegalArgumentException("备份中存在重复文件：$entryName")
                }
                zip.putNextEntry(ZipEntry(entryName).apply { time = source.lastModified() })
                BufferedInputStream(FileInputStream(source)).use { input ->
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        zip.write(buffer, 0, count)
                    }
                }
                zip.closeEntry()
                included++
            }
        }
        return mapOf(
            "path" to output.absolutePath,
            "includedCount" to included,
            "skippedCount" to skipped,
        )
    }

    private fun extractBackupZip(inputPath: String, outputDirectory: String): Map<String, Any> {
        val input = File(inputPath)
        require(input.isFile && input.canRead()) { "备份文件不可读" }
        val root = File(outputDirectory).canonicalFile
        root.mkdirs()
        val rootPrefix = root.path + File.separator
        var entryCount = 0
        var extractedBytes = 0L

        ZipInputStream(BufferedInputStream(FileInputStream(input))).use { zip ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val entry = zip.nextEntry ?: break
                entryCount++
                require(entryCount <= maxBackupEntries) { "备份文件条目过多" }
                val entryName = safeEntryName(entry.name)
                val target = File(root, entryName).canonicalFile
                require(target.path.startsWith(rootPrefix)) { "备份包含不安全路径" }
                if (entry.isDirectory) {
                    target.mkdirs()
                } else {
                    target.parentFile?.mkdirs()
                    BufferedOutputStream(FileOutputStream(target)).use { output ->
                        while (true) {
                            val count = zip.read(buffer)
                            if (count < 0) break
                            extractedBytes += count
                            require(extractedBytes <= maxExtractedBackupBytes) { "备份解压后体积过大" }
                            output.write(buffer, 0, count)
                        }
                    }
                }
                zip.closeEntry()
            }
        }
        return mapOf(
            "outputDirectory" to root.absolutePath,
            "entryCount" to entryCount,
            "extractedBytes" to extractedBytes,
        )
    }

    private fun safeEntryName(original: String): String {
        val normalized = original.replace('\\', '/').trimStart('/')
        require(normalized.isNotBlank()) { "备份条目名称为空" }
        require(normalized.split('/').none { it == ".." || it.isBlank() }) {
            "备份包含不安全路径"
        }
        return normalized
    }

    private fun uniqueEntryName(original: String, used: MutableSet<String>): String {
        val safeName = original.ifBlank { "photo" }.replace(Regex("[\\\\/:*?\"<>|]"), "_")
        if (used.add(safeName)) return safeName
        val dot = safeName.lastIndexOf('.')
        val stem = if (dot > 0) safeName.substring(0, dot) else safeName
        val extension = if (dot > 0) safeName.substring(dot) else ""
        var suffix = 2
        while (true) {
            val candidate = "$stem-$suffix$extension"
            if (used.add(candidate)) return candidate
            suffix++
        }
    }

    companion object {
        private const val secureKeyAlias = "photo_storer_ai_api_key"
        private const val backupPickerRequestCode = 7314
        private const val maxBackupEntries = 20_000
        private const val maxExtractedBackupBytes = 20L * 1024L * 1024L * 1024L
    }
}
