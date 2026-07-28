import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api_profile.dart';

/// Manages API profiles: CRUD, persistence, active profile tracking.
class ApiProfileService extends ChangeNotifier {
  static const String _profilesKey = 'JagadAI_api_profiles';
  static const String _activeProfileKey = 'JagadAI_active_profile_id';

  List<ApiProfile> _profiles = [];
  String? _activeProfileId;
  bool _isLoaded = false;

  List<ApiProfile> get profiles => List.unmodifiable(_profiles);
  bool get isLoaded => _isLoaded;
  bool get hasProfiles => _profiles.isNotEmpty;

  ApiProfile? get activeProfile {
    if (_activeProfileId == null) return null;
    try {
      return _profiles.firstWhere((p) => p.id == _activeProfileId);
    } catch (_) {
      return _profiles.isNotEmpty ? _profiles.first : null;
    }
  }

  /// Load all profiles from storage
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_profilesKey);
      _activeProfileId = prefs.getString(_activeProfileKey);

      if (jsonStr != null) {
        final List<dynamic> list = jsonDecode(jsonStr);
        _profiles = list
            .map((e) => ApiProfile.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      // Ensure active profile ID is valid
      if (_activeProfileId != null &&
          !_profiles.any((p) => p.id == _activeProfileId)) {
        _activeProfileId = _profiles.isNotEmpty ? _profiles.first.id : null;
      }

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading API profiles: $e');
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// Save all profiles to storage
  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_profiles.map((p) => p.toJson()).toList());
      await prefs.setString(_profilesKey, jsonStr);
      if (_activeProfileId != null) {
        await prefs.setString(_activeProfileKey, _activeProfileId!);
      } else {
        await prefs.remove(_activeProfileKey);
      }
    } catch (e) {
      debugPrint('Error saving API profiles: $e');
    }
  }

  /// Add a new profile
  Future<void> addProfile(ApiProfile profile) async {
    _profiles.add(profile);
    // Auto-activate if it's the first profile
    if (_profiles.length == 1) {
      _activeProfileId = profile.id;
    }
    await _save();
    notifyListeners();
  }

  /// Update an existing profile
  Future<void> updateProfile(ApiProfile updated) async {
    final index = _profiles.indexWhere((p) => p.id == updated.id);
    if (index >= 0) {
      _profiles[index] = updated;
      await _save();
      notifyListeners();
    }
  }

  /// Delete a profile
  Future<void> deleteProfile(String id) async {
    _profiles.removeWhere((p) => p.id == id);
    if (_activeProfileId == id) {
      _activeProfileId = _profiles.isNotEmpty ? _profiles.first.id : null;
    }
    await _save();
    notifyListeners();
  }

  /// Set the active profile
  Future<void> setActiveProfile(String id) async {
    if (_profiles.any((p) => p.id == id)) {
      _activeProfileId = id;
      await _save();
      notifyListeners();
    }
  }

  /// Update the selected model for the active profile
  Future<void> setActiveModel(String model) async {
    final profile = activeProfile;
    if (profile != null) {
      profile.selectedModel = model;
      profile.updatedAt = DateTime.now();
      await _save();
      notifyListeners();
    }
  }

  /// Get a profile by ID
  ApiProfile? getProfile(String id) {
    try {
      return _profiles.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
