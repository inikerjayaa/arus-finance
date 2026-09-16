import 'package:arus_finance/core/services/user_profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('profile name is normalized and persisted locally', () async {
    final service = UserProfileService();
    await service.load();
    expect(service.name, isNull);

    await service.saveName('  Ema   Putri  ');
    expect(service.name, 'Ema Putri');

    final second = UserProfileService();
    await second.load();
    expect(second.name, 'Ema Putri');
  });

  test('profile notifies listeners after a successful rename', () async {
    final service = UserProfileService();
    var notifications = 0;
    service.addListener(() => notifications++);

    await service.saveName('Ema');
    expect(service.name, 'Ema');
    expect(notifications, 1);
  });

  test('profile rejects empty and overlong names', () async {
    final service = UserProfileService();
    await expectLater(service.saveName('   '), throwsArgumentError);
    await expectLater(service.saveName('x' * 41), throwsArgumentError);
  });
}
