import 'package:arus_finance/core/services/security_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('recovery code is shown once while only a verifier is stored', () async {
    const storage = FlutterSecureStorage();
    final security = SecurityService(storage: storage);

    await security.setPin('1234');
    final code = await security.createRecoveryCode();

    expect(
      code,
      matches(RegExp(r'^[A-HJ-NP-Z2-9]{4}(?:-[A-HJ-NP-Z2-9]{4}){3}$')),
    );
    expect(await security.hasRecoveryCode(), isTrue);
    expect(await security.verifyRecoveryCode(code), isTrue);

    final humanTyped = code.toLowerCase().replaceAll('-', ' ');
    expect(await security.verifyRecoveryCode(humanTyped), isTrue);

    final stored = await storage.readAll();
    final normalized = code.replaceAll('-', '');
    expect(stored.values.join('\n'), isNot(contains(normalized)));
  });

  test('successful recovery resets PIN and rotates the old recovery code', () async {
    const storage = FlutterSecureStorage();
    final security = SecurityService(storage: storage);

    await security.setPin('1234');
    final oldCode = await security.createRecoveryCode();

    final newCode = await security.resetPinWithRecoveryCode(
      recoveryCode: oldCode,
      newPin: '5678',
    );

    expect(newCode, isNotNull);
    expect(newCode, isNot(oldCode));
    expect(await security.verifyPin('5678'), isTrue);
    expect(await security.verifyRecoveryCode(oldCode), isFalse);
    expect(await security.verifyRecoveryCode(newCode!), isTrue);
  });

  test('recovery attempts have an independent local lockout', () async {
    const storage = FlutterSecureStorage();
    final security = SecurityService(storage: storage);

    await security.setPin('1234');
    final code = await security.createRecoveryCode();

    for (var i = 0; i < 5; i++) {
      expect(await security.verifyRecoveryCode('SALAH'), isFalse);
    }

    final lockedUntil = await security.recoveryLockedUntil();
    expect(lockedUntil, isNotNull);
    expect(lockedUntil!.isAfter(DateTime.now().toUtc()), isTrue);
    expect(await security.verifyRecoveryCode(code), isFalse);
    expect(await security.verifyPin('1234'), isTrue);
  });

  test('disabling app PIN also removes local recovery material', () async {
    const storage = FlutterSecureStorage();
    final security = SecurityService(storage: storage);

    await security.setPin('1234');
    await security.createRecoveryCode();
    expect(await security.hasRecoveryCode(), isTrue);

    await security.disablePin();

    expect(await security.hasPin(), isFalse);
    expect(await security.hasRecoveryCode(), isFalse);
  });
}
