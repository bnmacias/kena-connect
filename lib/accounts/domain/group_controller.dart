import 'package:flutter/foundation.dart';

import '../accounts_environment.dart';
import '../data/group_repository.dart';
import 'entitlement_manager.dart';
import 'models/group_room.dart';
import 'models/kena_group.dart';
import 'models/membership.dart';
import 'providers/billing_service.dart';

/// Estado de "grupos" del usuario con sesión iniciada: la lista de
/// grupos a los que pertenece, cuál está activo ahora mismo (el que
/// muestra `GroupHomeScreen`), y las operaciones sobre él. Un
/// `ChangeNotifier` (no `ValueNotifier`, porque expone varias piezas de
/// estado a la vez) — se instancia por sesión, no es un singleton
/// global como `AuthController`/`KenaThemeController` (se crea recién
/// cuando hay un usuario con sesión iniciada, ver `AccountsEntryScreen`).
class GroupController extends ChangeNotifier {
  GroupController({required this.userId, GroupRepository? repository})
      : _repo = repository ?? AccountsEnvironment.groupRepository;

  final String userId;
  final GroupRepository _repo;

  List<KenaGroup> _groups = const [];
  KenaGroup? _active;
  List<Membership> _activeMembers = const [];
  List<GroupRoom> _activeRooms = const [];
  bool _loading = false;

  List<KenaGroup> get groups => _groups;
  KenaGroup? get active => _active;
  List<Membership> get activeMembers => _activeMembers;
  List<GroupRoom> get activeRooms => _activeRooms;
  bool get loading => _loading;

  EntitlementManager? get entitlement => _active == null ? null : EntitlementManager(_active!);

  Membership? get myMembership {
    final group = _active;
    if (group == null) return null;
    try {
      return _activeMembers.firstWhere((m) => m.userId == userId);
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _groups = await _repo.groupsFor(userId);
    if (_groups.isNotEmpty) {
      await selectGroup(_groups.first.id);
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> selectGroup(String groupId) async {
    final group = await _repo.byId(groupId);
    if (group == null) return;
    _active = group;
    _activeMembers = await _repo.membersOf(groupId);
    _activeRooms = await _repo.roomsOf(groupId);
    notifyListeners();
  }

  Future<KenaGroup> createGroup(String name) async {
    final group = await _repo.createGroup(name: name, ownerId: userId);
    _groups = [..._groups, group];
    await selectGroup(group.id);
    return group;
  }

  /// Activa un plan sobre el grupo activo — pasa por [BillingService]
  /// (mockeado hoy, ver `AccountsEnvironment`), nunca escribe
  /// `expiresAt`/`planType` directamente sin pasar por una compra
  /// "exitosa" (aunque sea simulada).
  Future<PurchaseResult> activatePlan(GroupPlanType planType) async {
    final group = _active;
    if (group == null) throw StateError('No hay grupo activo.');
    final result = await AccountsEnvironment.billingService.purchase(planType);
    if (result.outcome != PurchaseOutcome.success) return result;

    final updated = group.copyWith(
      planType: planType,
      maxMembers: planType.maxMembers,
      expiresAt: planType == GroupPlanType.free ? null : DateTime.now().add(Duration(days: planType.durationDays)),
      status: GroupStatus.active,
      isTrial: false,
    );
    await _repo.updateGroup(updated);
    _active = updated;
    _groups = [
      for (final g in _groups) g.id == updated.id ? updated : g,
    ];
    notifyListeners();
    return result;
  }

  /// "Activar prueba gratuita" (ver `KenaPassPlansScreen`) — desbloquea
  /// los límites de [GroupPlanType.personal] ("Kena Pass") por
  /// [trialDays] sin cobrar nada todavía (igual pasa por
  /// [BillingService], simulado hoy, para que el día que haya un
  /// backend real sea el mismo punto el que decida si ya se usó la
  /// prueba antes).
  Future<PurchaseResult> activateFreeTrial({int trialDays = 7}) async {
    final group = _active;
    if (group == null) throw StateError('No hay grupo activo.');
    final result = await AccountsEnvironment.billingService.purchase(GroupPlanType.personal);
    if (result.outcome != PurchaseOutcome.success) return result;

    final updated = group.copyWith(
      planType: GroupPlanType.personal,
      maxMembers: GroupPlanType.personal.maxMembers,
      expiresAt: DateTime.now().add(Duration(days: trialDays)),
      status: GroupStatus.active,
      isTrial: true,
    );
    await _repo.updateGroup(updated);
    _active = updated;
    _groups = [
      for (final g in _groups) g.id == updated.id ? updated : g,
    ];
    notifyListeners();
    return result;
  }

  Future<void> inviteMember(String invitedUserId, {MembershipRole role = MembershipRole.member}) async {
    final group = _active;
    if (group == null) throw StateError('No hay grupo activo.');
    final entitlement = EntitlementManager(group);
    if (!entitlement.canInviteMember(_activeMembers.length)) {
      throw StateError(
        entitlement.isExpired
            ? 'El plan de "${group.name}" venció — renovalo antes de invitar gente nueva.'
            : 'Llegaste al límite de ${entitlement.memberLimit} miembros de "${group.name}".',
      );
    }
    final membership = await _repo.addMember(group.id, invitedUserId, role: role);
    _activeMembers = [..._activeMembers, membership];
    notifyListeners();
  }

  Future<void> removeMember(String memberId) async {
    final group = _active;
    if (group == null) return;
    await _repo.removeMember(group.id, memberId);
    _activeMembers = _activeMembers.where((m) => m.userId != memberId).toList();
    notifyListeners();
  }

  Future<void> changeMemberRole(String memberId, MembershipRole role) async {
    final group = _active;
    if (group == null) return;
    await _repo.updateMemberRole(group.id, memberId, role);
    _activeMembers = [
      for (final m in _activeMembers) m.userId == memberId ? m.copyWith(role: role) : m,
    ];
    notifyListeners();
  }

  /// Registra una sala nueva dentro del grupo activo — sólo la
  /// metadata organizativa (ver `GroupRoom`), no abre ninguna conexión
  /// de red por sí sola. Cualquier miembro puede hacerlo (ver brief,
  /// sección 5) — no valida rol a propósito.
  Future<GroupRoom> createRoom(String name) async {
    final group = _active;
    if (group == null) throw StateError('No hay grupo activo.');
    final room = await _repo.createRoom(group.id, name: name, createdByUserId: userId);
    _activeRooms = [..._activeRooms, room];
    notifyListeners();
    return room;
  }
}
