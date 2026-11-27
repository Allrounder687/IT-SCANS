package com.syeds.itscans

import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val CHANNEL = "com.syeds.itscans/platform"
        private const val PREFS_NAME = "itscans_native_recovery"
        private const val KEY_SCAN_IN_PROGRESS = "scan_in_progress"
        private const val KEY_RECOVERED_SCANS = "recovered_scans"

        // Request codes used by flutter_doc_scanner for ML Kit Document Scanner
        private const val REQUEST_CODE_SCAN = 213312
        private const val REQUEST_CODE_SCAN_PDF = 216612
    }

    private var wasRecreated = false
    private var activeScanHandledByDart = false

    override fun onCreate(savedInstanceState: Bundle?) {
        wasRecreated = savedInstanceState != null
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "markScanStarted" -> {
                    activeScanHandledByDart = true
                    getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        .edit()
                        .putBoolean(KEY_SCAN_IN_PROGRESS, true)
                        .apply()
                    result.success(null)
                }
                "markScanFinished" -> {
                    activeScanHandledByDart = false
                    getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        .edit()
                        .putBoolean(KEY_SCAN_IN_PROGRESS, false)
                        .apply()
                    result.success(null)
                }
                "consumeRecoveredScans" -> {
                    val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    val raw = prefs.getString(KEY_RECOVERED_SCANS, "[]") ?: "[]"
                    prefs.edit().putString(KEY_RECOVERED_SCANS, "[]").apply()
                    result.success(raw)
                }
                "copyUriToFile" -> {
                    val uriString = call.argument<String>("uri")
                    val destPath = call.argument<String>("destPath")
                    if (uriString.isNullOrEmpty() || destPath.isNullOrEmpty()) {
                        result.error("INVALID_ARGS", "uri and destPath are required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        copyUriToPath(Uri.parse(uriString), File(destPath))
                        result.success(destPath)
                    } catch (e: Exception) {
                        result.error("COPY_FAILED", e.message, null)
                    }
                }
                "saveToDownloads" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val fileName = call.argument<String>("fileName")
                    val mimeType = call.argument<String>("mimeType") ?: "application/pdf"
                    if (sourcePath.isNullOrEmpty() || fileName.isNullOrEmpty()) {
                        result.error("INVALID_ARGS", "sourcePath and fileName are required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val savedLocation = saveFileToDownloads(File(sourcePath), fileName, mimeType)
                        result.success(savedLocation)
                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val scanPendingFromPreviousProcess = prefs.getBoolean(KEY_SCAN_IN_PROGRESS, false)
        val isMlKitScanCode = requestCode == REQUEST_CODE_SCAN || requestCode == REQUEST_CODE_SCAN_PDF

        // If Android killed or recreated the Activity while ML Kit was open,
        // FlutterDocScannerPlugin lost its pendingResult and will drop the result.
        // Recover the PDF directly into app storage so the scan is never lost.
        if (isMlKitScanCode && (wasRecreated || !activeScanHandledByDart) && scanPendingFromPreviousProcess) {
            prefs.edit().putBoolean(KEY_SCAN_IN_PROGRESS, false).apply()
            if (resultCode == Activity.RESULT_OK && data != null) {
                recoverMlKitResult(data)
            }
        }

        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun recoverMlKitResult(data: Intent) {
        try {
            val pdf = GmsDocumentScanningResult.fromActivityResultIntent(data)?.pdf ?: return
            val scansDir = File(filesDir, "scans")
            if (!scansDir.exists()) {
                scansDir.mkdirs()
            }
            val timestamp = System.currentTimeMillis()
            val destFile = File(scansDir, "scan_$timestamp.pdf")
            copyUriToPath(pdf.uri, destFile)

            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val existingRaw = prefs.getString(KEY_RECOVERED_SCANS, "[]") ?: "[]"
            val array = JSONArray(existingRaw)
            val item = JSONObject().apply {
                put("filePath", destFile.absolutePath)
                put("pageCount", pdf.pageCount.coerceAtLeast(1))
                put("timestamp", timestamp)
            }
            array.put(item)
            prefs.edit().putString(KEY_RECOVERED_SCANS, array.toString()).apply()
        } catch (_: Exception) {
            // Best-effort recovery; never crash Activity startup
        }
    }

    private fun copyUriToPath(uri: Uri, destFile: File) {
        destFile.parentFile?.let { parent ->
            if (!parent.exists()) parent.mkdirs()
        }
        if (uri.scheme == "file" && uri.path != null) {
            FileInputStream(File(uri.path!!)).use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output)
                }
            }
            return
        }
        contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(destFile).use { output ->
                input.copyTo(output)
            }
        } ?: throw IllegalStateException("Unable to open input stream for $uri")
    }

    private fun saveFileToDownloads(sourceFile: File, fileName: String, mimeType: String): String {
        if (!sourceFile.exists()) {
            throw IllegalStateException("Source file does not exist")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                ?: throw IllegalStateException("Failed to create MediaStore Downloads entry")
            try {
                resolver.openOutputStream(uri)?.use { output ->
                    FileInputStream(sourceFile).use { input ->
                        input.copyTo(output)
                    }
                } ?: throw IllegalStateException("Failed to open Downloads output stream")
                contentValues.clear()
                contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, contentValues, null, null)
                return uri.toString()
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                throw e
            }
        } else {
            @Suppress("DEPRECATION")
            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!downloadsDir.exists()) downloadsDir.mkdirs()
            var dest = File(downloadsDir, fileName)
            var counter = 1
            val dotIdx = fileName.lastIndexOf('.')
            val base = if (dotIdx > 0) fileName.substring(0, dotIdx) else fileName
            val ext = if (dotIdx > 0) fileName.substring(dotIdx) else ""
            while (dest.exists()) {
                dest = File(downloadsDir, "${base}_$counter$ext")
                counter++
            }
            FileInputStream(sourceFile).use { input ->
                FileOutputStream(dest).use { output ->
                    input.copyTo(output)
                }
            }
            return dest.absolutePath
        }
    }
}
