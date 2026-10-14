package com.example.dotdays

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.Calendar

/**
 * Native BroadcastReceiver that runs the wallpaper ID check ~10 minutes
 * BEFORE the midnight Dart alarm fires.
 *
 * WHY THIS IS NEEDED:
 * - DotDaysApplication.onCreate() only runs once per process lifetime.
 * - If the app process is still alive when the midnight alarm fires,
 *   the smart location from onCreate() is stale (computed hours ago).
 * - This pre-check alarm runs at 23:50 every night, ensuring a FRESH
 *   wallpaper ID comparison is written to SharedPreferences before
 *   the Dart callback reads it at 00:00:05.
 *
 * FLOW:
 * 23:50 → PreCheckReceiver runs → WallpaperIdChecker writes smart location
 * 00:00:05 → Dart alarmCallbackDispatcher → reads smart location → applies correctly
 */
class PreCheckReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "PreCheckReceiver"
        private const val ALARM_ID = 1002

        /**
         * Schedule the pre-check alarm for 23:50 tonight (or tomorrow if past).
         * Uses setExactAndAllowWhileIdle for reliability in Doze mode.
         */
        fun scheduleNext(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            val now = Calendar.getInstance()
            val target = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 23)
                set(Calendar.MINUTE, 50)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                // If 23:50 has already passed today, schedule for tomorrow
                if (before(now)) {
                    add(Calendar.DAY_OF_YEAR, 1)
                }
            }

            val intent = Intent(context, PreCheckReceiver::class.java)
            val flags = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            val pi = PendingIntent.getBroadcast(context, ALARM_ID, intent, flags)

            // On Android 12+ (API 31+) exact alarms need SCHEDULE_EXACT_ALARM /
            // USE_EXACT_ALARM, and the user can revoke that permission at any
            // time in Settings. Scheduling an exact alarm without it throws a
            // SecurityException, which would crash the app. Check first and
            // fall back to an inexact (but still wake-up) alarm so the nightly
            // wallpaper pre-check keeps running on every supported Android
            // version.
            val canScheduleExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                am.canScheduleExactAlarms()

            try {
                if (canScheduleExact) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        am.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            target.timeInMillis,
                            pi
                        )
                    } else {
                        am.setExact(
                            AlarmManager.RTC_WAKEUP,
                            target.timeInMillis,
                            pi
                        )
                    }
                } else {
                    Log.w(TAG, "Exact alarms not permitted, scheduling inexact pre-check")
                    am.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        target.timeInMillis,
                        pi
                    )
                }
            } catch (e: SecurityException) {
                Log.e(TAG, "Exact alarm rejected (${e.message}), scheduling inexact pre-check")
                try {
                    am.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        target.timeInMillis,
                        pi
                    )
                } catch (e2: Exception) {
                    Log.e(TAG, "Failed to schedule pre-check: ${e2.message}")
                }
            }

            Log.d(TAG, "Pre-check alarm scheduled for ${target.time}")
        }

        fun cancel(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, PreCheckReceiver::class.java)
            val flags = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            val pi = PendingIntent.getBroadcast(context, ALARM_ID, intent, flags)
            am.cancel(pi)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Pre-check alarm fired, computing smart wallpaper location")

        try {
            val prefs = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE
            )

            // If IDs are stale (background updated wallpaper), refresh baseline first
            val idsStale = prefs.getBoolean("flutter.dotdays_ids_stale", false)
            if (idsStale) {
                Log.d(TAG, "IDs stale from background update, refreshing baseline")
                WallpaperIdChecker.saveCurrentIds(context)
            }

            // Compute and save the smart location for tonight's Dart alarm
            val smartLocation = WallpaperIdChecker.computeAndSaveSmartLocation(context)
            Log.d(TAG, "Smart location computed: $smartLocation")
        } catch (e: Exception) {
            Log.e(TAG, "Error in pre-check: ${e.message}")
        }

        // Re-schedule for tomorrow night. Never let a scheduling failure
        // escape here: an uncaught exception in a BroadcastReceiver crashes
        // the whole app on Android 10+.
        try {
            scheduleNext(context)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to re-schedule pre-check: ${e.message}")
        }
    }
}
