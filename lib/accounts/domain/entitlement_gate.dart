import 'auth_controller.dart';
import 'group_controller.dart';
import 'models/kena_group.dart';

/// `true` si este dispositivo ya tiene una cuenta con un grupo con plan
/// pago (o prueba gratuita) vigente — es lo que decide si "Crear una
/// sala" en Inicio (`HomeScreen`) puede ir directo a `CreateRoomScreen`
/// o si primero hay que mostrar el instructivo + Kena Pass (ver
/// `RoomWalkthroughScreen`/`KenaPassPlansScreen`). El plan `free` no
/// cuenta — sólo "ya pagó (o está en prueba)" salta el paywall.
Future<bool> hasActiveGroupEntitlement() async {
  await AuthController.instance.load();
  final user = AuthController.instance.value;
  if (user == null) return false;

  final groupController = GroupController(userId: user.id);
  await groupController.load();
  final entitlement = groupController.entitlement;
  final group = groupController.active;
  if (entitlement == null || group == null) return false;
  return entitlement.isActive && group.planType != GroupPlanType.free;
}
