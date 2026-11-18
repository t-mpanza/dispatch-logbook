import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/scan_sounds.dart';
import '../services/database_service.dart';

class SettingsRepository extends ChangeNotifier {
  static const String _keyDespatcherName = 'despatcher_name';
  static const String _keySunlightMode = 'is_sunlight_mode';
  static const String _keyWelcomeSeen = 'welcome_seen_v3';
  static const String _keyNfcEnabled = 'nfc_enabled';
  static const String _keyScanSoundsEnabled = 'scan_sounds_enabled';

  String _despatcherName = 'Theolus';
  String get despatcherName => _despatcherName;

  bool _isSunlightMode = false;
  bool get isSunlightMode => _isSunlightMode;

  bool _welcomeSeen = false;
  bool get welcomeSeen => _welcomeSeen;

  /// NFC tyre-scanning kill switch (persisted).
  bool _nfcEnabled = true;
  bool get nfcEnabled => _nfcEnabled;

  /// Scanner audio switch (persisted). Haptics always fire — this mutes
  /// only the two scan sounds.
  bool _scanSoundsEnabled = true;
  bool get scanSoundsEnabled => _scanSoundsEnabled;

  /// Dispatch tab unlock — IN MEMORY ONLY. Closing the app re-hides the
  /// tab (night shift can't stumble onto it).
  bool _dispatchUnlocked = false;
  bool get dispatchUnlocked => _dispatchUnlocked;

  Future<void> loadSettings() async {
    final sp = await SharedPreferences.getInstance();
    // The DB fallbacks are best-effort: a database hiccup must NEVER
    // propagate out of loadSettings (it runs before runApp — an uncaught
    // error there bricks the app at the splash, device report
    // 2026-11-18).
    String? name;
    String? dbSunlight;
    try {
      name = sp.getString(_keyDespatcherName) ??
          await DatabaseService.getSetting(_keyDespatcherName);
    } catch (e) {
      debugPrint('Settings DB fallback failed (using prefs): $e');
      name = sp.getString(_keyDespatcherName);
    }

    if (name != null && name.trim().isNotEmpty) {
      _despatcherName = name.trim();
    }

    final sunlightVal = sp.getBool(_keySunlightMode);
    if (sunlightVal != null) {
      _isSunlightMode = sunlightVal;
    } else {
      try {
        dbSunlight = await DatabaseService.getSetting(_keySunlightMode);
      } catch (e) {
        debugPrint('Settings DB fallback failed (using prefs): $e');
      }
      if (dbSunlight != null) {
        _isSunlightMode =
            dbSunlight == '1' || dbSunlight.toLowerCase() == 'true';
      }
    }

    _welcomeSeen = sp.getBool(_keyWelcomeSeen) ?? false;

    final nfcVal = sp.getBool(_keyNfcEnabled);
    if (nfcVal != null) {
      _nfcEnabled = nfcVal;
    }

    final soundsVal = sp.getBool(_keyScanSoundsEnabled);
    if (soundsVal != null) {
      _scanSoundsEnabled = soundsVal;
    }
    ScanSounds.muted = !_scanSoundsEnabled;
    notifyListeners();
  }

  Future<void> saveDespatcherName(String name) async {
    _despatcherName = name.trim().isEmpty ? 'Theolus' : name.trim();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keyDespatcherName, _despatcherName);
    await DatabaseService.saveSetting(_keyDespatcherName, _despatcherName);
    notifyListeners();
  }

  Future<void> toggleSunlightMode() async {
    _isSunlightMode = !_isSunlightMode;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_keySunlightMode, _isSunlightMode);
    await DatabaseService.saveSetting(
      _keySunlightMode,
      _isSunlightMode ? '1' : '0',
    );
    notifyListeners();
  }

  Future<void> markWelcomeSeen() async {
    _welcomeSeen = true;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_keyWelcomeSeen, true);
    notifyListeners();
  }

  Future<void> setNfcEnabled(bool enabled) async {
    _nfcEnabled = enabled;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_keyNfcEnabled, enabled);
    notifyListeners();
  }

  Future<void> setScanSoundsEnabled(bool enabled) async {
    _scanSoundsEnabled = enabled;
    ScanSounds.muted = !enabled;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_keyScanSoundsEnabled, enabled);
    notifyListeners();
  }

  /// Unlock the Dispatch tab for this launch only.
  void unlockDispatch() {
    _dispatchUnlocked = true;
    notifyListeners();
  }
}
