import 'package:flutter/material.dart';

import '../../accounts/domain/group_controller.dart';
import '../../accounts/domain/models/membership.dart';
import '../../theme/kena_colors.dart';
import '../../theme/kena_spacing.dart';
import '../../theme/kena_typography.dart';
import '../../widgets/avatar.dart';
import '../../widgets/kena_confirm_sheet.dart';
import '../../widgets/kena_field.dart';

/// Miembros del grupo activo — invitar, ver rol, expulsar (ver brief,
/// sección 4: sólo OWNER puede expulsar; OWNER/ADMIN pueden invitar).
///
/// **Sobre "invitar":** sin un backend real no hay forma de resolver un
/// código de invitación desde OTRO dispositivo — acá se simula sumando
/// directo a un `userId` de prueba a la membresía local (ver
/// `GroupRepository`). Un invite de verdad (link/código que otro
/// dispositivo canjea) necesita ese backend, documentado en el brief
/// como pendiente.
class GroupMembersScreen extends StatefulWidget {
  const GroupMembersScreen({super.key, required this.groupController});

  final GroupController groupController;

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  final _inviteController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    final name = _inviteController.text.trim();
    if (name.isEmpty) return;
    setState(() => _error = null);
    try {
      await widget.groupController.inviteMember('demo-${DateTime.now().microsecondsSinceEpoch}-$name');
      _inviteController.clear();
      if (mounted) setState(() {});
    } catch (e) {
      setState(() => _error = e is StateError ? e.message : 'No se pudo invitar.');
    }
  }

  Future<void> _confirmRemove(String memberId, String label) async {
    final confirmed = await KenaConfirmSheet.show(
      context,
      title: '¿Sacar a $label del grupo?',
      body: 'Va a dejar de ver las salas y mensajes de este grupo.',
      confirmLabel: 'Sacar del grupo',
      tone: KenaConfirmTone.danger,
    );
    if (confirmed == true) {
      await widget.groupController.removeMember(memberId);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.groupController;
    final myMembership = controller.myMembership;
    final canInvite = myMembership?.canInvite ?? false;
    final canRemove = myMembership?.canRemoveMembers ?? false;

    return KenaBackground(
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Miembros')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              if (canInvite) ...[
                KenaField(
                  label: 'Invitar a alguien',
                  controller: _inviteController,
                  hint: 'Nombre de la persona (demo)',
                  onSubmitted: (_) => _invite(),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.person_add_alt_1_rounded, color: KenaColors.accent),
                    onPressed: _invite,
                  ),
                ),
                if (_error != null) Text(_error!, style: KenaTypography.bodySmall.copyWith(color: KenaColors.red)),
                const SizedBox(height: KenaSpacing.sm),
              ],
              for (final m in controller.activeMembers)
                Padding(
                  padding: const EdgeInsets.only(bottom: KenaSpacing.sm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: KenaColors.card,
                      borderRadius: BorderRadius.circular(KenaRadius.card),
                      border: Border.all(color: KenaColors.line),
                    ),
                    child: Row(
                      children: [
                        Avatar.forName(m.userId, size: 38),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.userId == controller.userId ? 'Vos' : m.userId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: KenaTypography.body.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(_roleLabel(m.role), style: KenaTypography.caption),
                            ],
                          ),
                        ),
                        if (canRemove && m.userId != controller.userId)
                          IconButton(
                            tooltip: 'Sacar del grupo',
                            icon: Icon(Icons.person_remove_rounded, color: KenaColors.red, size: 18),
                            onPressed: () => _confirmRemove(m.userId, m.userId),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _roleLabel(MembershipRole role) => switch (role) {
        MembershipRole.owner => 'Anfitrión del grupo',
        MembershipRole.admin => 'Administrador',
        MembershipRole.member => 'Miembro',
      };
}
