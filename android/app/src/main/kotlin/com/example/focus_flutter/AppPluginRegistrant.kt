package com.example.focus_flutter

import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin

// Plugin imports
import com.mr.flutter.plugin.filepicker.FilePickerPlugin
import com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin
import io.flutter.plugins.flutter_plugin_android_lifecycle.FlutterAndroidLifecyclePlugin
import io.flutter.plugins.googlesignin.GoogleSignInPlugin
import io.flutter.plugins.pathprovider.PathProviderPlugin
import io.flutter.plugins.quickactions.QuickActionsPlugin
import io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin
import net.wolverinebeach.flutter_timezone.FlutterTimezonePlugin
import xyz.luan.audioplayers.AudioplayersPlugin

/**
 * Registers Android plugins with the FlutterEngine.
 *
 * Why this exists:
 * - On some Android devices/build variants a plugin class can throw a NoClassDefFoundError
 *   (which is a Throwable, not an Exception) during class loading.
 * - Flutter's generated registrant catches Exception, which won't catch those errors.
 *
 * By registering plugins here with `catch (t: Throwable)`, we prevent a single plugin
 * from crashing the app and blocking other plugins (e.g. shared_preferences/path_provider).
 */
object AppPluginRegistrant {
  private const val TAG = "AppPluginRegistrant"

  fun registerWith(flutterEngine: FlutterEngine) {
    Log.i(TAG, "registerWith() called")
    safeAdd(flutterEngine, "audioplayers_android") { AudioplayersPlugin() }
    safeAdd(flutterEngine, "file_picker") { FilePickerPlugin() }
    safeAdd(flutterEngine, "flutter_local_notifications") { FlutterLocalNotificationsPlugin() }
    safeAdd(flutterEngine, "flutter_plugin_android_lifecycle") { FlutterAndroidLifecyclePlugin() }
    safeAdd(flutterEngine, "flutter_timezone") { FlutterTimezonePlugin() }
    safeAdd(flutterEngine, "google_sign_in_android") { GoogleSignInPlugin() }
    safeAdd(flutterEngine, "path_provider_android") { PathProviderPlugin() }
    safeAdd(flutterEngine, "quick_actions_android") { QuickActionsPlugin() }
    safeAdd(flutterEngine, "shared_preferences_android") { SharedPreferencesPlugin() }
    Log.i(TAG, "registerWith() finished")
  }

  private inline fun safeAdd(
    flutterEngine: FlutterEngine,
    pluginName: String,
    factory: () -> FlutterPlugin,
  ) {
    try {
      flutterEngine.plugins.add(factory())
      Log.i(TAG, "Registered plugin $pluginName")
    } catch (t: Throwable) {
      Log.e(TAG, "Error registering plugin $pluginName", t)
    }
  }
}
