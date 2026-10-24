package com.yas369.platecheck

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

/** Starts background step counting again after the phone restarts or the app updates. */
class StepBootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        val enabled = ctx.getSharedPreferences(StepService.PREFS, Context.MODE_PRIVATE).getBoolean("enabled", false)
        if (!enabled) return
        if (Build.VERSION.SDK_INT >= 29 &&
            ctx.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) != PackageManager.PERMISSION_GRANTED
        ) return
        try {
            StepService.start(ctx)
        } catch (e: Exception) {
            // Some phones don't allow it here; the app starts it when opened.
        }
    }
}
