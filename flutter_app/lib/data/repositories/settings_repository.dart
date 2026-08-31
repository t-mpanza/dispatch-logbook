import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';

class SettingsRepository extends ChangeNotifier {
  static const String _keyDespatcherName = 'despatcher_name';
  String _despatcherName = 'Theolus';
  String get despatcherName => _despatcherName;

  Future<void> loadSettings() async {
    final sp = await SharedPreferences.getInstance();
    final name = sp.getString(_keyDespatcherName) ??
        await DatabaseService.getSetting(_keyDespatcherName);

    if (name != null && name.trim().isNotEmpty) {
      _despatcherName = name.trim();
      notifyListeners();
    }
  }

  Future<void> saveDespatcherName(String name) async {
    _despatcherName = name.trim().isEmpty ? 'Theolus' : name.trim();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keyDespatcherName, _despatcherName);
    await DatabaseService.saveSetting(_keyDespatcherName, _despatcherName);
    notifyListeners();
  }
}
