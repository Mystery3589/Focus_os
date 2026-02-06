package com.example.focus_flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

import android.util.Log

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		// Prefer the default embedding behavior (it may do more than just plugins depending on Flutter version),
		// but guard it: some plugins can throw NoClassDefFoundError (a Throwable) during class loading.
		//
		// IMPORTANT: Only fall back to manual registration when the default path fails.
		// Calling both will cause "Attempted to register plugin ... but it was already registered" warnings.
		try {
			super.configureFlutterEngine(flutterEngine)
			return
		} catch (t: Throwable) {
			Log.e("MainActivity", "Default plugin registration failed; falling back to safe registrant", t)
		}

		AppPluginRegistrant.registerWith(flutterEngine)
	}
}
