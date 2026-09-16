import '../../app_controller.dart';
import 'user_profile_service.dart';

final Expando<UserProfileService> _userProfiles =
    Expando<UserProfileService>('arus_user_profile_service');

extension UserProfileControllerAccess on AppController {
  UserProfileService? get userProfileService => _userProfiles[this];

  set userProfileService(UserProfileService? value) {
    _userProfiles[this] = value;
  }
}
