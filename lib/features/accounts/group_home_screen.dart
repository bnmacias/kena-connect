import 'package:flutter/material.dart';

import '../../accounts/domain/auth_controller.dart';
import '../../accounts/domain/group_controller.dart';
import '../../accounts/domain/models/kena_group.dart';
import '../../theme/kena_colors.dart';
import '../../theme/kena_spacing.dart';
import '../../theme/kena_typography.dart';
import '../../widgets/kena_confirm_sheet.dart';
import '../../widgets/kena_field.dart';
import '../../widgets/kena_glass_button.dart';
import '../../widgets/option_row.dart';
import '../create_room/create_room_screen.dart';
import '../join_room/join_room_screen.dart';
import 'activate_plan_screen.dart';
import 'group_members_screen.dart';

/// Home del flujo de cuentas (ver brief, sección 8 y 9) — grupo activo,
/// crear/unirse a una sala, miembros, plan. A propósito **no** muestra
/// historial de salas (brief, sección 8) — eso sigue siendo del
/// `HomeScreen` local de siempre, que no cambia.
///
/// "Crear sala"/"Unirme a sala" siguen siendo, puertas adentro, el
/// mismo `CreateRoomScreen`/`JoinRoomScreen` de siempre — el brief pide
/// explícitamente no tocar el networking. Lo único que se agrega es la
/// metadata organizativa del grupo (`GroupRoom`, ver
/// `accounts/domain/models/group_room.dart`), no una integración real
/// (eso necesitaría que ambos dispositivos ya estén en la misma red
/// local, algo que un backend de grupos no resuelve).
class GroupHomeScreen extends StatefulWidget {
  const GroupHomeScreen({super.key, required this.groupController});

  final GroupController groupController;

  @override
  State<GroupHomeScreen> createState() => _GroupHomeScreenState();
}

class _GroupHomeScreenState extends State<GroupHomeScreen> {
  Future<void> _addRoom() async {
    final controller = TextEditingController();
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nueva sala del grupo', style: KenaTypography.titleXL),
                const SizedBox(height: KenaSpacing.lg),
                KenaField(
                  label: 'Nombre',
                  controller: controller,
                  hint: 'Ej: Padres, Hermanos, Primos',
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (v) => Navigator.of(sheetContext).pop(v),
                ),
                KenaGlassButton(
                  onPressed: () => Navigator.of(sheetContext).pop(controller.text),
                  child: const Text('Crear'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    await widget.groupController.createRoom(trimmed);
    if (mounted) setState(() {});
  }

  Future<void> _signOut() async {
    final confirmed = await KenaConfirmSheet.show(
      context,
      title: '¿Cerrar sesión?',
      body: 'Vas a tener que volver a iniciar sesión para ver tus grupos.',
      confirmLabel: 'Cerrar sesión',
      tone: KenaConfirmTone.danger,
    );
    if (confirmed != true) return;
    await AuthController.instance.signOut();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.groupController;
    final group = controller.active;
    final entitlement = controller.entitlement;

    return KenaBackground(
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(group?.name ?? 'Tu grupo'),
          actions: [
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: Icon(Icons.logout_rounded, color: KenaColors.text2),
              onPressed: _signOut,
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              if (group != null && entitlement != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: KenaColors.accentSoft,
                    borderRadius: BorderRadius.circular(KenaRadius.card),
                    border: Border.all(color: KenaColors.accent.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${controller.activeMembers.length} miembros', style: KenaTypography.body.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                              entitlement.isActive
                                  ? '${group.isTrial ? 'Prueba gratuita' : 'Plan ${group.planType.label}'}'
                                      '${group.planType.durationDays > 0 ? ' · ${entitlement.remainingDays} días restantes' : ''}'
                                  : 'Plan ${group.planType.label} vencido',
                              style: KenaTypography.caption.copyWith(color: entitlement.isActive ? KenaColors.text2 : KenaColors.red),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ActivatePlanScreen(groupController: controller)),
                          );
                          if (mounted) setState(() {});
                        },
                        child: const Text('Cambiar plan'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: KenaSpacing.lg),
              OptionCard(
                icon: Icons.add_rounded,
                title: 'Crear una sala',
                subtitle: 'Red local para el grupo',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateRoomScreen())),
              ),
              const SizedBox(height: KenaSpacing.sm),
              OptionCard(
                icon: Icons.group_add_rounded,
                title: 'Unirme a una sala',
                subtitle: 'Con código, QR o cerca tuyo',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JoinRoomScreen())),
              ),
              const SizedBox(height: KenaSpacing.sm),
              OptionCard(
                icon: Icons.groups_rounded,
                title: 'Miembros',
                subtitle: '${controller.activeMembers.length} en el grupo',
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => GroupMembersScreen(groupController: controller)),
                  );
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: KenaSpacing.xl),
              Row(
                children: [
                  Expanded(child: Text('SALAS DEL GRUPO', style: KenaTypography.label)),
                  IconButton(
                    tooltip: 'Nueva sala',
                    icon: Icon(Icons.add_circle_outline_rounded, color: KenaColors.accent, size: 20),
                    onPressed: _addRoom,
                  ),
                ],
              ),
              if (controller.activeRooms.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Todavía no hay salas nombradas en este grupo.', style: KenaTypography.bodySmall),
                ),
              for (final room in controller.activeRooms)
                Padding(
                  padding: const EdgeInsets.only(bottom: KenaSpacing.sm),
                  child: OptionCard(
                    icon: Icons.forum_rounded,
                    title: room.name,
                    subtitle: 'Tocá para armarla ahora',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => CreateRoomScreen(initialRoomName: room.name)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
