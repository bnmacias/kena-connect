import 'package:flutter/material.dart';

import '../core/network/chat_host_server.dart';
import '../theme/kena_colors.dart';
import '../theme/kena_spacing.dart';
import '../theme/kena_typography.dart';
import 'avatar.dart';
import 'kena_glass_button.dart';

/// Muestra "alguien quiere unirse" — un pedido pendiente por vez, nunca
/// varios diálogos apilados si llegan casi juntos — y lo hace por
/// [KenaGlassButton]/[KenaGhostButton] en vez del `AlertDialog` nativo
/// de Material, para no romper el lenguaje visual del resto de la app.
///
/// Antes esta lógica (la cola de "uno por vez" + el diálogo en sí)
/// estaba copiada línea por línea entre `LobbyBody` y `RoomShellScreen`
/// (ver auditoría de diseño, sección K) — ahora es una sola clase que
/// las dos instancian.
class JoinRequestPrompter {
  JoinRequestPrompter({
    required this.roomName,
    required this.pendingRequests,
    required this.onAccept,
    required this.onReject,
  });

  final String roomName;
  final List<PendingJoinRequest> Function() pendingRequests;
  final void Function(String connKey) onAccept;
  final void Function(String connKey) onReject;

  bool _open = false;

  /// El caller es responsable de chequear `mounted` antes de llamar —
  /// esta clase no es un `State`, no tiene forma propia de saberlo.
  void maybeShow(BuildContext context) {
    if (_open) return;
    final requests = pendingRequests();
    if (requests.isEmpty) return;
    final request = requests.first;
    _open = true;
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => _JoinRequestSheet(
        senderName: request.senderName,
        roomName: roomName,
        onAccept: () {
          onAccept(request.connKey);
          Navigator.of(sheetContext).pop();
        },
        onReject: () {
          onReject(request.connKey);
          Navigator.of(sheetContext).pop();
        },
      ),
    ).then((_) {
      _open = false;
      // Por si llegó (o quedó) otro pedido mientras se mostraba éste.
      WidgetsBinding.instance.addPostFrameCallback((_) => maybeShow(context));
    });
  }
}

class _JoinRequestSheet extends StatelessWidget {
  const _JoinRequestSheet({
    required this.senderName,
    required this.roomName,
    required this.onAccept,
    required this.onReject,
  });

  final String senderName;
  final String roomName;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(KenaSpacing.xl, KenaSpacing.xl, KenaSpacing.xl, KenaSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar.forName(senderName, size: 44),
            const SizedBox(height: KenaSpacing.lg),
            Text('Alguien quiere unirse', style: KenaTypography.titleXL),
            const SizedBox(height: KenaSpacing.sm),
            Text.rich(
              TextSpan(
                style: KenaTypography.bodySmall,
                children: [
                  TextSpan(text: '"$senderName" ', style: TextStyle(fontWeight: FontWeight.w700, color: KenaColors.text)),
                  TextSpan(text: 'quiere unirse a "$roomName".'),
                ],
              ),
            ),
            const SizedBox(height: KenaSpacing.xxl),
            KenaGlassButton(onPressed: onAccept, child: const Text('Aceptar')),
            const SizedBox(height: KenaSpacing.sm),
            KenaGhostButton(onPressed: onReject, child: const Text('Rechazar')),
          ],
        ),
      ),
    );
  }
}
