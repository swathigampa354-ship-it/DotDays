import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import '../shared/models/calendar_type.dart';
import 'storage_service.dart';
import 'headless_wallpaper_renderer.dart';
import 'wallpaper_service.dart';

@pragma('vm:entry-point')
void alarmCallbackDispatcher() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Re-init storage since this runs in a separate isolate.
    // reload() ensures we read the FRESHEST values, including the
    // smart_wallpaper_location written by the native PreCheckReceiver
    // at 23:50 (10 minutes before this callback fires at 00:00:05).
    await StorageService.init();
    await StorageService.reload();

    final autoUpdate = StorageService.getAutoUpdate();
    if (!autoUpdate) return;

    final onboardingDone = StorageService.getOnboardingComplete();
    if (!onboardingDone) return;

    // Check if already updated today
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';
    final lastUpdate = StorageService.getString('wallpaper_last_update_day');
    if (lastUpdate == todayKey) {
      debugPrint('BackgroundService: already updated today, skipping');
      return;
    }

    debugPrint('BackgroundService: daily wallpaper update starting');

    // Read the smart wallpaper location computed by native WallpaperIdChecker.
    // This is set by EITHER:
    //   1. DotDaysApplication.onCreate() — when the process is freshly started
    //   2. PreCheckReceiver — fires at 23:50 every night (10 min before this alarm)
    // This tells us which screens still have DotDays wallpaper.
    // -1 means user changed ALL screens externally → skip update.
    final smartLocation = StorageService.getInt('dotdays_smart_wallpaper_location');
    final wallpaperLocation = StorageService.getWallpaperLocation();

    // Use the native-computed smart location, fall back to saved location
    final effectiveLocation = smartLocation ?? wallpaperLocation;

    if (effectiveLocation == -1) {
      debugPrint('BackgroundService: user changed all screens externally, skipping');
      await StorageService.setString('wallpaper_last_update_day', todayKey);
      return;
    }

    debugPrint('BackgroundService: applying to location=$effectiveLocation (saved=$wallpaperLocation, smart=$smartLocation)');

    // Read settings from storage
    final calTypeStr = StorageService.getCalendarType();
    final calendarType = calTypeStr != null
        ? CalendarType.fromKey(calTypeStr)
        : CalendarType.life;
    final dob = StorageService.getDateOfBirth();
    final lifespan = StorageService.getLifespan();
    final goalName = StorageService.getGoalName();
    final goalStart = StorageService.getGoalStart();
    final goalEnd = StorageService.getGoalEnd();
    final livedDotColorVal = StorageService.getLivedDotColor();

    // Render new wallpaper with today's date
    final file = await HeadlessWallpaperRenderer.render(
      calendarType: calendarType,
      dateOfBirth: dob,
      lifespan: lifespan,
      goalName: goalName,
      goalStart: goalStart,
      goalEnd: goalEnd,
      livedDotColor: Color(livedDotColorVal),
    );

    if (file != null) {
      final success =
          await WallpaperService.applyWallpaper(file, effectiveLocation);
      if (success) {
        await StorageService.setString('wallpaper_last_update_day', todayKey);

        // Try to save new wallpaper IDs via SmartWallpaperPlugin
        // (works on background engines since it's registered via GeneratedPluginRegistrant)
        try {
          const smartChannel = MethodChannel('com.example.dotdays/smart_wallpaper');
          await smartChannel.invokeMethod('saveCurrentIds');
          debugPrint('BackgroundService: IDs saved via SmartWallpaperPlugin');
        } catch (e) {
          // If plugin not available, mark IDs as stale for foreground
          await StorageService.setBool('dotdays_ids_stale', true);
          debugPrint('BackgroundService: marked IDs stale ($e)');
        }

        debugPrint('BackgroundService: wallpaper applied successfully');
      } else {
        debugPrint('BackgroundService: failed to apply wallpaper');
      }
    } else {
      debugPrint('BackgroundService: failed to render wallpaper');
    }
  } catch (e) {
    debugPrint('BackgroundService error: $e');
  } finally {
    // Always schedule next day's alarm so it creates a daily cycle
    BackgroundService.scheduleDaily();
  }
}

class BackgroundService {
  BackgroundService._();
  
  static const int alarmId = 1001;

  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    await AndroidAlarmManager.initialize();
  }

  /// Schedule the wallpaper update for exactly midnight.
  static Future<void> scheduleDaily() async {
    if (!Platform.isAndroid) return;
    final now = DateTime.now();
    
    // Calculate the next midnight (plus 5 seconds to ensure the day has fully rolled over)
    DateTime nextMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 5);
    
    // Use oneShotAt for exact timing and wakeup.
    // On Android 12+ exact alarms need a permission the user can revoke from
    // Settings; if the exact alarm is rejected we fall back to an inexact
    // (still wake-up) alarm so the daily update keeps running instead of
    // failing. scheduleDaily() is awaited from main(), so it must never throw.
    try {
      await AndroidAlarmManager.oneShotAt(
        nextMidnight,
        alarmId,
        alarmCallbackDispatcher,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );
      debugPrint('BackgroundService: exact alarm scheduled for $nextMidnight');
    } catch (e) {
      debugPrint('BackgroundService: exact alarm failed ($e), using inexact alarm');
      await _scheduleInexact(nextMidnight);
    }
  }

  /// Schedule a non-exact wake-up alarm for [time] (fallback path).
  static Future<void> _scheduleInexact(DateTime time) async {
    try {
      await AndroidAlarmManager.oneShotAt(
        time,
        alarmId,
        alarmCallbackDispatcher,
        exact: false,
        wakeup: true,
        rescheduleOnReboot: true,
      );
      debugPrint('BackgroundService: inexact alarm scheduled for $time');
    } catch (e) {
      debugPrint('BackgroundService: could not schedule alarm: $e');
    }
  }

  /// Re-schedule the task — useful on app launch to ensure it's still alive.
  static Future<void> ensureScheduled() async {
    if (!Platform.isAndroid) return;
    final autoUpdate = StorageService.getAutoUpdate();
    final onboardingDone = StorageService.getOnboardingComplete();
    if (autoUpdate && onboardingDone) {
      await scheduleDaily();
    }
  }

  static Future<void> cancel() async {
    if (!Platform.isAndroid) return;
    await AndroidAlarmManager.cancel(alarmId);
  }
}
