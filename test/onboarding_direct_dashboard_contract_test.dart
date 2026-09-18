import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fresh onboarding completion enters app unlocked without a second PIN gate',
      () async {
    final source = await File('lib/app.dart').readAsString();

    expect(source, contains('_onboardingJustCompleted = true;'));
    expect(source, contains('startUnlocked: _onboardingJustCompleted'));
    expect(source, contains('return AppShell('));
  });
}
