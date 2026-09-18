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
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.unlocked_this_device,
          ),
        ),
        _auth = auth ?? LocalAuthentication();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _auth;

  static const _pinHashKey = 'arus_pin_hash_v2';
  static const _pinSaltKey = 'arus_pin_salt_v2';
  static const _bioKey = 'arus_biometric_enabled_v1';
  static const _failedAttemptsKey = 'arus_pin_failed_attempts_v1';
  static const _lockUntilKey = 'arus_pin_lock_until_v1';

  static const _recoveryVerifierKey = 'arus_pin_recovery_verifier_v1';
  static const _recoveryFailedAttemptsKey =
      'arus_pin_recovery_failed_attempts_v1';
  static const _recoveryLockUntilKey = 'arus_pin_recovery_lock_until_v1';
  static const _recoveryAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String? _lastBiometricError;
  String? get lastBiometricError => _lastBiometricError;

  Future<bool> hasPin() async =>
      (await _storage.read(key: _pinHashKey))?.isNotEmpty == true;

  Future<bool> biometricEnabled() async =>
      (await _storage.read(key: _bioKey)) == '1';

  Future<bool> hasRecoveryCode() async =>
      (await _storage.read(key: _recoveryVerifierKey))?.isNotEmpty == true;

  Future<bool> canUseBiometrics() async {
    try {
      if (!await _auth.isDeviceSupported() || !await _auth.canCheckBiometrics) {
        return false;
      }

      // Prefer the enrolled-biometric list when the platform reports it
      // correctly. Some Android/OEM combinations return an empty list even
      // though BiometricPrompt can authenticate an enrolled fingerprint.
      // Do not hide SAKU's biometric option solely because that advisory list
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
    _validatePin(pin);
    final saltBytes = _randomBytes(16);
    final hashBytes = await _deriveSecretHash(pin, saltBytes);
    await _storage.write(
      key: _pinSaltKey,
      value: base64UrlEncode(saltBytes),
    );
    await _storage.write(
      key: _pinHashKey,
      value: base64UrlEncode(hashBytes),
    );
    await _storage.delete(key: _failedAttemptsKey);
    await _storage.delete(key: _lockUntilKey);
  }

  Future<bool> verifyPin(String pin) async {
    final lockUntil = await pinLockedUntil();
    if (lockUntil != null && lockUntil.isAfter(DateTime.now().toUtc())) {
      return false;
    }

    final saltRaw = await _storage.read(key: _pinSaltKey);
    final storedRaw = await _storage.read(key: _pinHashKey);
    if (saltRaw == null || storedRaw == null) return false;

    final expected = base64Url.decode(storedRaw);
    final actual = await _deriveSecretHash(pin, base64Url.decode(saltRaw));
    final ok = _constantTimeEquals(actual, expected);
    if (ok) {
      await _storage.delete(key: _failedAttemptsKey);
      await _storage.delete(key: _lockUntilKey);
      return true;
    }

    final attempts =
        (int.tryParse(await _storage.read(key: _failedAttemptsKey) ?? '') ??
            0) +
        1;
    await _storage.write(key: _failedAttemptsKey, value: '$attempts');
    if (attempts >= 5) {
      final exponent = (attempts - 5).clamp(0, 5).toInt();
      final seconds = 30 * (1 << exponent);
      final until = DateTime.now().toUtc().add(Duration(seconds: seconds));
      await _storage.write(key: _lockUntilKey, value: until.toIso8601String());
    }
    return false;
  }

  Future<DateTime?> pinLockedUntil() => _activeLockUntil(
    key: _lockUntilKey,
  );

  /// Creates a new recovery secret and replaces any previous one.
  ///
  /// The plaintext is returned exactly once to the caller so onboarding or
  /// Settings can ask the user to save it. Only an Argon2 verifier is stored.
  Future<String> createRecoveryCode() async {
    final raw = _generateRecoveryCode();
    await _writeRecoveryVerifier(raw);
    await _clearRecoveryFailures();
    return _formatRecoveryCode(raw);
  }

  Future<bool> verifyRecoveryCode(String code) async {
    final lockUntil = await recoveryLockedUntil();
    if (lockUntil != null && lockUntil.isAfter(DateTime.now().toUtc())) {
      return false;
    }

    final verifierRaw = await _storage.read(key: _recoveryVerifierKey);
    if (verifierRaw == null || verifierRaw.isEmpty) return false;

    final normalized = _normalizeRecoveryCode(code);
    var ok = false;
    try {
      final payload = jsonDecode(verifierRaw) as Map<String, dynamic>;
      if (payload['v'] != 1 ||
          payload['salt'] is! String ||
          payload['hash'] is! String ||
          !_isValidRecoveryCode(normalized)) {
        ok = false;
      } else {
        final expected = base64Url.decode(payload['hash'] as String);
        final salt = base64Url.decode(payload['salt'] as String);
        final actual = await _deriveSecretHash(normalized, salt);
        ok = _constantTimeEquals(actual, expected);
      }
    } catch (_) {
      // Corrupt or legacy verifier fails closed; never bypass local recovery.
      ok = false;
    }

    if (ok) {
      await _clearRecoveryFailures();
      return true;
    }
    await _recordRecoveryFailure();
    return false;
  }

  Future<DateTime?> recoveryLockedUntil() => _activeLockUntil(
    key: _recoveryLockUntilKey,
  );

  /// Resets the PIN using the local recovery secret and rotates that secret.
  /// Returns the new one-time-visible recovery code on success.
  Future<String?> resetPinWithRecoveryCode({
    required String recoveryCode,
    required String newPin,
  }) async {
    _validatePin(newPin);
    if (!await verifyRecoveryCode(recoveryCode)) return null;
    return _rotateRecoveryAndSetPin(newPin);
  }

  /// Allows PIN reset only through biometrics the user already enabled in SAKU.
  /// A successful reset also rotates the recovery code.
  Future<String?> resetPinWithBiometric({required String newPin}) async {
    _validatePin(newPin);
    if (!await biometricEnabled()) return null;
    if (!await authenticateBiometric()) return null;
    return _rotateRecoveryAndSetPin(newPin);
  }

  Future<void> disablePin() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _pinSaltKey);
    await _storage.delete(key: _failedAttemptsKey);
    await _storage.delete(key: _lockUntilKey);
    await _storage.delete(key: _recoveryVerifierKey);
    await _clearRecoveryFailures();
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
        localizedReason: 'Buka SAKU',
        biometricOnly: true,
        // Do not let the plugin re-open the biometric prompt after an OS
        // lifecycle transition. Cancel must return control to SAKU so the
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
        LocalAuthExceptionCode.deviceError ||
        LocalAuthExceptionCode.unknownError =>
          error.description ??
              'Perangkat gagal memproses autentikasi biometrik.',
      };
      return false;
    } catch (_) {
      _lastBiometricError =
          'Biometrik belum dapat digunakan pada perangkat ini.';
      return false;
    }
  }

  Future<String> _rotateRecoveryAndSetPin(String newPin) async {
    final oldVerifier = await _storage.read(key: _recoveryVerifierKey);
    final raw = _generateRecoveryCode();
    await _writeRecoveryVerifier(raw);
    try {
      await setPin(newPin);
    } catch (_) {
      // Keep recovery usable if the PIN write itself fails. A failed rollback
      // is intentionally allowed to surface instead of claiming recovery is OK.
      if (oldVerifier == null) {
        await _storage.delete(key: _recoveryVerifierKey);
      } else {
        await _storage.write(key: _recoveryVerifierKey, value: oldVerifier);
      }
      rethrow;
    }
    await _clearRecoveryFailures();
    return _formatRecoveryCode(raw);
  }

  Future<void> _writeRecoveryVerifier(String normalizedCode) async {
    final salt = _randomBytes(16);
    final hash = await _deriveSecretHash(normalizedCode, salt);
    final payload = jsonEncode({
      'v': 1,
      'salt': base64UrlEncode(salt),
      'hash': base64UrlEncode(hash),
    });
    await _storage.write(key: _recoveryVerifierKey, value: payload);
  }

  Future<void> _recordRecoveryFailure() async {
    final attempts =
        (int.tryParse(
              await _storage.read(key: _recoveryFailedAttemptsKey) ?? '',
            ) ??
            0) +
        1;
    await _storage.write(
      key: _recoveryFailedAttemptsKey,
      value: '$attempts',
    );
    if (attempts >= 5) {
      final exponent = (attempts - 5).clamp(0, 5).toInt();
      final seconds = 30 * (1 << exponent);
      final until = DateTime.now().toUtc().add(Duration(seconds: seconds));
      await _storage.write(
        key: _recoveryLockUntilKey,
        value: until.toIso8601String(),
      );
    }
  }

  Future<void> _clearRecoveryFailures() async {
    await _storage.delete(key: _recoveryFailedAttemptsKey);
    await _storage.delete(key: _recoveryLockUntilKey);
  }

  Future<DateTime?> _activeLockUntil({required String key}) async {
    final raw = await _storage.read(key: key);
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw)?.toUtc();
    if (parsed == null || !parsed.isAfter(DateTime.now().toUtc())) {
      await _storage.delete(key: key);
      return null;
    }
    return parsed;
  }

  void _validatePin(String pin) {
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      throw ArgumentError('PIN harus 4–8 digit.');
    }
  }

  String _generateRecoveryCode() {
    final random = Random.secure();
    return List<String>.generate(
      16,
      (_) => _recoveryAlphabet[random.nextInt(_recoveryAlphabet.length)],
    ).join();
  }

  String _normalizeRecoveryCode(String value) => value
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]'), '');

  bool _isValidRecoveryCode(String value) =>
      value.length == 16 &&
      value.split('').every(_recoveryAlphabet.contains);

  String _formatRecoveryCode(String value) => [
    value.substring(0, 4),
    value.substring(4, 8),
    value.substring(8, 12),
    value.substring(12, 16),
  ].join('-');

  Future<List<int>> _deriveSecretHash(String secret, List<int> salt) async {
    final kdf = Argon2id(
      memory: 16 * 1024,
      parallelism: 2,
      iterations: 2,
      hashLength: 32,
    );
    final key = await kdf.deriveKeyFromPassword(
      password: secret,
      nonce: salt,
    );
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
