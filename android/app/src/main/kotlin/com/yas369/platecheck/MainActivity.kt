package com.yas369.platecheck

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Background step counting (see StepService).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "platecheck/steps").setMethodCallHandler { call, result ->
            try {
                val prefs = getSharedPreferences(StepService.PREFS, Context.MODE_PRIVATE)
                when (call.method) {
                    "start" -> {
                        prefs.edit().putBoolean("enabled", true).apply()
                        StepService.start(this)
                        result.success(true)
                    }
                    "stop" -> {
                        prefs.edit().putBoolean("enabled", false).apply()
                        StepService.stop(this)
                        result.success(true)
                    }
                    "drain" -> result.success(StepService.drain(this))
                    "bootTime" -> result.success(StepService.bootTime())
                    "batteryExempt" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "askBatteryExempt" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName")))
                        } catch (e: Exception) {
                            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("steps", e.message, null)
            }
        }
    }
}
