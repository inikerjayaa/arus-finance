import 'package:arus_finance/core/services/security_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

class _FakeLocalAuthentication extends LocalAuthentication {
  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> get canCheckBiometrics async => true;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async =>
      const [BiometricType.strong];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('disabling PIN also disables biometrics and recovery credentials', () async {
    const storage = FlutterSecureStorage();
    final security = SecurityService(
      storage: storage,
      auth: _FakeLocalAuthentication(),
    );

    await security.setPin('2468');
    await security.createRecoveryCode();
    await security.setBiometricEnabled(true);

    expect(await security.hasPin(), isTrue);
    expect(await security.hasRecoveryCode(), isTrue);
    expect(await security.biometricEnabled(), isTrue);

    await security.disablePin();

    expect(await security.hasPin(), isFalse);
    expect(await security.hasRecoveryCode(), isFalse);
    expect(await security.biometricEnabled(), isFalse);
    expect(await security.verifyPin('2468'), isFalse);
  });
}
