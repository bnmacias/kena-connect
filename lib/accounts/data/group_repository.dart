import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/group_room.dart';
import '../domain/models/kena_group.dart';
import '../domain/models/membership.dart';

/// Persistencia de grupos/membresías/salas-del-grupo — igual que
/// `UserRepository`, desacoplada de dónde viven de verdad. Hoy todo es
/// local a este dispositivo (no hay forma de que otro dispositivo vea
/// "los mismos" grupos sin un backend real detrás sincronizando esto —
/// ver el brief, sección 11: "no romper compatibilidad" se refiere
/// puntualmente a esto, no a que ya sea multi-dispositivo).
abstract class GroupRepository {
  Future<List<KenaGroup>> groupsFor(String userId);
  Future<KenaGroup?> byId(String groupId);
  Future<KenaGroup> createGroup({required String name, required String ownerId});
  Future<void> updateGroup(KenaGroup group);

  Future<List<Membership>> membersOf(String groupId);
  Future<Membership> addMember(String groupId, String userId, {MembershipRole role = MembershipRole.member});
  Future<void> removeMember(String groupId, String userId);
  Future<void> updateMemberRole(String groupId, String userId, MembershipRole role);

  Future<List<GroupRoom>> roomsOf(String groupId);
  Future<GroupRoom> createRoom(String groupId, {required String name, required String createdByUserId});
}

class LocalGroupRepository implements GroupRepository {
  static const _groupsKey = 'kena.accounts.groups';
  static const _membershipsKey = 'kena.accounts.memberships';
  static const _roomsKey = 'kena.accounts.groupRooms';

  Future<List<KenaGroup>> _readGroups(SharedPreferences prefs) => _readList(prefs, _groupsKey, KenaGroup.fromJson);
  Future<List<Membership>> _readMemberships(SharedPreferences prefs) =>
      _readList(prefs, _membershipsKey, Membership.fromJson);
  Future<List<GroupRoom>> _readRooms(SharedPreferences prefs) => _readList(prefs, _roomsKey, GroupRoom.fromJson);

  Future<List<T>> _readList<T>(
    SharedPreferences prefs,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final raw = prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeGroups(SharedPreferences prefs, List<KenaGroup> groups) =>
      prefs.setString(_groupsKey, jsonEncode(groups.map((g) => g.toJson()).toList()));
  Future<void> _writeMemberships(SharedPreferences prefs, List<Membership> memberships) =>
      prefs.setString(_membershipsKey, jsonEncode(memberships.map((m) => m.toJson()).toList()));
  Future<void> _writeRooms(SharedPreferences prefs, List<GroupRoom> rooms) =>
      prefs.setString(_roomsKey, jsonEncode(rooms.map((r) => r.toJson()).toList()));

  String _generateId(String prefix) => '$prefix-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 31)}';

  @override
  Future<List<KenaGroup>> groupsFor(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final memberships = await _readMemberships(prefs);
    final groupIds = memberships.where((m) => m.userId == userId).map((m) => m.groupId).toSet();
    final groups = await _readGroups(prefs);
    return groups.where((g) => groupIds.contains(g.id)).toList();
  }

  @override
  Future<KenaGroup?> byId(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final groups = await _readGroups(prefs);
    try {
      return groups.firstWhere((g) => g.id == groupId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<KenaGroup> createGroup({required String name, required String ownerId}) async {
    final prefs = await SharedPreferences.getInstance();
    final groups = await _readGroups(prefs);
    final group = KenaGroup.newFree(id: _generateId('group'), name: name, ownerId: ownerId);
    groups.add(group);
    await _writeGroups(prefs, groups);

    final memberships = await _readMemberships(prefs);
    memberships.add(Membership(userId: ownerId, groupId: group.id, role: MembershipRole.owner));
    await _writeMemberships(prefs, memberships);

    return group;
  }

  @override
  Future<void> updateGroup(KenaGroup group) async {
    final prefs = await SharedPreferences.getInstance();
    final groups = await _readGroups(prefs);
    final idx = groups.indexWhere((g) => g.id == group.id);
    if (idx == -1) return;
    groups[idx] = group;
    await _writeGroups(prefs, groups);
  }

  @override
  Future<List<Membership>> membersOf(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final memberships = await _readMemberships(prefs);
    return memberships.where((m) => m.groupId == groupId).toList();
  }

  @override
  Future<Membership> addMember(String groupId, String userId, {MembershipRole role = MembershipRole.member}) async {
    final prefs = await SharedPreferences.getInstance();
    final memberships = await _readMemberships(prefs);
    memberships.removeWhere((m) => m.groupId == groupId && m.userId == userId);
    final membership = Membership(userId: userId, groupId: groupId, role: role);
    memberships.add(membership);
    await _writeMemberships(prefs, memberships);
    return membership;
  }

  @override
  Future<void> removeMember(String groupId, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final memberships = await _readMemberships(prefs);
    memberships.removeWhere((m) => m.groupId == groupId && m.userId == userId);
    await _writeMemberships(prefs, memberships);
  }

  @override
  Future<void> updateMemberRole(String groupId, String userId, MembershipRole role) async {
    final prefs = await SharedPreferences.getInstance();
    final memberships = await _readMemberships(prefs);
    final idx = memberships.indexWhere((m) => m.groupId == groupId && m.userId == userId);
    if (idx == -1) return;
    memberships[idx] = memberships[idx].copyWith(role: role);
    await _writeMemberships(prefs, memberships);
  }

  @override
  Future<List<GroupRoom>> roomsOf(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final rooms = await _readRooms(prefs);
    return rooms.where((r) => r.groupId == groupId).toList();
  }

  @override
  Future<GroupRoom> createRoom(String groupId, {required String name, required String createdByUserId}) async {
    final prefs = await SharedPreferences.getInstance();
    final rooms = await _readRooms(prefs);
    final room = GroupRoom(
      id: _generateId('room'),
      groupId: groupId,
      name: name,
      createdByUserId: createdByUserId,
      createdAt: DateTime.now(),
    );
    rooms.add(room);
    await _writeRooms(prefs, rooms);
    return room;
  }
}
