import '../../app_controller.dart';
import 'visual_identity_store.dart';

final Expando<VisualIdentityStore> _visualIdentityStores =
    Expando<VisualIdentityStore>('arus_visual_identity_store');

extension VisualIdentityControllerAccess on AppController {
  VisualIdentityStore? get visualIdentityStore => _visualIdentityStores[this];

  set visualIdentityStore(VisualIdentityStore? value) {
    _visualIdentityStores[this] = value;
  }
}
