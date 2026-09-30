import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-controlled switch for SAKU's local intelligence layer.
///
/// The feature is enabled by default but is entirely optional. Toggling this
/// never changes ledger/accounting data; it only controls whether local
/// read-only analysis is allowed to run.
class LocalAiPreferencesService extends ChangeNotifier {
  static const _enabledKey = 'saku_local_ai_enabled';

  bool _enabled = true;
  bool get enabled => _enabled;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    _enabled = value;
    notifyListeners();
  }
}
