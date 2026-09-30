import '../../app_controller.dart';
import 'local_ai_preferences_service.dart';

final Expando<LocalAiPreferencesService> _localAiPreferences =
    Expando<LocalAiPreferencesService>('saku_local_ai_preferences');

extension LocalAiPreferencesControllerAccess on AppController {
  LocalAiPreferencesService? get localAiPreferencesService =>
      _localAiPreferences[this];

  set localAiPreferencesService(LocalAiPreferencesService? value) {
    _localAiPreferences[this] = value;
  }
}
