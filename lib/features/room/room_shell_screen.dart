import 'package:flutter/material.dart';

import '../../core/network/chat_client_connection.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/notifications/room_foreground_service.dart';
import '../../core/utils/host_session_store.dart';
import '../../core/utils/participant_session_store.dart';
import '../../core/utils/pending_transfer_history.dart';
import '../../core/network/chat_host_server.dart' show RoomMember;
import '../../theme/kena_colors.dart';
import '../../theme/kena_spacing.dart';
import '../../theme/kena_typography.dart';
import '../../widgets/avatar.dart';
import '../../widgets/connection_phase_style.dart';
import '../../widgets/join_request_prompter.dart';
import '../../widgets/kena_confirm_sheet.dart';
import '../../widgets/kena_glass_button.dart';
import '../../widgets/option_row.dart';
import '../join_room/join_room_screen.dart';
import 'chat_thread_screen.dart';
import 'domain/active_room_registry.dart';
import 'domain/connection_phase.dart';
import 'domain/conversation_summary.dart';
import 'domain/room_session.dart';
import 'host_takeover_screen.dart';
import 'room_details_sheet.dart';

/// Copy propio de la bandeja (no reusa [connectionPhaseLabel] a secas):
/// acá el nombre de la sala ya está en el título de la barra, así que
/// repetirlo en el subtítulo sería ruido.
String _statusLabel(ConnectionPhase phase) {
  switch (phase) {
    case ConnectionPhase.connected:
      return 'Conexión activa';
    case ConnectionPhase.unstable:
      return 'Conexión inestable';
    case ConnectionPhase.reconnecting:
      return 'Reconectando…';
    case ConnectionPhase.lost:
      return 'Conexión perdida';
    case ConnectionPhase.restored:
      return 'Conexión restablecida';
    case ConnectionPhase.preparing:
    case ConnectionPhase.connecting:
      return 'Conectando…';
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// La bandeja de la sala: General + una conversación por cada otro
/// participante, más el estado de conexión y las acciones del
/// anfitrión/participante. Es la pantalla principal mientras se está
/// "dentro" de una sala. En pantallas anchas (tablet/desktop) muestra
/// la lista y la conversación activa lado a lado.
class RoomShellScreen extends StatefulWidget {
  const RoomShellScreen({super.key, required this.session});

  final RoomSession session;

  @override
  State<RoomShellScreen> createState() => _RoomShellScreenState();
}

class _RoomShellScreenState extends State<RoomShellScreen> {
  static const _wideBreakpoint = 700.0;

  late final ConnectionPhaseTracker _phaseTracker;
  ConnectionPhase _phase = ConnectionPhase.connected;
  List<ConversationSummary> _conversations = const [];
  Map<String?, int> _unread = const {};
  String? _selectedPeerId;
  bool _selectedIsGeneral = false;
  bool _hasSelection = false;
  late final _joinRequestPrompter = JoinRequestPrompter(
    roomName: widget.session.roomName,
    pendingRequests: () => widget.session.pendingJoinRequests,
    onAccept: widget.session.acceptJoinRequest,
    onReject: widget.session.rejectJoinRequest,
  );

  @override
  void initState() {
    super.initState();
    NotificationService.instance.init();
    // Mientras esta pantalla exista hay una sala activa — mantiene vivo el
    // proceso (y con él, el socket) si la pantalla se bloquea o la app
    // pasa a segundo plano (ver RoomForegroundService). Se detiene sólo en
    // _goHome/_goSwitchRoom (las únicas salidas reales) o si la conexión
    // se da por perdida — nunca en dispose(), porque una promoción a
    // anfitrión (ver _handlePromotion) también dispara dispose() de esta
    // pantalla sin que el usuario haya "salido" de la sala.
    RoomForegroundService.start(widget.session.roomName);
    ActiveRoomRegistry.set(widget.session);
    final wasAlreadyConnected = widget.session.currentStatus == ConnectionStatus.connected;
    _phaseTracker = ConnectionPhaseTracker(widget.session);
    _phase = _phaseTracker.current;
    _unread = widget.session.unreadCounts;
    _recompute();
    _phaseTracker.stream.listen((p) {
      if (!mounted) return;
      setState(() => _phase = p);
      // Se agotaron los reintentos: no queda nada que mantener vivo en
      // segundo plano — apagarlo evita una notificación de "conectado"
      // engañosa mientras se muestra el botón de volver al inicio.
      if (p == ConnectionPhase.lost) RoomForegroundService.stop();
    });
    widget.session.statusStream.listen((s) {
      if (!mounted) return;
      if (s == ConnectionStatus.closedByHost) _showRoomClosedDialog();
    });
    widget.session.messages.listen((_) {
      if (!mounted) return;
      setState(_recompute);
    });
    widget.session.membersStream.listen((_) {
      if (!mounted) return;
      setState(_recompute);
    });
    widget.session.unreadStream.listen((u) {
      if (!mounted) return;
      setState(() => _unread = u);
    });
    widget.session.promotedToHostStream.listen(_handlePromotion);
    widget.session.joinRequestsStream.listen((_) => _maybeShowJoinRequestDialog());
    // Por si ya había un pedido pendiente al entrar (el anfitrión crea
    // la sala, alguien pide unirse mientras todavía está en el lobby, y
    // recién después entra acá).
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowJoinRequestDialog());
    if (wasAlreadyConnected) {
      // Feedback de conexión exitosa (sección 7 del brief): sólo la
      // primera vez que se entra ya conectado — las reconexiones
      // posteriores las cubre la franja global con "restablecida".
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Conectado a "${widget.session.roomName}"'),
            backgroundColor: KenaColors.card2,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _phaseTracker.dispose();
    super.dispose();
  }

  void _recompute() {
    _conversations = buildConversationSummaries(widget.session);
  }

  // Los dos únicos lugares donde esta pantalla efectivamente termina de
  // usar `widget.session` (en los dos casos ya se llamó antes a
  // leaveRoom()/finishRoom()/transferHostTo(), así que la conexión de
  // red ya está cerrada) — sin este dispose(), los streams/timers
  // internos de la sesión (RoomSession → ResilientRoomSession →
  // ChatClientConnection) quedaban vivos para siempre en memoria cada
  // vez que se salía de una sala.
  void _goHome() {
    RoomForegroundService.stop();
    // Salida real y a propósito (finalizar/transferir, salir, o darse
    // por vencido) — a diferencia de cerrar la app a la fuerza, acá sí
    // corresponde que la sala deje de recuperarse sola la próxima vez
    // que se abra Kena (ver `host_session_resume.dart`).
    if (widget.session.isHost) {
      HostSessionStore.clear();
    } else {
      ParticipantSessionStore.clear();
    }
    ActiveRoomRegistry.clearIfCurrent(widget.session);
    widget.session.dispose();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _goSwitchRoom() {
    RoomForegroundService.stop();
    if (widget.session.isHost) {
      HostSessionStore.clear();
    } else {
      ParticipantSessionStore.clear();
    }
    ActiveRoomRegistry.clearIfCurrent(widget.session);
    widget.session.dispose();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const JoinRoomScreen()),
      (route) => route.isFirst,
    );
  }

  Future<void> _handlePromotion(String roomName) async {
    if (!mounted) return;
    await KenaInfoSheet.show(
      context,
      title: 'Ahora sos el anfitrión',
      body: 'Te transfirieron "$roomName". Vamos a preparar la continuación de la sala.',
      buttonLabel: 'Continuar',
      icon: Icons.workspace_premium_rounded,
    );
    if (!mounted) return;
    ActiveRoomRegistry.clearIfCurrent(widget.session);
    final yourName = widget.session.myName;
    // La conexión vieja (como participante) ya no tiene ningún uso desde
    // acá en más — este dispositivo va a levantar su propio servidor
    // (ver `HostTakeoverScreen`). Sin este dispose(), el socket/timers de
    // `widget.session` quedaban vivos para siempre en memoria en cada
    // promoción a anfitrión (mismo motivo que el dispose() explícito en
    // `_goHome`/`_goSwitchRoom`).
    widget.session.dispose();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HostTakeoverScreen(roomName: roomName, yourName: yourName)),
      (route) => route.isFirst,
    );
  }

  Future<void> _showRoomClosedDialog() async {
    ActiveRoomRegistry.clearIfCurrent(widget.session);
    await KenaInfoSheet.show(
      context,
      title: 'La sala fue finalizada',
      body: widget.session.closeReason ?? 'El anfitrión finalizó "${widget.session.roomName}".',
      buttonLabel: 'Volver al inicio',
      icon: Icons.wifi_off_rounded,
    );
    if (!mounted) return;
    _goHome();
  }

  /// Muestra un pedido de ingreso pendiente por vez (nunca varios
  /// apilados) — corrige el bug de seguridad reportado por uso: antes,
  /// cualquiera en la misma red (por ejemplo, el wifi de un avión)
  /// entraba directo con un toque, sin que el anfitrión tuviera forma
  /// de decir que no (ver `ChatHostServer.requireApproval`). No hace
  /// nada si esta sala no exige aprobación — ahí la lista siempre está
  /// vacía. Mismo componente que usa `LobbyBody` — ver
  /// `JoinRequestPrompter`.
  void _maybeShowJoinRequestDialog() {
    if (!mounted) return;
    _joinRequestPrompter.maybeShow(context);
  }

  Future<void> _confirmFinishRoom() async {
    final confirmed = await KenaConfirmSheet.show(
      context,
      title: '¿Querés finalizar esta sala?',
      body: 'Todos los participantes serán desconectados.',
      confirmLabel: 'Finalizar sala',
      tone: KenaConfirmTone.danger,
    );
    if (confirmed == true) {
      await widget.session.finishRoom();
      if (!mounted) return;
      _goHome();
    }
  }

  /// Antes de perder la sesión: si más adelante volvemos a unirnos a la
  /// sala que arrancó quien la sucede (mismo nombre, código distinto —
  /// ver ROADMAP.md), esto es lo que le va a permitir a `JoinRoomScreen`
  /// no arrancar de cero (ver `PendingTransferHistoryStore`). Compartido
  /// por las dos formas de transferir (selector general y el ícono de
  /// una fila puntual en Detalles de la sala) para que las dos se
  /// comporten igual.
  Future<void> _transferHostTo(RoomMember member) async {
    await PendingTransferHistoryStore.save(roomName: widget.session.roomName, messages: widget.session.messageLog);
    await widget.session.transferHostTo(member);
    if (!mounted) return;
    ActiveRoomRegistry.clearIfCurrent(widget.session);
    _goHome();
  }

  Future<void> _openTransferPicker() async {
    final others = widget.session.members.where((m) => m.id != widget.session.mySenderId).toList();
    if (others.isEmpty) return;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => _TransferHostSheet(members: others),
    );
    if (chosen == null) return;
    await _transferHostTo(others.firstWhere((m) => m.id == chosen));
  }

  Future<void> _confirmTransferMember(RoomMember member) async {
    final confirmed = await KenaConfirmSheet.show(
      context,
      title: 'Transferir anfitrión',
      body: '${member.name} pasará a ser el anfitrión y vos vas a salir de la sala.',
      confirmLabel: 'Transferir y salir',
      tone: KenaConfirmTone.neutral,
      icon: Icons.workspace_premium_rounded,
    );
    if (confirmed == true) await _transferHostTo(member);
  }

  Future<void> _confirmLeaveRoom({required bool andSwitch}) async {
    final confirmed = await KenaConfirmSheet.show(
      context,
      title: andSwitch ? '¿Cambiar de sala?' : '¿Salir de la sala?',
      body: andSwitch
          ? 'Vas a salir de "${widget.session.roomName}" y buscar otra sala.'
          : 'Vas a dejar de ver los mensajes de "${widget.session.roomName}".',
      confirmLabel: andSwitch ? 'Cambiar de sala' : 'Salir de la sala',
      tone: andSwitch ? KenaConfirmTone.neutral : KenaConfirmTone.danger,
      icon: andSwitch ? Icons.swap_horiz_rounded : null,
    );
    if (confirmed == true) {
      await widget.session.leaveRoom();
      if (!mounted) return;
      if (andSwitch) {
        _goSwitchRoom();
      } else {
        _goHome();
      }
    }
  }

  void _selectThread(ConversationSummary summary, {required bool wide}) {
    if (wide) {
      setState(() {
        _hasSelection = true;
        _selectedIsGeneral = summary.isGeneral;
        _selectedPeerId = summary.peerId;
      });
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(session: widget.session, peerId: summary.peerId),
        ),
      );
    }
  }

  void _openRoomInfo() {
    final isHost = widget.session.isHost;
    final canTransfer = isHost && widget.session.members.length > 1;
    RoomDetailsSheet.show(
      context,
      session: widget.session,
      onOpenThread: (peerId) {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ChatThreadScreen(session: widget.session, peerId: peerId)),
        );
      },
      onToggleMute: () => setState(() => widget.session.setMuted(!widget.session.isMuted)),
      onTransferMember: (member) {
        Navigator.of(context).pop();
        _confirmTransferMember(member);
      },
      onTransfer: canTransfer
          ? () {
              Navigator.of(context).pop();
              _openTransferPicker();
            }
          : null,
      onFinish: isHost
          ? () {
              Navigator.of(context).pop();
              _confirmFinishRoom();
            }
          : null,
      onSwitch: !isHost
          ? () {
              Navigator.of(context).pop();
              _confirmLeaveRoom(andSwitch: true);
            }
          : null,
      onLeave: !isHost
          ? () {
              Navigator.of(context).pop();
              _confirmLeaveRoom(andSwitch: false);
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return KenaBackground(
      builder: (context) => Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: InkWell(
          onTap: _openRoomInfo,
          child: Text(widget.session.roomName),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                _StatusDot(color: connectionPhaseColor(_phase)),
                const SizedBox(width: 6),
                Text(_statusLabel(_phase), style: KenaTypography.bodySmall.copyWith(fontSize: 12.5, height: 1, color: KenaColors.text2)),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Detalles de la sala',
            icon: const Icon(Icons.groups_rounded),
            onPressed: _openRoomInfo,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'info':
                  _openRoomInfo();
                case 'mute':
                  setState(() => widget.session.setMuted(!widget.session.isMuted));
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'info', child: Text('Detalles de la sala')),
              PopupMenuItem(value: 'mute', child: Text(widget.session.isMuted ? 'Activar notificaciones' : 'Silenciar notificaciones')),
            ],
          ),
        ],
      ),
      body: _phase == ConnectionPhase.lost
            ? _LostConnectionState(onBackHome: _goHome)
            : LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= _wideBreakpoint;
                  final list = _ConversationList(
                    conversations: _conversations,
                    unread: _unread,
                    mySenderId: widget.session.mySenderId,
                    selectedPeerId: wide && _hasSelection ? (_selectedIsGeneral ? null : _selectedPeerId) : null,
                    selectedIsGeneral: wide && _hasSelection && _selectedIsGeneral,
                    onTap: (summary) => _selectThread(summary, wide: wide),
                  );
                  if (!wide) return list;
                  return Row(
                    children: [
                      SizedBox(width: 360, child: list),
                      VerticalDivider(width: 1, color: KenaColors.line),
                      Expanded(
                        child: _hasSelection
                            ? ChatThreadScreen(
                                key: ValueKey(_selectedIsGeneral ? '__general__' : _selectedPeerId),
                                session: widget.session,
                                peerId: _selectedIsGeneral ? null : _selectedPeerId,
                              )
                            : const _EmptySelectionState(),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}


class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.conversations,
    required this.unread,
    required this.mySenderId,
    required this.selectedPeerId,
    required this.selectedIsGeneral,
    required this.onTap,
  });

  final List<ConversationSummary> conversations;
  final Map<String?, int> unread;
  final String mySenderId;
  final String? selectedPeerId;
  final bool selectedIsGeneral;
  final void Function(ConversationSummary summary) onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: conversations.length,
      separatorBuilder: (_, _) => Divider(height: 1, indent: 76, color: KenaColors.line),
      itemBuilder: (context, index) {
        final summary = conversations[index];
        final isSelected = summary.isGeneral ? selectedIsGeneral : summary.peerId == selectedPeerId;
        return _ConversationRow(
          summary: summary,
          mySenderId: mySenderId,
          unreadCount: unread[summary.peerId] ?? 0,
          selected: isSelected,
          onTap: () => onTap(summary),
        );
      },
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.summary,
    required this.mySenderId,
    required this.unreadCount,
    required this.selected,
    required this.onTap,
  });

  final ConversationSummary summary;
  final String mySenderId;
  final int unreadCount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final last = summary.lastMessage;
    final preview = last == null
        ? (summary.isGeneral ? 'Sin mensajes todavía' : 'Iniciar conversación privada')
        : (last.senderId == mySenderId ? 'Vos: ${last.text}' : last.text ?? '');
    final hasUnread = unreadCount > 0;

    return Material(
      color: selected ? KenaColors.card2 : Colors.transparent,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        leading: summary.isGeneral
            ? Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(gradient: KenaColors.brandGradient, shape: BoxShape.circle),
                child: Icon(Icons.forum_rounded, color: KenaColors.onAccent, size: 22),
              )
            : Avatar.forName(summary.title, size: 48),
        title: Text(summary.title,
            style: KenaTypography.bodyLarge.copyWith(
                height: 1, fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w700, color: KenaColors.text)),
        subtitle: Text(
          preview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: KenaTypography.bodySmall.copyWith(
            color: hasUnread ? KenaColors.text : KenaColors.text2,
            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (last != null)
              Text(
                '${DateTime.fromMillisecondsSinceEpoch(last.timestamp).hour.toString().padLeft(2, '0')}:'
                '${DateTime.fromMillisecondsSinceEpoch(last.timestamp).minute.toString().padLeft(2, '0')}',
                style: KenaTypography.bodySmall.copyWith(fontSize: 12, height: 1, color: hasUnread ? KenaColors.accent : KenaColors.text2),
              ),
            if (hasUnread) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: KenaColors.accent, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 20),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  textAlign: TextAlign.center,
                  style: KenaTypography.caption.copyWith(color: KenaColors.onAccent, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptySelectionState extends StatelessWidget {
  const _EmptySelectionState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Elegí una conversación', style: TextStyle(color: KenaColors.text2)),
    );
  }
}

