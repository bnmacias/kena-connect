import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kena/accounts/data/group_repository.dart';
import 'package:kena/accounts/domain/models/membership.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('crear un grupo suma automáticamente a su creador como OWNER', () async {
    final repo = LocalGroupRepository();
    final group = await repo.createGroup(name: 'Familia', ownerId: 'u1');

    expect(group.name, 'Familia');
    expect(group.ownerId, 'u1');
    final members = await repo.membersOf(group.id);
    expect(members, hasLength(1));
    expect(members.single.role, MembershipRole.owner);

    final groupsForOwner = await repo.groupsFor('u1');
    expect(groupsForOwner.map((g) => g.id), contains(group.id));
  });

  test('un usuario que no pertenece al grupo no lo ve en groupsFor', () async {
    final repo = LocalGroupRepository();
    await repo.createGroup(name: 'Familia', ownerId: 'u1');

    final groupsForStranger = await repo.groupsFor('u2');
    expect(groupsForStranger, isEmpty);
  });

  test('addMember/removeMember actualizan la lista de miembros del grupo', () async {
    final repo = LocalGroupRepository();
    final group = await repo.createGroup(name: 'Familia', ownerId: 'u1');

    await repo.addMember(group.id, 'u2', role: MembershipRole.member);
    expect(await repo.membersOf(group.id), hasLength(2));

    await repo.removeMember(group.id, 'u2');
    final remaining = await repo.membersOf(group.id);
    expect(remaining, hasLength(1));
    expect(remaining.single.userId, 'u1');
  });

  test('updateGroup persiste los cambios (p.ej. tras activar un plan)', () async {
    final repo = LocalGroupRepository();
    final group = await repo.createGroup(name: 'Familia', ownerId: 'u1');

    await repo.updateGroup(group.copyWith(name: 'Familia Macías'));

    final reloaded = await repo.byId(group.id);
    expect(reloaded?.name, 'Familia Macías');
  });

  test('createRoom guarda la sala bajo el grupo correcto', () async {
    final repo = LocalGroupRepository();
    final group = await repo.createGroup(name: 'Familia', ownerId: 'u1');

    await repo.createRoom(group.id, name: 'Padres', createdByUserId: 'u1');
    final rooms = await repo.roomsOf(group.id);

    expect(rooms, hasLength(1));
    expect(rooms.single.name, 'Padres');
  });
}
