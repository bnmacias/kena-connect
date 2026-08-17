import 'package:flutter_test/flutter_test.dart';
import 'package:kena/accounts/domain/models/membership.dart';

void main() {
  group('permisos por rol (brief, sección 4)', () {
    test('OWNER puede administrar, expulsar, invitar y crear salas', () {
      const m = Membership(userId: 'u1', groupId: 'g1', role: MembershipRole.owner);
      expect(m.canManageGroup, isTrue);
      expect(m.canRemoveMembers, isTrue);
      expect(m.canInvite, isTrue);
      expect(m.canCreateRoom, isTrue);
    });

    test('ADMIN puede invitar y crear salas, pero no administrar ni expulsar', () {
      const m = Membership(userId: 'u1', groupId: 'g1', role: MembershipRole.admin);
      expect(m.canManageGroup, isFalse);
      expect(m.canRemoveMembers, isFalse);
      expect(m.canInvite, isTrue);
      expect(m.canCreateRoom, isTrue);
    });

    test('MEMBER puede crear salas y participar, pero no invitar/administrar/expulsar', () {
      const m = Membership(userId: 'u1', groupId: 'g1', role: MembershipRole.member);
      expect(m.canManageGroup, isFalse);
      expect(m.canRemoveMembers, isFalse);
      expect(m.canInvite, isFalse);
      expect(m.canCreateRoom, isTrue, reason: 'brief, sección 5: "Todos los miembros pueden crear salas"');
    });
  });

  test('serializa y restaura sin perder el rol', () {
    const m = Membership(userId: 'u1', groupId: 'g1', role: MembershipRole.admin);
    final restored = Membership.fromJson(m.toJson());
    expect(restored.userId, m.userId);
    expect(restored.groupId, m.groupId);
    expect(restored.role, MembershipRole.admin);
  });
}
