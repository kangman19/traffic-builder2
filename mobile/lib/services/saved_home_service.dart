import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_place.dart';

/// Persists the user's saved home location across app launches.
///
/// Static rather than instance-based because the background isolate in
/// `background_traffic_service.dart` has no access to the UI isolate's objects —
/// if it ever needs the saved home, it can call these directly.
class SavedHomeService {
  SavedHomeService._();

  static const String _tag = 'SavedHomeService';
  static const String _key = 'saved_home_location';

  static Future<void> saveHome(SavedPlace place) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(place.toJson()));
    debugPrint('[$_tag] Saved home → ${place.label}');
  }

  static Future<SavedPlace?> loadHome() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;

    try {
      return SavedPlace.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      // A malformed entry — older schema, or a partial write — must not brick
      // launch. Drop it and start clean.
      debugPrint('[$_tag] Discarding unreadable saved home: $e');
      await prefs.remove(_key);
      return null;
    }
  }

  static Future<void> clearHome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    debugPrint('[$_tag] Cleared saved home');
  }
}
