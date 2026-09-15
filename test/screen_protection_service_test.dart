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

  test('screen protection defaults ON and applies secure native state', () async {
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
    expect(service.enabled, isTrue);
    expect(applied, [true]);
  });

  test('persisted OFF is applied only after the Android bridge confirms it', () async {
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

  test('runtime toggle persists locally after native state succeeds', () async {
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
    await service.setEnabled(false);

    final prefs = await SharedPreferences.getInstance();
    expect(service.enabled, isFalse);
    expect(prefs.getBool('screen_protection_enabled_v1'), isFalse);
    expect(applied, [true, false]);
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
    await expectLater(service.setEnabled(false), throwsA(isA<StateError>()));
  });

  test('failed saved OFF preference falls back to truthful secure ON state', () async {
    SharedPreferences.setMockInitialValues({
      'screen_protection_enabled_v1': false,
    });
    final applied = <bool>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isSupported') return true;
      if (call.method == 'setEnabled') {
        final enabled = (call.arguments as Map)['enabled'] as bool;
        applied.add(enabled);
        if (!enabled) {
          throw PlatformException(code: 'APPLY_FAILED');
        }
        return true;
      }
      return null;
    });

    final service = ScreenProtectionService(channel: channel);
    await service.loadAndApply();

    expect(service.supported, isTrue);
    expect(service.enabled, isTrue);
    expect(applied, [false, true]);
  });
}
