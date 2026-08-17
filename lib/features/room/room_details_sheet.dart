import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/network/chat_host_server.dart';
import '../../core/utils/connection_code.dart';
import '../../theme/kena_colors.dart';
import '../../theme/kena_spacing.dart';
import '../../theme/kena_typography.dart';
import '../../widgets/gradient_text.dart';
import '../../widgets/kena_glass_button.dart';
import '../../widgets/option_row.dart';
import '../../widgets/participant_row.dart';
import '../../widgets/reveal_in.dart';
import 'domain/room_session.dart';

/// "Detalles de la sala": código/QR para invitar (si sos anfitrión),
/// participantes, silenciar notificaciones, y las acciones de ciclo de
/// vida — todo en una sola hoja inferior.
///
/// Antes esto eran dos pantallas completas (Configuración de la sala y
/// Participantes), alcanzables además por dos rutas distintas desde la
/// bandeja (tocar el nombre de la sala, o el ícono de personas). Es
/// literalmente la misma información — quién está y cómo invito —
/// partida sin ninguna razón funcional (ver auditoría de diseño,
/// hallazgo #4 y sección F.2). Ahora es un único lugar, alcanzable por
/// cualquiera de las dos rutas de siempre.
///
/// Renombrar la sala sigue fuera de alcance: [RoomSession] no expone
/// forma de cambiar `roomName` una vez creada (ver ROADMAP.md).
class RoomDetailsSheet extends StatelessWidget {
  const RoomDetailsSheet({
    super.key,
    required this.session,
    required this.onOpenThread,
    required this.onToggleMute,
    required this.onTransferMember,
    this.onTransfer,
    this.onFinish,
    this.onLeave,
    this.onSwitch,
  });

  final RoomSession session;

  /// Tocar una fila de participante (que no seas vos) abre — o retoma —
  /// la conversación privada con esa persona.
  final ValueChanged<String> onOpenThread;
  final VoidCallback onToggleMute;

  /// Ícono de transferir en la fila de un participante puntual (sólo
  /// visible si sos anfitrión) — distinto de [onTransfer], que abre el
  /// selector general desde las acciones de abajo.
  final ValueChanged<RoomMember> onTransferMember;
  final VoidCallback? onTransfer;
  final VoidCallback? onFinish;
  final VoidCallback? onLeave;
  final VoidCallback? onSwitch;

  static Future<void> show(
    BuildContext context, {
    required RoomSession session,
    required ValueChanged<String> onOpenThread,
    required VoidCallback onToggleMute,
    required ValueChanged<RoomMember> onTransferMember,
    VoidCallback? onTransfer,
    VoidCallback? onFinish,
    VoidCallback? onLeave,
    VoidCallback? onSwitch,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RoomDetailsSheet(
        session: session,
        onOpenThread: onOpenThread,
        onToggleMute: onToggleMute,
        onTransferMember: onTransferMember,
        onTransfer: onTransfer,
        onFinish: onFinish,
        onLeave: onLeave,
        onSwitch: onSwitch,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = session.code;
    final isHost = session.isHost;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          top: false,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(color: KenaColors.lineStrong, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(session.roomName, style: KenaTypography.titleXL),
              const SizedBox(height: 4),
              Text(
                isHost ? 'Sos el anfitrión de esta sala.' : 'Estás participando en esta sala.',
                style: KenaTypography.bodySmall,
              ),
              if (code != null) ...[
                const SizedBox(height: KenaSpacing.xxl),
                RevealIn(
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(KenaRadius.sheet)),
                          child: QrImageView(
                            data: formatConnectionCode(code),
                            size: 128,
                            backgroundColor: Colors.white,
                            eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: KenaColors.bg),
                            dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: KenaColors.bg),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: GradientText(
                          formatConnectionCode(code),
                          style: KenaTypography.code.copyWith(fontSize: 18),
                          gradient: KenaColors.brandGradient,
                        ),
                      ),
                    ],
                  ),
                ),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: formatConnectionCode(code)));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado')));
                    },
                    icon: Icon(Icons.copy_rounded, size: 13, color: KenaColors.text3),
                    label: Text('Copiar código', style: KenaTypography.caption),
                  ),
                ),
              ],
              const SizedBox(height: KenaSpacing.xl),
              StreamBuilder<List<RoomMember>>(
                stream: session.membersStream,
                initialData: session.members,
                builder: (context, snapshot) {
                  final members = snapshot.data ?? const <RoomMember>[];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10, left: 2),
                        child: Text(
                          '${members.length} ${members.length == 1 ? 'PARTICIPANTE' : 'PARTICIPANTES'}',
                          style: KenaTypography.label,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: KenaColors.card,
                          borderRadius: BorderRadius.circular(KenaRadius.card),
                          border: Border.all(color: KenaColors.line),
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < members.length; i++)
                              Column(
                                children: [
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: members[i].id == session.mySenderId ? null : () => onOpenThread(members[i].id),
                                      child: ParticipantRow(
                                        name: members[i].name,
                                        isSelf: members[i].id == session.mySenderId,
                                        isHost: members[i].isHost,
                                        trailing: (isHost && members[i].id != session.mySenderId)
                                            ? IconButton(
                                                tooltip: 'Transferir anfitrión',
                                                icon: Icon(Icons.swap_horiz_rounded, color: KenaColors.accent, size: 18),
                                                onPressed: () => onTransferMember(members[i]),
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                  if (i < members.length - 1) Divider(height: 1, color: KenaColors.line),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: KenaSpacing.sm),
              OptionCard(
                icon: session.isMuted ? Icons.notifications_off_rounded : Icons.notifications_active_rounded,
                title: session.isMuted ? 'Notificaciones silenciadas' : 'Notificaciones activas',
                onTap: onToggleMute,
                trailing: Switch(value: !session.isMuted, onChanged: (_) => onToggleMute()),
              ),
              if (onTransfer != null) ...[
                const SizedBox(height: KenaSpacing.sm),
                OptionCard(icon: Icons.workspace_premium_rounded, title: 'Transferir anfitrión', onTap: onTransfer),
              ],
              const SizedBox(height: KenaSpacing.xxl),
              if (onSwitch != null) ...[
                KenaGhostButton(onPressed: onSwitch, child: const Text('Cambiar de sala')),
                const SizedBox(height: KenaSpacing.sm),
              ],
              if (onLeave != null)
                KenaGhostButton(danger: true, onPressed: onLeave, child: const Text('Salir de la sala')),
              if (onFinish != null)
                KenaGhostButton(danger: true, onPressed: onFinish, child: const Text('Finalizar sala')),
            ],
          ),
        );
      },
    );
  }
}

