import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kena/accounts/data/group_repository.dart';
import 'package:kena/accounts/domain/group_controller.dart';
import 'package:kena/accounts/domain/models/kena_group.dart';
import 'package:kena/accounts/domain/providers/billing_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('createGroup deja el grupo nuevo como activo', () async {
    final controller = GroupController(userId: 'u1', repository: LocalGroupRepository());
    final group = await controller.createGroup('Familia');

    expect(controller.active?.id, group.id);
    expect(controller.active?.planType, GroupPlanType.free);
    expect(controller.myMembership?.role.name, 'owner');
  });

  test('activatePlan pasa por BillingService y actualiza plan + vencimiento', () async {
    final controller = GroupController(userId: 'u1', repository: LocalGroupRepository());
    await controller.createGroup('Familia');

    final result = await controller.activatePlan(GroupPlanType.personal);

    expect(result.outcome, PurchaseOutcome.success);
    expect(controller.active?.planType, GroupPlanType.personal);
    expect(controller.active?.maxMembers, GroupPlanType.personal.maxMembers);
    expect(controller.active?.expiresAt, isNotNull);
    expect(controller.entitlement?.isActive, isTrue);
  });

  test('inviteMember respeta el límite de miembros del plan activo', () async {
    final controller = GroupController(userId: 'u1', repository: LocalGroupRepository());
    await controller.createGroup('Familia');
    // Plan free: tope bajo (ver GroupPlanType.free.maxMembers) — se llena
    // rápido a propósito para poder probar el límite sin miles de invites.
    final limit = controller.entitlement!.memberLimit;

    for (var i = controller.activeMembers.length; i < limit; i++) {
      await controller.inviteMember('member-$i');
    }
    expect(controller.activeMembers.length, limit);

    expect(
      () => controller.inviteMember('one-too-many'),
      throwsA(isA<StateError>()),
    );
  });

  test('createRoom agrega la sala a activeRooms del grupo activo', () async {
    final controller = GroupController(userId: 'u1', repository: LocalGroupRepository());
    await controller.createGroup('Familia');

    await controller.createRoom('Padres');

    expect(controller.activeRooms.map((r) => r.name), contains('Padres'));
  });

  group('activateFreeTrial (Kena Pass)', () {
    test('activa los límites de Kena Pass marcados como prueba, no como compra', () async {
      final controller = GroupController(userId: 'u1', repository: LocalGroupRepository());
      await controller.createGroup('Familia');

      final result = await controller.activateFreeTrial(trialDays: 7);

      expect(result.outcome, PurchaseOutcome.success);
      expect(controller.active?.planType, GroupPlanType.personal);
      expect(controller.active?.maxMembers, GroupPlanType.personal.maxMembers);
      expect(controller.active?.isTrial, isTrue);
      expect(controller.entitlement?.isActive, isTrue);
      expect(controller.entitlement?.remainingDays, 7);
    });

    test('comprar un plan de verdad después de la prueba saca la marca de prueba', () async {
      final controller = GroupController(userId: 'u1', repository: LocalGroupRepository());
      await controller.createGroup('Familia');
      await controller.activateFreeTrial();

      await controller.activatePlan(GroupPlanType.group);

      expect(controller.active?.isTrial, isFalse);
      expect(controller.active?.planType, GroupPlanType.group);
    });
  });
}
