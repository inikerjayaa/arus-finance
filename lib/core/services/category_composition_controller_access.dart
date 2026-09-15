import '../../app_controller.dart';
import 'category_composition_service.dart';

final Expando<CategoryCompositionService> _categoryCompositionServices =
    Expando<CategoryCompositionService>('arus_category_composition_service');

extension CategoryCompositionControllerAccess on AppController {
  CategoryCompositionService? get categoryCompositionService =>
      _categoryCompositionServices[this];

  set categoryCompositionService(CategoryCompositionService? value) {
    _categoryCompositionServices[this] = value;
  }
}
