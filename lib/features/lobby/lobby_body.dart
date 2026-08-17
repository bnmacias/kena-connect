import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/network/chat_host_server.dart';
import '../../core/network/host_discovery_responder.dart';
import '../../core/utils/connection_code.dart';
import '../../theme/kena_colors.dart';
import '../../theme/kena_spacing.dart';
import '../../theme/kena_typography.dart';
import '../../widgets/gradient_text.dart';
import '../../widgets/join_request_prompter.dart';
import '../../widgets/kena_glass_button.dart';
import '../../widgets/participant_row.dart';
import '../../widgets/reveal_in.dart';

/// Contenido de la sala de espera del anfitrión: código, QR para
/// invitar, lista de participantes en vivo, y el botón "Entrar a la
/// sala" — sin `Scaffold`/`AppBar` propios, para poder embeberse tanto
/// en [LobbyScreen] (la retoma de sala tras una migración/transferencia
/// de anfitrión, ver `HostTakeoverScreen`) como directamente dentro de
/// `CreateRoomScreen` (el flujo normal de crear una sala, fusionado en
/// una sola pantalla continua — ver auditoría de diseño, sección F.1).
///
/// Dueña también del pedido de "alguien quiere unirse" ([JoinRequestPrompter]):
/// tiene que poder aparecer mientras se está en esta etapa, no sólo una
/// vez dentro de la sala (ver `RoomShellScreen`, que usa el mismo
/// componente).
class LobbyBody extends StatefulWidget {
  const LobbyBody({super.key, required this.server, required this.discovery, required this.onEnterRoom});

  final ChatHostServer server;
  final HostDiscoveryResponder discovery;
  final VoidCallback onEnterRoom;

  @override
  State<LobbyBody> createState() => _LobbyBodyState();
}

class _LobbyBodyState extends State<LobbyBody> {
  late final _joinRequestPrompter = JoinRequestPrompter(
    roomName: widget.server.roomName,
    pendingRequests: () => widget.server.pendingJoinRequests,
    onAccept: widget.server.acceptJoinRequest,
    onReject: widget.server.rejectJoinRequest,
  );

  @override
  void initState() {
    super.initState();
    widget.server.joinRequests.listen((_) => _maybeShowJoinRequestDialog());
    // Por si ya había un pedido pendiente al montar este widget (p.ej.
    // se coló uno justo entre que el servidor arrancó y esta pantalla
    // terminó de construirse).
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowJoinRequestDialog());
  }

  void _maybeShowJoinRequestDialog() {
    if (!mounted) return;
    _joinRequestPrompter.maybeShow(context);
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: formatConnectionCode(widget.server.code)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código copiado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = formatConnectionCode(widget.server.code);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              Text('COMPARTÍ ESTE CÓDIGO', textAlign: TextAlign.center, style: KenaTypography.label),
              const SizedBox(height: KenaSpacing.md + 2),
              RevealIn(
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(KenaRadius.button)),
                        child: QrImageView(
                          data: code,
                          size: 148,
                          backgroundColor: Colors.white,
                          eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: KenaColors.bg),
                          dataModuleStyle: QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: KenaColors.bg,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: KenaSpacing.md + 2),
                    Center(child: GradientText(code, style: KenaTypography.code, gradient: KenaColors.brandGradient)),
                  ],
                ),
              ),
              Center(
                child: TextButton.icon(
                  onPressed: _copyCode,
                  icon: Icon(Icons.copy_rounded, size: 13, color: KenaColors.text3),
                  label: Text('Copiar código', style: KenaTypography.caption),
                ),
              ),
              const SizedBox(height: KenaSpacing.sm),
              StreamBuilder<List<RoomMember>>(
                stream: widget.server.membersStream,
                initialData: widget.server.members,
                builder: (context, snapshot) {
                  final members = snapshot.data ?? const <RoomMember>[];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: KenaColors.card,
                      borderRadius: BorderRadius.circular(KenaRadius.card),
                      border: Border.all(color: KenaColors.line),
                    ),
                    child: Column(
                      children: [
                        for (final m in members)
                          ParticipantRow(name: m.name, isSelf: m.id == ChatHostServer.hostSenderId, isHost: m.isHost),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: KenaGlassButton(onPressed: widget.onEnterRoom, child: const Text('Entrar a la sala')),
        ),
      ],
    );
  }
}
