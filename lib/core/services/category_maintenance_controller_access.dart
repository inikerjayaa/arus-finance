import '../../app_controller.dart';
import 'category_maintenance_service.dart';

final Expando<CategoryMaintenanceService> _categoryMaintenanceServices =
    Expando<CategoryMaintenanceService>('arus_category_maintenance_service');

extension CategoryMaintenanceControllerAccess on AppController {
  CategoryMaintenanceService? get categoryMaintenanceService =>
      _categoryMaintenanceServices[this];

  set categoryMaintenanceService(CategoryMaintenanceService? value) {
    _categoryMaintenanceServices[this] = value;
  }
}
