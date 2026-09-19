import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cold-start brand splash is not covered by LockGate', () async {
    final source = await File('lib/app.dart').readAsString();

    expect(
      source,
      contains(
        'bool get _isBooting =>\n'
        '      _onboardingDone == null || widget.controller.initializing;',
      ),
    );
    expect(source, contains('if (_isBooting) {\n      return _buildPrivacyProtectedHome(child);'));
    expect(source, contains('return _buildPrivacyProtectedHome(_buildRootLock(child));'));
    expect(source, contains('if (_isBooting) {\n      return const SakuSplashScreen();'));
  });
}
