import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileService extends ChangeNotifier {
  static const _nameKey = 'profile_name_v1';

  String? _name;
  String? get name => _name;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_nameKey)?.trim();
    _name = raw == null || raw.isEmpty ? null : raw;
  }

  Future<void> saveName(String value) async {
    final clean = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) {
      throw ArgumentError('Nama tidak boleh kosong.');
    }
    if (clean.length > 40) {
      throw ArgumentError('Nama maksimal 40 karakter.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, clean);
    _name = clean;
    notifyListeners();
  }
}
