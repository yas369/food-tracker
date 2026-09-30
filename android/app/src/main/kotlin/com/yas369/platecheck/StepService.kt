package com.yas369.platecheck

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.os.SystemClock

/**
 * Keeps the phone's step counter listened to while Plate Check is closed.
 *
 * On many phones the counter only counts while some app listens, and Android
 * stops closed apps from listening. A foreground service, with its small
 * notification, is how Android lets an app keep listening. Readings go into a
 * queue that the app reads the next time it opens.
 */
class StepService : Service(), SensorEventListener {
    companion object {
        const val PREFS = "platecheck_steps"
        private const val QUEUE = "queue"
        private const val CHANNEL = "steps"
        private const val NOTE_ID = 4201
        private const val MAX_LINES = 5000
        private const val EVERY_MS = 60_000L // about one queued reading a minute
        private const val SAVE_MS = 30_000L

        private var cache: MutableList<String>? = null
        private var savedAt = 0L

        /** When the phone last started, from Android's own clock (includes sleep). */
        fun bootTime(): Long = System.currentTimeMillis() - SystemClock.elapsedRealtime()

        fun start(ctx: Context) {
            val i = Intent(ctx, StepService::class.java)
            if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
        }

        fun stop(ctx: Context) {
            ctx.stopService(Intent(ctx, StepService::class.java))
        }

        private fun lines(ctx: Context): MutableList<String> =
            cache ?: ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(QUEUE, "").orEmpty()
                .split('\n').filter { it.isNotBlank() }.toMutableList().also { cache = it }

        private fun save(ctx: Context) {
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(QUEUE, lines(ctx).joinToString("\n")).apply()
            savedAt = SystemClock.elapsedRealtime()
        }

        private fun atOf(line: String): Long? = line.split(',').getOrNull(2)?.toLongOrNull()

        /** Queue a reading: steps since the phone started, when it started, and when counted. */
        @Synchronized
        fun record(ctx: Context, count: Float, boot: Long, at: Long) {
            val q = lines(ctx)
            val line = "$count,$boot,$at"
            // While walking the counter reports every step; one reading a minute is
            // plenty, so the newest replaces the last one within the same minute.
            val before = if (q.size >= 2) atOf(q[q.size - 2]) else null
            if (before != null && at - before < EVERY_MS) q[q.size - 1] = line else q.add(line)
            while (q.size > MAX_LINES) q.removeAt(0)
            if (SystemClock.elapsedRealtime() - savedAt > SAVE_MS) save(ctx)
        }

        /** The queued readings, oldest first, as [count, boot, at]; empties the queue. */
        @Synchronized
        fun drain(ctx: Context): List<List<Double>> {
            val q = lines(ctx)
            val out = q.mapNotNull { line ->
                val p = line.split(',').mapNotNull { it.toDoubleOrNull() }
                if (p.size == 3) p else null
            }
            q.clear()
            save(ctx)
            return out
        }

        @Synchronized
        fun flush(ctx: Context) = save(ctx)
    }

    private var sensors: SensorManager? = null

    override fun onCreate() {
        super.onCreate()
        makeChannel()
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(NOTE_ID, notification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH)
            } else {
                startForeground(NOTE_ID, notification())
            }
        } catch (e: Exception) {
            // Not allowed right now (permission missing, or started from the
            // background on a newer Android). The app tries again when it opens.
            stopSelf()
            return
        }
        val sm = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val counter = sm.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (counter == null) {
            stopSelf()
            return
        }
        sensors = sm
        // Let the sensor hold readings for up to a minute before waking the
        // phone: the count is a running total, so nothing is lost by waiting.
        sm.registerListener(this, counter, SensorManager.SENSOR_DELAY_NORMAL, 60_000_000)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onDestroy() {
        sensors?.unregisterListener(this)
        sensors = null
        flush(this)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onSensorChanged(event: SensorEvent) {
        val boot = bootTime()
        val now = System.currentTimeMillis()
        // The event's own time (since the phone started), not when it arrived:
        // batched readings arrive late but still say when the steps happened.
        var at = boot + event.timestamp / 1_000_000
        if (at > now + 60_000 || at < now - 86_400_000) at = now
        record(this, event.values[0], boot, at)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun makeChannel() {
        if (Build.VERSION.SDK_INT < 26) return
        val ch = NotificationChannel(CHANNEL, "Step counting", NotificationManager.IMPORTANCE_MIN)
        ch.description = "Shown while Plate Check counts your steps with the app closed"
        ch.setShowBadge(false)
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(ch)
    }

    private fun notification(): Notification {
        val open = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else @Suppress("DEPRECATION") Notification.Builder(this)
        return b.setSmallIcon(R.drawable.ic_stat_plate)
            .setContentTitle("Counting your steps")
            .setContentText("Plate Check keeps counting while it's closed. Tap to open.")
            .setContentIntent(open)
            .setOngoing(true)
            .setShowWhen(false)
            .build()
    }
}
