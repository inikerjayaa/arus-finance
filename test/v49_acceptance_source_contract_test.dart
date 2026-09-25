import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('V49 physical UAT source contracts', () {
    test('settings exposes an explicit safe Matikan PIN action', () {
      final settings = File('lib/features/settings/settings_screen.dart').readAsStringSync();
      final security = File('lib/core/services/security_service.dart').readAsStringSync();

      expect(settings, contains('Matikan PIN'));
      expect(settings, contains('disablePin'));
      expect(settings, contains('verifyPin'));
      expect(security, contains('Future<void> disablePin()'));
      expect(security, contains("_storage.write(key: _bioKey, value: '0')"));
    });

    test('reachable settings contains approved Tentang SAKU origin copy', () {
      final settings = File('lib/features/settings/settings_screen.dart').readAsStringSync();

      expect(settings, contains('Tentang SAKU'));
      expect(settings, contains('SAKU berawal dari hal sederhana'));
      expect(settings, contains('Istri saya biasa mencatat pengeluaran secara manual'));
      expect(settings, contains('Data keuangan utama tetap tersimpan di perangkatmu'));
    });

    test('V49 does not regress local-first security service semantics', () {
      final security = File('lib/core/services/security_service.dart').readAsStringSync();

      expect(security, contains('FlutterSecureStorage'));
      expect(security, contains('Argon2id'));
      expect(security, contains('biometricEnabled'));
      expect(security, contains('authenticateBiometric'));
    });
  });
}
