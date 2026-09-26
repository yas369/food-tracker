package com.yas369.platecheck;

import android.Manifest;
import android.content.Context;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import com.getcapacitor.JSObject;
import com.getcapacitor.PermissionState;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.getcapacitor.annotation.Permission;
import com.getcapacitor.annotation.PermissionCallback;
import java.util.ArrayList;
import java.util.List;

/**
 * Reads the phone's hardware step counter (TYPE_STEP_COUNTER): the total
 * number of steps since the phone last restarted. The app stores readings and
 * works out steps per day from the differences.
 *
 * The listener stays registered while the app is alive, because on some
 * phones the counter only keeps counting while someone is listening.
 */
@CapacitorPlugin(
    name = "StepCounter",
    permissions = { @Permission(alias = "activity", strings = { Manifest.permission.ACTIVITY_RECOGNITION }) }
)
public class StepCounterPlugin extends Plugin implements SensorEventListener {

    private SensorManager sensorManager;
    private Sensor sensor;
    private boolean listening = false;
    private float lastValue = -1;
    private final List<PluginCall> waiting = new ArrayList<>();
    private final Handler handler = new Handler(Looper.getMainLooper());

    @Override
    public void load() {
        sensorManager = (SensorManager) getContext().getSystemService(Context.SENSOR_SERVICE);
        sensor = sensorManager == null ? null : sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER);
        listen();
    }

    /** Activity recognition only became a runtime permission in Android 10. */
    private boolean granted() {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || getPermissionState("activity") == PermissionState.GRANTED;
    }

    private void listen() {
        if (listening || sensor == null || !granted()) return;
        listening = sensorManager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL);
    }

    private JSObject status() {
        JSObject r = new JSObject();
        r.put("available", sensor != null);
        r.put("granted", granted());
        return r;
    }

    @PluginMethod
    public void getStatus(PluginCall call) {
        call.resolve(status());
    }

    @PluginMethod
    public void requestAccess(PluginCall call) {
        if (sensor == null || granted()) {
            listen();
            call.resolve(status());
            return;
        }
        requestPermissionForAlias("activity", call, "accessCallback");
    }

    @PermissionCallback
    private void accessCallback(PluginCall call) {
        listen();
        call.resolve(status());
    }

    @PluginMethod
    public void read(PluginCall call) {
        if (sensor == null) {
            call.reject("This phone has no step sensor", "UNAVAILABLE");
            return;
        }
        if (!granted()) {
            call.reject("Physical activity permission is needed", "DENIED");
            return;
        }
        listen();
        waiting.add(call);
        // The sensor only reports when the count changes, so fall back to the
        // last value if no new event arrives.
        handler.postDelayed(() -> {
            if (waiting.remove(call)) {
                if (lastValue >= 0) resolveWith(call);
                else call.reject("No reading from the step sensor yet", "NO_DATA");
            }
        }, 2500);
    }

    private void resolveWith(PluginCall call) {
        JSObject r = new JSObject();
        r.put("steps", (double) lastValue);
        r.put("bootTime", System.currentTimeMillis() - SystemClock.elapsedRealtime());
        r.put("at", System.currentTimeMillis());
        call.resolve(r);
    }

    @Override
    public void onSensorChanged(SensorEvent event) {
        lastValue = event.values[0];
        List<PluginCall> ready = new ArrayList<>(waiting);
        waiting.clear();
        for (PluginCall c : ready) resolveWith(c);
    }

    @Override
    public void onAccuracyChanged(Sensor s, int accuracy) {}

    @Override
    protected void handleOnDestroy() {
        if (sensorManager != null && listening) sensorManager.unregisterListener(this);
        listening = false;
    }
}
