import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first PIN setup lives in Settings and immediately hands off recovery code',
      () async {
    final source =
        await File('lib/features/settings/settings_screen.dart').readAsString();

    expect(source, contains("labelText: creatingPin ? 'PIN' : 'PIN baru'"));
    expect(source, contains("labelText: 'Konfirmasi PIN'"));
    expect(source, contains('recoveryCode = await widget.security.createRecoveryCode();'));
    expect(source, contains('initialCode: recoveryCode'));
    expect(source, contains("title: Text(_hasPin == true ? 'Ubah PIN' : 'Buat PIN')"));
  });
}
