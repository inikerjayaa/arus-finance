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

    test('reachable settings contains exact approved Tentang SAKU copy', () {
      final settings = File('lib/features/settings/settings_screen.dart').readAsStringSync();
      const approved = 'SAKU berawal dari cerita sederhana. Dulu istriku suka ribet nyatat pengeluaran manual, jadi aku coba bikin sesuatu yang bisa mempermudah dia. Dari sana lahirlah SAKU: aplikasi catat keuangan yang simpel, cepat, dan tetap menjaga privasimu.';

      expect(settings, contains('Tentang SAKU'));
      expect(settings, contains(approved));
    });

    test('Flutter splash and About share the canonical SAKU mark implementation', () {
      final settings = File('lib/features/settings/settings_screen.dart').readAsStringSync();
      final splash = File('lib/shared/saku_splash.dart').readAsStringSync();

      expect(settings, contains('SakuBrandMark'));
      expect(splash, contains('class SakuBrandMark'));
      expect(splash, contains('SakuBrandMark(size: markSize)'));
      expect(splash, isNot(contains('Image.network')));
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
