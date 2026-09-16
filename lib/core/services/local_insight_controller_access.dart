import '../../app_controller.dart';
import 'local_insight_service.dart';

final Expando<LocalInsightService> _localInsightServices =
    Expando<LocalInsightService>('arus_local_insight_service');

extension LocalInsightControllerAccess on AppController {
  LocalInsightService? get localInsightService => _localInsightServices[this];

  set localInsightService(LocalInsightService? value) {
    _localInsightServices[this] = value;
  }
}
