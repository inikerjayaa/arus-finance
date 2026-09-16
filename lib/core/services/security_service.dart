import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  SecurityService({FlutterSecureStorage? storage, LocalAuthentication? auth})
      : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(resetOnError: false),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device),
        ),
        _auth = auth ?? LocalAuthentication();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _auth;

  static const _pinHashKey = 'arus_pin_hash_v2';
  static const _pinSaltKey = 'arus_pin_salt_v2';
  static const _bioKey = 'arus_biometric_enabled_v1';
  static const _failedAttemptsKey = 'arus_pin_failed_attempts_v1';
  static const _lockUntilKey = 'arus_pin_lock_until_v1';

  String? _lastBiometricError;
  String? get lastBiometricError => _lastBiometricError;

  Future<bool> hasPin() async => (await _storage.read(key: _pinHashKey))?.isNotEmpty == true;
  Future<bool> biometricEnabled() async => (await _storage.read(key: _bioKey)) == '1';

  Future<bool> canUseBiometrics() async {
    try {
      if (!await _auth.isDeviceSupported() || !await _auth.canCheckBiometrics) {
        return false;
      }

      // Prefer the enrolled-biometric list when the platform reports it
      // correctly. Some Android/OEM combinations return an empty list even
      // though BiometricPrompt can authenticate an enrolled fingerprint.
      // Do not hide Arus' biometric option solely because that advisory list
      // is empty on Android; the actual authenticate(biometricOnly: true)
      // call remains the source of truth.
      try {
        if ((await _auth.getAvailableBiometrics()).isNotEmpty) return true;
      } on LocalAuthException {
        // Capability checks above succeeded. Android gets a runtime-auth
        // fallback below; other platforms stay conservative.
      } catch (_) {
        // Same rationale as above for vendor-specific enumeration failures.
      }
      return defaultTargetPlatform == TargetPlatform.android;
    } catch (_) {
      return false;
    }
  }

  Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      throw ArgumentError('PIN harus 4–8 digit.');
    }
    final saltBytes = _randomBytes(16);
    final hashBytes = await _derivePinHash(pin, saltBytes);
    await _storage.write(key: _pinSaltKey, value: base64UrlEncode(saltBytes));
    await _storage.write(key: _pinHashKey, value: base64UrlEncode(hashBytes));
    await _storage.delete(key: _failedAttemptsKey);
    await _storage.delete(key: _lockUntilKey);
  }

  Future<bool> verifyPin(String pin) async {
    final lockUntil = await pinLockedUntil();
    if (lockUntil != null && lockUntil.isAfter(DateTime.now().toUtc())) return false;

    final saltRaw = await _storage.read(key: _pinSaltKey);
    final storedRaw = await _storage.read(key: _pinHashKey);
    if (saltRaw == null || storedRaw == null) return false;

    final expected = base64Url.decode(storedRaw);
    final actual = await _derivePinHash(pin, base64Url.decode(saltRaw));
    final ok = _constantTimeEquals(actual, expected);
    if (ok) {
      await _storage.delete(key: _failedAttemptsKey);
      await _storage.delete(key: _lockUntilKey);
      return true;
    }

    final attempts = (int.tryParse(await _storage.read(key: _failedAttemptsKey) ?? '') ?? 0) + 1;
    await _storage.write(key: _failedAttemptsKey, value: '$attempts');
    if (attempts >= 5) {
      final exponent = (attempts - 5).clamp(0, 5).toInt();
      final seconds = 30 * (1 << exponent);
      final until = DateTime.now().toUtc().add(Duration(seconds: seconds));
      await _storage.write(key: _lockUntilKey, value: until.toIso8601String());
    }
    return false;
  }

  Future<DateTime?> pinLockedUntil() async {
    final raw = await _storage.read(key: _lockUntilKey);
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw)?.toUtc();
    if (parsed == null || !parsed.isAfter(DateTime.now().toUtc())) {
      await _storage.delete(key: _lockUntilKey);
      return null;
    }
    return parsed;
  }

  Future<void> disablePin() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _pinSaltKey);
    await _storage.delete(key: _failedAttemptsKey);
    await _storage.delete(key: _lockUntilKey);
    await _storage.write(key: _bioKey, value: '0');
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    if (enabled && !await canUseBiometrics()) {
      throw StateError('Biometrik tidak tersedia pada perangkat ini.');
    }
    await _storage.write(key: _bioKey, value: enabled ? '1' : '0');
  }

  Future<bool> authenticateBiometric() async {
    _lastBiometricError = null;
    if (!await biometricEnabled()) return false;
    try {
      return await _auth.authenticate(
        localizedReason: 'Buka Arus Finance',
        biometricOnly: true,
        // Do not let the plugin re-open the biometric prompt after an OS
        // lifecycle transition. Cancel must return control to Arus so the
        // user can fall back to the app PIN. LockGate owns any later retry.
        persistAcrossBackgrounding: false,
      );
    } on LocalAuthException catch (error) {
      _lastBiometricError = switch (error.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.userRequestedFallback => null,
        LocalAuthExceptionCode.noBiometricsEnrolled =>
          'Belum ada sidik jari/biometrik yang terdaftar untuk aplikasi.',
        LocalAuthExceptionCode.noBiometricHardware =>
          'Sensor biometrik tidak terdeteksi oleh Android.',
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable =>
          'Sensor biometrik sedang tidak tersedia. Coba lagi.',
        LocalAuthExceptionCode.temporaryLockout =>
          'Biometrik dikunci sementara karena terlalu banyak percobaan. Coba lagi nanti.',
        LocalAuthExceptionCode.biometricLockout =>
          'Biometrik dikunci oleh perangkat. Buka kunci HP sekali lalu coba lagi.',
        LocalAuthExceptionCode.noCredentialsSet =>
          'Kunci layar perangkat belum siap untuk autentikasi biometrik.',
        LocalAuthExceptionCode.uiUnavailable =>
          'Prompt biometrik tidak dapat ditampilkan oleh perangkat.',
        LocalAuthExceptionCode.authInProgress =>
          'Permintaan biometrik lain masih berjalan.',
        LocalAuthExceptionCode.timeout =>
          'Pembacaan biometrik berakhir karena batas waktu.',
        LocalAuthExceptionCode.deviceError || LocalAuthExceptionCode.unknownError =>
          error.description ?? 'Perangkat gagal memproses autentikasi biometrik.',
      };
      return false;
    } catch (_) {
      _lastBiometricError = 'Biometrik belum dapat digunakan pada perangkat ini.';
      return false;
    }
  }

  Future<List<int>> _derivePinHash(String pin, List<int> salt) async {
    final kdf = Argon2id(
      memory: 16 * 1024,
      parallelism: 2,
      iterations: 2,
      hashLength: 32,
    );
    final key = await kdf.deriveKeyFromPassword(password: pin, nonce: salt);
    return key.extractBytes();
  }

  List<int> _randomBytes(int count) {
    final random = Random.secure();
    return List<int>.generate(count, (_) => random.nextInt(256));
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
