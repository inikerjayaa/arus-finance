import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cold-start brand splash is visible and not covered by LockGate', () async {
    final source = await File('lib/app.dart').readAsString();

    expect(
      source,
      contains(
        'static const _minimumColdStartSplash = Duration(milliseconds: 1200);',
      ),
    );
    expect(source, contains('bool _minimumSplashElapsed = false;'));
    expect(source, contains('!_minimumSplashElapsed ||'));
    expect(source, contains('await Future<void>.delayed(remaining);'));
    expect(
      source,
      contains('if (_isBooting) return _buildPrivacyProtectedHome(child);'),
    );
    expect(
      source,
      contains('return _buildPrivacyProtectedHome(_buildRootLock(child));'),
    );
    expect(
      source,
      contains('if (_isBooting) return const SakuSplashScreen();'),
    );
  });
}
