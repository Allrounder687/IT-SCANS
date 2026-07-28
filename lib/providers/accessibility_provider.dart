import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessibilityProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  
  static const String _largeTextKey = 'is_large_text_enabled';
  static const String _textScaleKey = 'text_scale_factor';
  
  bool _isLargeTextEnabled = false;
  double _textScaleFactor = 1.3;

  AccessibilityProvider(this._prefs) {
    _isLargeTextEnabled = _prefs.getBool(_largeTextKey) ?? false;
    _textScaleFactor = _prefs.getDouble(_textScaleKey) ?? 1.3;
  }

  bool get isLargeTextEnabled => _isLargeTextEnabled;
  double get textScaleFactor => _textScaleFactor;
  
  double get currentScale => _isLargeTextEnabled ? _textScaleFactor : 1.0;

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

  Future<void> setTextScaleFactor(double value) async {
    if (_textScaleFactor != value) {
      _textScaleFactor = value;
      await _prefs.setDouble(_textScaleKey, _textScaleFactor);
      if (!_isLargeTextEnabled) {
        _isLargeTextEnabled = true;
        await _prefs.setBool(_largeTextKey, true);
      }
      notifyListeners();
    }
  }
}
