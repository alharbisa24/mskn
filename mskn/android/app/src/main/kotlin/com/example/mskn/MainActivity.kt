package com.example.mskn

import android.content.pm.PackageManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
	private val CHANNEL = "app.env"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"getMapsApiKey" -> {
					val key = getMetaDataValue("com.google.android.geo.API_KEY")
					if (key != null && key.isNotEmpty()) {
						result.success(key)
					} else {
						result.success(null)
					}
				}
				else -> result.notImplemented()
			}
		}
	}

	private fun getMetaDataValue(name: String): String? {
		return try {
			val appInfo = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
			val bundle: Bundle? = appInfo.metaData
			bundle?.getString(name)
		} catch (e: Exception) {
			null
		}
	}
}