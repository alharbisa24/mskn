import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  static final MethodChannel _channel = const MethodChannel('app.env');
  static String _mapsKey = '';

  // Initialize env-derived settings and try platform sources as fallback
  static Future<void> init() async {
    // 1) Try .env
    _mapsKey = dotenv.env['GOOGLE_MAP_API'] ??
        dotenv.env['GOOGLE_MAPS_API_KEY'] ??
        dotenv.env['MAPS_API_KEY'] ??
        '';

    // 2) Fallback: Android Manifest meta-data
    if (_mapsKey.isEmpty && Platform.isAndroid) {
      try {
        final String? key =
            await _channel.invokeMethod<String>('getMapsApiKey');
        if (key != null && key.isNotEmpty) {
          _mapsKey = key;
        }
      } catch (_) {
        // ignore, keep empty
      }
    }
  }

  // Accessor for the cached key (empty if none)
  static String googleMapsApiKey() => _mapsKey;
}
