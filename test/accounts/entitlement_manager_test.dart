import 'package:flutter_test/flutter_test.dart';
import 'package:kena/accounts/domain/entitlement_manager.dart';
import 'package:kena/accounts/domain/models/kena_group.dart';

KenaGroup _group({
  GroupPlanType planType = GroupPlanType.free,
  DateTime? expiresAt,
  GroupStatus status = GroupStatus.active,
  int? maxMembers,
}) =>
    KenaGroup(
      id: 'g1',
      name: 'Familia',
      ownerId: 'u1',
      planType: planType,
      maxMembers: maxMembers ?? planType.maxMembers,
      expiresAt: expiresAt,
      createdAt: DateTime(2026, 1, 1),
      status: status,
    );

void main() {
  group('EntitlementManager.isActive', () {
    test('el plan free siempre está activo, sin importar expiresAt', () {
      final entitlement = EntitlementManager(_group());
      expect(entitlement.isActive, isTrue);
      expect(entitlement.isExpired, isFalse);
    });

    test('un plan pago con expiresAt futuro está activo', () {
      final entitlement = EntitlementManager(
        _group(planType: GroupPlanType.personal, expiresAt: DateTime.now().add(const Duration(days: 5))),
      );
      expect(entitlement.isActive, isTrue);
    });

    test('un plan pago con expiresAt pasado no está activo', () {
      final entitlement = EntitlementManager(
        _group(planType: GroupPlanType.personal, expiresAt: DateTime.now().subtract(const Duration(days: 1))),
      );
      expect(entitlement.isActive, isFalse);
      expect(entitlement.isExpired, isTrue);
    });

    test('un plan pago sin expiresAt (dato inconsistente) no se considera activo', () {
      final entitlement = EntitlementManager(_group(planType: GroupPlanType.group));
      expect(entitlement.isActive, isFalse);
    });

    test('un grupo cancelado no está activo aunque el plan no haya vencido', () {
      final entitlement = EntitlementManager(
        _group(
          planType: GroupPlanType.personal,
          expiresAt: DateTime.now().add(const Duration(days: 10)),
          status: GroupStatus.cancelled,
        ),
      );
      expect(entitlement.isActive, isFalse);
    });
  });

  group('EntitlementManager.remainingDays', () {
    test('0 para el plan free', () {
      expect(EntitlementManager(_group()).remainingDays, 0);
    });

    test('redondea hacia arriba las horas parciales', () {
      final entitlement = EntitlementManager(
        _group(planType: GroupPlanType.personal, expiresAt: DateTime.now().add(const Duration(days: 2, hours: 3))),
      );
      expect(entitlement.remainingDays, 3);
    });

    test('0 si ya venció', () {
      final entitlement = EntitlementManager(
        _group(planType: GroupPlanType.personal, expiresAt: DateTime.now().subtract(const Duration(days: 1))),
      );
      expect(entitlement.remainingDays, 0);
    });
  });

  group('EntitlementManager.canInviteMember', () {
    test('puede invitar mientras haya lugar y el plan esté activo', () {
      final entitlement = EntitlementManager(_group(maxMembers: 3));
      expect(entitlement.canInviteMember(2), isTrue);
    });

    test('no puede invitar si ya llegó al límite de miembros', () {
      final entitlement = EntitlementManager(_group(maxMembers: 3));
      expect(entitlement.canInviteMember(3), isFalse);
    });

    test('no puede invitar si el plan venció, aunque haya lugar', () {
      final entitlement = EntitlementManager(
        _group(planType: GroupPlanType.personal, expiresAt: DateTime.now().subtract(const Duration(days: 1))),
      );
      expect(entitlement.canInviteMember(1), isFalse);
    });
  });
}
