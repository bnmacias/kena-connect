/// Plan de un [KenaGroup] — el entitlement (ver `entitlement_manager.dart`)
/// se calcula siempre a partir de esto, nunca al revés. `free` es el
/// default de cualquier grupo nuevo antes de activar un plan pago.
enum GroupPlanType { free, personal, group }

extension GroupPlanTypeInfo on GroupPlanType {
  /// Nombre de venta ("Kena Pass"/"Kena Group Pass" — ver
  /// `KenaPassPlansScreen`), no el nombre técnico del plan.
  String get label => switch (this) {
        GroupPlanType.free => 'Free',
        GroupPlanType.personal => 'Kena Pass',
        GroupPlanType.group => 'Kena Group Pass',
      };

  /// Precio de referencia en USD — sólo para mostrar en la UI de
  /// planes (`KenaPassPlansScreen`/`ActivatePlanScreen`); el cobro real
  /// lo resuelve `BillingService` contra el store correspondiente, que
  /// es quien define el precio final (impuestos/moneda local incluidos).
  double get referencePriceUsd => switch (this) {
        GroupPlanType.free => 0,
        GroupPlanType.personal => 0.99,
        GroupPlanType.group => 4.99,
      };

  int get maxMembers => switch (this) {
        GroupPlanType.free => 3,
        GroupPlanType.personal => 10,
        GroupPlanType.group => 50,
      };

  /// Ninguno de los planes pagos dura más de 30 días por ciclo — se
  /// renueva comprando de nuevo (no hay auto-renovación implementada
  /// todavía, ver `BillingService`).
  int get durationDays => switch (this) {
        GroupPlanType.free => 0,
        GroupPlanType.personal => 30,
        GroupPlanType.group => 30,
      };
}

/// Estado de un [KenaGroup] — separado de si el plan está vigente
/// (`EntitlementManager.isActive`, que mira `expiresAt`): un grupo
/// puede estar `active` con un plan vencido (sigue existiendo, sólo que
/// no puede invitar/crear más hasta renovar), o `cancelled` a mano por
/// el owner.
enum GroupStatus { active, expired, cancelled }

/// El grupo es el dueño del entitlement — nunca una sala, nunca el
/// dispositivo anfitrión (ver el modelo de dominio en el brief). Todas
/// las salas que crea cualquier miembro del grupo comparten el mismo
/// plan.
class KenaGroup {
  final String id;
  final String name;
  final String ownerId;
  final GroupPlanType planType;
  final int maxMembers;

  /// `null` en el plan `free` (no vence, pero tampoco desbloquea nada
  /// que el free no tenga ya).
  final DateTime? expiresAt;

  final DateTime createdAt;
  final GroupStatus status;

  /// `true` mientras el plan pago vigente ([planType]/[expiresAt]) viene
  /// de "Activar prueba gratuita" (ver `KenaPassPlansScreen`) en vez de
  /// una compra real — sólo cambia el rótulo que ve el usuario
  /// ("Prueba gratuita" en vez de "Kena Pass"), nunca los límites: una
  /// prueba activa el mismo [GroupPlanType.personal] de siempre, sólo
  /// que sin cobrar (ver `GroupController.activateFreeTrial`).
  final bool isTrial;

  const KenaGroup({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.planType,
    required this.maxMembers,
    required this.createdAt,
    required this.status,
    this.expiresAt,
    this.isTrial = false,
  });

  factory KenaGroup.newFree({required String id, required String name, required String ownerId}) => KenaGroup(
        id: id,
        name: name,
        ownerId: ownerId,
        planType: GroupPlanType.free,
        maxMembers: GroupPlanType.free.maxMembers,
        createdAt: DateTime.now(),
        status: GroupStatus.active,
      );

  KenaGroup copyWith({
    String? name,
    GroupPlanType? planType,
    int? maxMembers,
    DateTime? expiresAt,
    GroupStatus? status,
    bool? isTrial,
  }) =>
      KenaGroup(
        id: id,
        name: name ?? this.name,
        ownerId: ownerId,
        planType: planType ?? this.planType,
        maxMembers: maxMembers ?? this.maxMembers,
        expiresAt: expiresAt ?? this.expiresAt,
        createdAt: createdAt,
        status: status ?? this.status,
        isTrial: isTrial ?? this.isTrial,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ownerId': ownerId,
        'planType': planType.name,
        'maxMembers': maxMembers,
        'expiresAt': expiresAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'isTrial': isTrial,
      };

  factory KenaGroup.fromJson(Map<String, dynamic> json) => KenaGroup(
        id: json['id'] as String,
        name: json['name'] as String,
        ownerId: json['ownerId'] as String,
        planType: GroupPlanType.values.firstWhere(
          (p) => p.name == json['planType'],
          orElse: () => GroupPlanType.free,
        ),
        maxMembers: json['maxMembers'] as int? ?? GroupPlanType.free.maxMembers,
        expiresAt: json['expiresAt'] == null ? null : DateTime.tryParse(json['expiresAt'] as String),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        status: GroupStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => GroupStatus.active,
        ),
        isTrial: json['isTrial'] as bool? ?? false,
      );
}
