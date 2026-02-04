package com.example.focus_flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

import android.util.Log

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		// Prefer the default embedding behavior (it may do more than just plugins depending on Flutter version),
		// but guard it: some plugins can throw NoClassDefFoundError (a Throwable) during class loading.
		try {
			super.configureFlutterEngine(flutterEngine)
		} catch (t: Throwable) {
			Log.e("MainActivity", "Default plugin registration failed; falling back to safe registrant", t)
		}

		// Always ensure required plugins are registered. If a plugin is already added,
		// the safe registrant will catch and ignore the duplicate registration error.
		AppPluginRegistrant.registerWith(flutterEngine)
	}
}