class _LostConnectionState extends StatelessWidget {
  const _LostConnectionState({required this.onBackHome});

  final VoidCallback onBackHome;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: KenaColors.redSoft, shape: BoxShape.circle),
              child: Icon(Icons.wifi_off_rounded, size: 28, color: KenaColors.red),
            ),
            const SizedBox(height: KenaSpacing.lg),
            Text('Se perdió la conexión con la sala', style: KenaTypography.titleL.copyWith(fontSize: 18)),
            const SizedBox(height: KenaSpacing.sm),
            Text(
              'Probá acercarte al resto del grupo o volvé a unirte con el código.',
              textAlign: TextAlign.center,
              style: KenaTypography.bodySmall,
            ),
            const SizedBox(height: KenaSpacing.xxl),
            SizedBox(
              width: 220,
              child: KenaGlassButton(onPressed: onBackHome, child: const Text('Volver al inicio')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hoja para elegir a quién transferir el anfitrión — reemplaza el
/// `AlertDialog`+`RadioGroup` nativo que había acá antes (único diálogo
/// de Material que quedaba en la app, junto con el de editar mensaje en
/// [ChatThreadScreen]), para no romper el lenguaje "vidrio líquido" del
/// resto de Kena.
class _TransferHostSheet extends StatefulWidget {
  const _TransferHostSheet({required this.members});

  final List<RoomMember> members;

  @override
  State<_TransferHostSheet> createState() => _TransferHostSheetState();
}

class _TransferHostSheetState extends State<_TransferHostSheet> {
  late String _selected = widget.members.first.id;

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
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: KenaColors.accentSoft, borderRadius: BorderRadius.circular(KenaRadius.button)),
              alignment: Alignment.center,
              child: Icon(Icons.workspace_premium_rounded, color: KenaColors.accent, size: 24),
            ),
            const SizedBox(height: KenaSpacing.lg),
            Text('Transferir anfitrión', style: KenaTypography.titleXL),
            const SizedBox(height: KenaSpacing.sm),
            Text('Elegí quién será el nuevo anfitrión para que la sala pueda continuar.', style: KenaTypography.bodySmall),
            const SizedBox(height: KenaSpacing.lg),
            for (final m in widget.members)
              Padding(
                padding: const EdgeInsets.only(bottom: KenaSpacing.xs),
                child: OptionCard(
                  title: m.name,
                  leading: Avatar.forName(m.name, size: 38),
                  trailing: Icon(
                    m.id == _selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: m.id == _selected ? KenaColors.accent : KenaColors.text3,
                  ),
                  color: m.id == _selected ? KenaColors.accentSoft : null,
                  onTap: () => setState(() => _selected = m.id),
                ),
              ),
            const SizedBox(height: KenaSpacing.lg),
            KenaGlassButton(
              onPressed: () => Navigator.of(context).pop(_selected),
              child: const Text('Transferir y salir'),
            ),
            const SizedBox(height: KenaSpacing.sm),
            KenaGhostButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
