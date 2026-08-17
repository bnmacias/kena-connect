import 'package:flutter_test/flutter_test.dart';
import 'package:kena/accounts/domain/models/app_user.dart';
import 'package:kena/accounts/domain/models/auth_provider_type.dart';
import 'package:kena/accounts/domain/models/group_room.dart';
import 'package:kena/accounts/domain/models/kena_group.dart';

void main() {
  test('AppUser sobrevive un toJson/fromJson sin perder datos', () {
    final user = AppUser(
      id: 'u1',
      firstName: 'Sol',
      lastName: 'Pérez',
      email: 'sol@example.com',
      avatarUrl: 'https://example.com/a.png',
      authProvider: AuthProviderType.google,
      createdAt: DateTime(2026, 3, 1, 10, 30),
    );

    final restored = AppUser.fromJson(user.toJson());

    expect(restored.id, user.id);
    expect(restored.fullName, 'Sol Pérez');
    expect(restored.email, user.email);
    expect(restored.authProvider, AuthProviderType.google);
    expect(restored.createdAt, user.createdAt);
  });

  test('KenaGroup sobrevive un toJson/fromJson, incluyendo expiresAt nulo', () {
    final group = KenaGroup.newFree(id: 'g1', name: 'Familia', ownerId: 'u1');
    final restored = KenaGroup.fromJson(group.toJson());

    expect(restored.id, group.id);
    expect(restored.planType, GroupPlanType.free);
    expect(restored.expiresAt, isNull);
    expect(restored.status, GroupStatus.active);
  });

  test('KenaGroup con plan pago conserva expiresAt', () {
    final expires = DateTime.now().add(const Duration(days: 30));
    final group = KenaGroup(
      id: 'g1',
      name: 'Familia',
      ownerId: 'u1',
      planType: GroupPlanType.personal,
      maxMembers: GroupPlanType.personal.maxMembers,
      expiresAt: expires,
      createdAt: DateTime.now(),
      status: GroupStatus.active,
    );

    final restored = KenaGroup.fromJson(group.toJson());
    expect(restored.expiresAt, expires);
  });

  test('KenaGroup conserva isTrial (default false, y true si viene de una prueba)', () {
    final free = KenaGroup.newFree(id: 'g1', name: 'Familia', ownerId: 'u1');
    expect(KenaGroup.fromJson(free.toJson()).isTrial, isFalse);

    final trial = free.copyWith(planType: GroupPlanType.personal, isTrial: true);
    expect(KenaGroup.fromJson(trial.toJson()).isTrial, isTrue);
  });

  test('GroupRoom sobrevive un toJson/fromJson', () {
    final room = GroupRoom(id: 'r1', groupId: 'g1', name: 'Padres', createdByUserId: 'u1', createdAt: DateTime.now());
    final restored = GroupRoom.fromJson(room.toJson());

    expect(restored.id, room.id);
    expect(restored.groupId, room.groupId);
    expect(restored.name, 'Padres');
  });
}
