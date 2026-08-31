import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';

class SettingsRepository extends ChangeNotifier {
  static const String _keyDespatcherName = 'despatcher_name';
  static const String _keySunlightMode = 'is_sunlight_mode';

  String _despatcherName = 'Theolus';
  String get despatcherName => _despatcherName;

  bool _isSunlightMode = false;
  bool get isSunlightMode => _isSunlightMode;

  Future<void> loadSettings() async {
    final sp = await SharedPreferences.getInstance();
    final name = sp.getString(_keyDespatcherName) ??
        await DatabaseService.getSetting(_keyDespatcherName);

    if (name != null && name.trim().isNotEmpty) {
      _despatcherName = name.trim();
    }

    final sunlightVal = sp.getBool(_keySunlightMode);
    if (sunlightVal != null) {
      _isSunlightMode = sunlightVal;
    } else {
      final dbSunlight = await DatabaseService.getSetting(_keySunlightMode);
      if (dbSunlight != null) {
        _isSunlightMode = dbSunlight == '1' || dbSunlight.toLowerCase() == 'true';
      }
    }
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
    await DatabaseService.saveSetting(_keySunlightMode, _isSunlightMode ? '1' : '0');
    notifyListeners();
  }
}
