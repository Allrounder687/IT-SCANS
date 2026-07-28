import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessibilityProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  
  static const String _largeTextKey = 'is_large_text_enabled';
  
  bool _isLargeTextEnabled = false;

  AccessibilityProvider(this._prefs) {
    _isLargeTextEnabled = _prefs.getBool(_largeTextKey) ?? false;
  }

  bool get isLargeTextEnabled => _isLargeTextEnabled;

  Future<void> toggleLargeText() async {
    _isLargeTextEnabled = !_isLargeTextEnabled;
    await _prefs.setBool(_largeTextKey, _isLargeTextEnabled);
    notifyListeners();
  }

  Future<void> setLargeText(bool value) async {
    if (_isLargeTextEnabled != value) {
      _isLargeTextEnabled = value;
      await _prefs.setBool(_largeTextKey, _isLargeTextEnabled);
      notifyListeners();
    }
  }
}
