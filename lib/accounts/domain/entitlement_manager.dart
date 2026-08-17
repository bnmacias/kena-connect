import 'models/kena_group.dart';

/// Todo lo que un [KenaGroup] puede/no puede hacer según su plan
/// vigente — la única fuente de verdad de esto en toda la app (ver
/// brief, sección 7: "El networking no consulta Billing. Consulta
/// EntitlementManager."). Nada por fuera de `accounts/` debería mirar
/// `KenaGroup.planType`/`expiresAt` directamente.
///
/// Puro: no lee `SharedPreferences` ni llama a ningún proveedor — toma
/// el estado ya cargado del grupo y responde preguntas sobre él. Quien
/// necesite el [KenaGroup] actualizado es responsabilidad de
/// `GroupController`/`GroupRepository`, no de esta clase.
class EntitlementManager {
  const EntitlementManager(this.group);

  final KenaGroup group;

  /// El plan `free` nunca vence (siempre "activo", con los límites del
  /// free). Un plan pago está activo si todavía no llegó `expiresAt`.
  bool get isActive {
    if (group.status != GroupStatus.active) return false;
    if (group.planType == GroupPlanType.free) return true;
    final expiresAt = group.expiresAt;
    if (expiresAt == null) return false;
    return expiresAt.isAfter(DateTime.now());
  }

  bool get isExpired => !isActive;

  /// `0` si ya venció o es el plan free (no aplica "días restantes").
  int get remainingDays {
    if (group.planType == GroupPlanType.free) return 0;
    final expiresAt = group.expiresAt;
    if (expiresAt == null) return 0;
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? 0 : diff.inDays + (diff.inHours % 24 > 0 ? 1 : 0);
  }

  int get memberLimit => group.maxMembers;

  /// Cualquier usuario con sesión iniciada puede crear un grupo nuevo
  /// (el free no tiene tope de grupos por usuario, sólo de miembros por
  /// grupo) — método de instancia por consistencia con el resto de la
  /// clase, aunque hoy no dependa del [group] recibido.
  bool canCreateGroup() => true;

  /// Hace falta un plan vigente y no haber llegado al tope de
  /// miembros — un grupo vencido no puede sumar gente nueva hasta
  /// renovar, aunque los miembros actuales sigan pudiendo chatear.
  bool canInviteMember(int currentMemberCount) => isActive && currentMemberCount < memberLimit;
}
