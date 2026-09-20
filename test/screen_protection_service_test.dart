import 'package:arus_finance/core/services/screen_protection_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('arus.finance/screen_protection.test');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('screen protection defaults OFF and applies non-secure native state', () async {
    SharedPreferences.setMockInitialValues({});
    final applied = <bool>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isSupported') return true;
      if (call.method == 'setEnabled') {
        applied.add((call.arguments as Map)['enabled'] as bool);
        return true;
      }
      return null;
    });

    final service = ScreenProtectionService(channel: channel);
    await service.loadAndApply();

    expect(service.loaded, isTrue);
    expect(service.supported, isTrue);
    expect(service.enabled, isFalse);
    expect(applied, [false]);
  });

  test('preference-store failure at boot keeps opt-in protection OFF', () async {
    final applied = <bool>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isSupported') return true;
      if (call.method == 'setEnabled') {
        applied.add((call.arguments as Map)['enabled'] as bool);
        return true;
      }
      return null;
    });

    final service = ScreenProtectionService(
      channel: channel,
      preferences: () async => throw StateError('preference store unavailable'),
    );
    await service.loadAndApply();

    expect(service.loaded, isTrue);
    expect(service.supported, isTrue);
    expect(service.enabled, isFalse);
    expect(applied, [false]);
  });

  test('persisted OFF remains OFF after the Android bridge confirms it', () async {
    SharedPreferences.setMockInitialValues({
      'screen_protection_enabled_v1': false,
    });
    final applied = <bool>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isSupported') return true;
      if (call.method == 'setEnabled') {
        applied.add((call.arguments as Map)['enabled'] as bool);
        return true;
      }
      return null;
    });

    final service = ScreenProtectionService(channel: channel);
    await service.loadAndApply();

    expect(service.enabled, isFalse);
    expect(applied, [false]);
  });

  test('runtime opt-in persists locally after native state succeeds', () async {
    SharedPreferences.setMockInitialValues({});
    final applied = <bool>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isSupported') return true;
      if (call.method == 'setEnabled') {
        applied.add((call.arguments as Map)['enabled'] as bool);
        return true;
      }
      return null;
    });

    final service = ScreenProtectionService(channel: channel);
    await service.loadAndApply();
    await service.setEnabled(true);

    final prefs = await SharedPreferences.getInstance();
    expect(service.enabled, isTrue);
    expect(prefs.getBool('screen_protection_enabled_v1'), isTrue);
    expect(applied, [false, true]);
  });

  test('preference-open failure after native change rolls back previous state', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var preferenceCalls = 0;
    final applied = <bool>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isSupported') return true;
      if (call.method == 'setEnabled') {
        applied.add((call.arguments as Map)['enabled'] as bool);
        return true;
      }
      return null;
    });

    final service = ScreenProtectionService(
      channel: channel,
      preferences: () async {
        preferenceCalls++;
        if (preferenceCalls == 1) return prefs;
        throw StateError('preference store unavailable');
      },
    );
    await service.loadAndApply();

    await expectLater(
      service.setEnabled(true),
      throwsA(isA<StateError>()),
    );

    expect(service.enabled, isFalse);
    expect(service.supported, isTrue);
    expect(applied, [false, true, false]);
  });

  test('failed rollback stops claiming reliable runtime control', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var preferenceCalls = 0;
    var disableCalls = 0;
    final applied = <bool>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isSupported') return true;
      if (call.method == 'setEnabled') {
        final enabled = (call.arguments as Map)['enabled'] as bool;
        applied.add(enabled);
        if (!enabled) {
          disableCalls++;
          if (disableCalls > 1) {
            throw PlatformException(code: 'REVERT_FAILED');
          }
        }
        return true;
      }
      return null;
    });

    final service = ScreenProtectionService(
      channel: channel,
      preferences: () async {
        preferenceCalls++;
        if (preferenceCalls == 1) return prefs;
        throw StateError('preference store unavailable');
      },
    );
    await service.loadAndApply();

    await expectLater(
      service.setEnabled(true),
      throwsA(isA<StateError>()),
    );

    expect(service.enabled, isTrue);
    expect(service.supported, isFalse);
    expect(applied, [false, true, false]);
  });

  test('unsupported platform is reported without claiming native blocking', () async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isSupported') return false;
      return null;
    });

    final service = ScreenProtectionService(channel: channel);
    await service.loadAndApply();

    expect(service.loaded, isTrue);
    expect(service.supported, isFalse);
    expect(service.enabled, isFalse);
    await expectLater(service.setEnabled(true), throwsA(isA<StateError>()));
  });

  test('failed saved ON preference never claims unverified protection', () async {
    SharedPreferences.setMockInitialValues({
      'screen_protection_enabled_v1': true,
    });
    final applied = <bool>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isSupported') return true;
      if (call.method == 'setEnabled') {
        final enabled = (call.arguments as Map)['enabled'] as bool;
        applied.add(enabled);
        if (enabled) {
          throw PlatformException(code: 'APPLY_FAILED');
        }
        return true;
      }
      return null;
    });

    final service = ScreenProtectionService(channel: channel);
    await service.loadAndApply();

    expect(service.supported, isFalse);
    expect(service.enabled, isFalse);
    expect(applied, [true]);
  });
}
