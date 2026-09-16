import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScreenProtectionService extends ChangeNotifier {
  ScreenProtectionService({
    MethodChannel? channel,
    Future<SharedPreferences> Function()? preferences,
  })  : _channel = channel ?? const MethodChannel(_channelName),
        _preferences = preferences ?? SharedPreferences.getInstance;

  static final ScreenProtectionService instance = ScreenProtectionService();

  static const _channelName = 'arus.finance/screen_protection';
  static const _enabledKey = 'screen_protection_enabled_v1';

  final MethodChannel _channel;
  final Future<SharedPreferences> Function() _preferences;

  bool _enabled = true;
  bool _loaded = false;
  bool _supported = false;

  bool get enabled => _enabled;
  bool get loaded => _loaded;
  bool get supported => _supported;

  Future<void> loadAndApply() async {
    var preferred = true;
    try {
      final prefs = await _preferences();
      preferred = prefs.getBool(_enabledKey) ?? true;
    } catch (_) {
      // A preference-store failure must never weaken startup protection.
      // Android has already started with FLAG_SECURE from native hardening, so
      // fall back to the secure default and keep the app usable.
      preferred = true;
    }

    _supported = await _nativeSupported();
    _enabled = preferred;
    if (_supported) {
      try {
        await _applyNative(preferred);
      } catch (_) {
        // Android starts with FLAG_SECURE already set by the native hardener.
        // If Dart cannot apply a saved OFF preference, report the truthful
        // fail-secure state instead of pretending screenshots are allowed.
        _enabled = true;
        try {
          await _applyNative(true);
        } catch (_) {
          _supported = false;
        }
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    if (!_loaded) {
      await loadAndApply();
    }
    if (!_supported) {
      throw StateError(
        'Perlindungan screenshot runtime belum tersedia di platform ini.',
      );
    }

    final previous = _enabled;

    // Apply native state first. Never persist a setting the OS window did not
    // actually accept, otherwise the next launch could misrepresent protection.
    await _applyNative(enabled);

    try {
      final prefs = await _preferences();
      final saved = await prefs.setBool(_enabledKey, enabled);
      if (!saved) {
        throw StateError('Preferensi perlindungan layar belum berhasil disimpan.');
      }
    } catch (_) {
      // Persistence failed after the OS flag changed. Restore the last known
      // state so UI, local preference and native window protection stay aligned.
      try {
        await _applyNative(previous);
        _enabled = previous;
      } catch (_) {
        // The last confirmed native state is the requested value. Stop claiming
        // that runtime control is reliable until the next fresh app start.
        _enabled = enabled;
        _supported = false;
      }
      notifyListeners();
      throw StateError(
        'Preferensi perlindungan layar belum berhasil disimpan. Perubahan native dibatalkan bila memungkinkan.',
      );
    }

    _enabled = enabled;
    notifyListeners();
  }

  Future<bool> _nativeSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> _applyNative(bool enabled) async {
    try {
      final applied = await _channel.invokeMethod<bool>(
        'setEnabled',
        <String, Object?>{'enabled': enabled},
      );
      if (applied != true) {
        throw StateError('Perangkat tidak mengonfirmasi perubahan perlindungan layar.');
      }
    } on MissingPluginException {
      throw StateError('Bridge perlindungan layar tidak tersedia.');
    } on PlatformException catch (error) {
      throw StateError(
        error.message ?? 'Perlindungan layar gagal diterapkan.',
      );
    }
  }
}
