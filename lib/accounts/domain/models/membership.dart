/// Rol de un [Membership] dentro de un grupo. Ver `Membership.can*` para
/// los permisos concretos que habilita cada uno — la fuente de verdad
/// de "quién puede qué" vive ahí, no repartida por la UI.
enum MembershipRole { owner, admin, member }

/// La relación User↔Group — un usuario puede pertenecer a muchos
/// grupos, cada pertenencia con su propio rol (el mismo usuario puede
/// ser OWNER de un grupo y MEMBER de otro).
class Membership {
  final String userId;
  final String groupId;
  final MembershipRole role;

  const Membership({required this.userId, required this.groupId, required this.role});

  /// Administrar el grupo (renombrarlo, cambiar plan, cancelarlo).
  bool get canManageGroup => role == MembershipRole.owner;

  /// Expulsar a otro miembro.
  bool get canRemoveMembers => role == MembershipRole.owner;

  /// Invitar gente nueva — OWNER y ADMIN, no MEMBER (ver brief, sección 4).
  bool get canInvite => role == MembershipRole.owner || role == MembershipRole.admin;

  /// Crear salas dentro del grupo — todos los roles pueden (ver brief,
  /// sección 5: "Cualquier miembro puede hacerlo").
  bool get canCreateRoom => true;

  Membership copyWith({MembershipRole? role}) => Membership(userId: userId, groupId: groupId, role: role ?? this.role);

  Map<String, dynamic> toJson() => {'userId': userId, 'groupId': groupId, 'role': role.name};

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
        userId: json['userId'] as String,
        groupId: json['groupId'] as String,
        role: MembershipRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => MembershipRole.member,
        ),
      );
}
