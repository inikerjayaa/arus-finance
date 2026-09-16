import 'package:arus_finance/core/services/security_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

class _FakeLocalAuthentication extends LocalAuthentication {
  _FakeLocalAuthentication({
    required this.deviceSupported,
    required this.canCheck,
    required this.enrolled,
  });

  final bool deviceSupported;
  final bool canCheck;
  final List<BiometricType> enrolled;

  @override
  Future<bool> isDeviceSupported() async => deviceSupported;

  @override
  Future<bool> get canCheckBiometrics async => canCheck;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => enrolled;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'Android keeps biometric option available when OEM enrolled list is empty',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final service = SecurityService(
        auth: _FakeLocalAuthentication(
          deviceSupported: true,
          canCheck: true,
          enrolled: const [],
        ),
      );

      expect(await service.canUseBiometrics(), isTrue);
    },
  );

  test(
    'non-Android remains conservative when enrolled biometric list is empty',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final service = SecurityService(
        auth: _FakeLocalAuthentication(
          deviceSupported: true,
          canCheck: true,
          enrolled: const [],
        ),
      );

      expect(await service.canUseBiometrics(), isFalse);
    },
  );

  test('hardware capability failure still disables biometric option', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final service = SecurityService(
      auth: _FakeLocalAuthentication(
        deviceSupported: true,
        canCheck: false,
        enrolled: const [BiometricType.strong],
      ),
    );

    expect(await service.canUseBiometrics(), isFalse);
  });
}
