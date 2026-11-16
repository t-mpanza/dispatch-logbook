package com.dispatchdiary.dispatch_diary

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val INSTALL_CHANNEL = "com.dispatchdiary.dispatch_diary/install"
    private val HAPTICS_CHANNEL = "dispatch_diary/haptics"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALL_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "installApk") {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_PATH", "APK path is null", null)
                        return@setMethodCallHandler
                    }

                    // API 26+: verify "Install unknown apps" is granted for this source
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        !packageManager.canRequestPackageInstalls()
                    ) {
                        val settingsIntent = Intent(
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:$packageName")
                        )
                        settingsIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(settingsIntent)
                        result.error(
                            "PERMISSION_REQUIRED",
                            "Enable 'Install unknown apps' for Dispatch Diary in Settings, then retry the update.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        val file = File(path)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "APK file not found at: $path", null)
                            return@setMethodCallHandler
                        }

                        val intent = Intent(Intent.ACTION_VIEW)
                        val apkUri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            FileProvider.getUriForFile(
                                this,
                                "${packageName}.fileprovider",
                                file
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            Uri.fromFile(file)
                        }

                        intent.setDataAndType(apkUri, "application/vnd.android.package-archive")
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_FAILED", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        // Scan-error haptics. Flutter's built-in impacts funnel into
        // performHapticFeedback, which Android silently drops when the
        // device's "touch feedback" setting is off — in a noisy bay the
        // WRONG-tyre rumble must always be felt. The system Vibrator only
        // respects the master Vibration setting (the VIBRATE permission is
        // declared in the manifest), so the error verdict goes straight
        // to it: three hard pulses at full amplitude.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HAPTICS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "vibrateError" -> {
                        vibratePattern(longArrayOf(0, 250, 110, 350, 110, 250))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun vibratePattern(pattern: LongArray) {
        val vibrator = getSystemService(VIBRATOR_SERVICE) as? Vibrator ?: return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // Odd indices are ON segments — full amplitude for each pulse.
                val amplitudes = IntArray(pattern.size) { if (it % 2 == 0) 0 else 255 }
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, amplitudes, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern, -1)
            }
        } catch (_: Exception) {
            // Haptics are best-effort — never let one crash a scan.
        }
    }
}
