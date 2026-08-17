import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/chat_client_connection.dart';
import '../../core/network/host_discovery_scanner.dart';
import '../../core/utils/app_permissions.dart';
import '../../core/utils/chat_history_store.dart';
import '../../core/utils/connection_code.dart';
import '../../core/utils/device_identity.dart';
import '../../core/utils/host_session_store.dart';
import '../../core/utils/participant_session_store.dart';
import '../../core/utils/pending_transfer_history.dart';
import '../../core/utils/profile_store.dart';
import '../../core/utils/room_history.dart';
import '../../theme/kena_colors.dart';
import '../../theme/kena_spacing.dart';
import '../../theme/kena_typography.dart';
import '../../widgets/avatar.dart';
import '../../widgets/kena_field.dart';
import '../../widgets/kena_glass_button.dart';
import '../../widgets/option_row.dart';
import '../../widgets/signal_bars.dart';
import '../../widgets/stagger_in.dart';
import '../../widgets/wifi_setup_guide.dart';
import '../room/domain/host_migration.dart';
import '../room/domain/notifying_room_session.dart';
import '../room/domain/room_session.dart';
import '../room/room_shell_screen.dart';
import 'qr_scanner_screen.dart';

/// Punto de entrada para sumarse a una sala existente. El usuario no ve
/// IP, puerto ni ningún concepto de red: sólo salas detectadas cerca, o
/// —a demanda, en una hoja aparte— un código para tipear o un QR para
/// escanear.
///
/// Antes las tres formas de unirse convivían siempre visibles en la
/// misma pantalla (lista cerca + divisor "O" + campo de código), lo que
/// hacía competir cinco decisiones a la vez por la atención (ver
/// auditoría de diseño, hallazgo #9). Ahora "cerca tuyo" es el foco
/// único; código/QR quedan a un toque de distancia, no menos
/// disponibles — sólo no compitiendo por defecto.
class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key, this.prefillCode});

  /// Si viene de "Recientes" en Inicio: intenta reconectar directo con
  /// este código, sin que el usuario tenga que volver a tipearlo. Sigue
  /// pasando por el mismo descubrimiento de siempre — si esa sala ya no
  /// está activa, se ve el mismo error que con cualquier código vencido.
  final String? prefillCode;

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _connection = ChatClientConnection();
  final _scanner = HostDiscoveryScanner();
  final _yourNameController = TextEditingController();
  final _codeController = TextEditingController();

  bool _scanning = false;
  bool _connecting = false;
  bool _waitingForApproval = false;
  bool _handedOff = false;
  String? _error;
  List<DiscoveredHost> _nearby = [];

  String get _yourName =>
      _yourNameController.text.trim().isEmpty ? 'Vos' : _yourNameController.text.trim();

  @override
  void initState() {
    super.initState();
    requestClientPermissions();
    ProfileStore.load().then((profile) {
      if (mounted && profile.name.isNotEmpty) {
        _yourNameController.text = profile.name;
      }
    });
    _scanNearby();
    if (widget.prefillCode != null) {
      _codeController.text = formatConnectionCode(normalizeConnectionCode(widget.prefillCode!));
      WidgetsBinding.instance.addPostFrameCallback((_) => _connectWithCode(widget.prefillCode!));
    }
  }

  @override
  void dispose() {
    if (!_handedOff) _connection.disconnect();
    _yourNameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _scanNearby() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final rooms = await _scanner.scan();
      if (!mounted) return;
      setState(() {
        _nearby = rooms;
        _scanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _scanning = false);
    }
  }

  /// Espera a que el anfitrión realmente admita a este dispositivo
  /// (llega el primer `roster`) antes de mostrar la sala — si la sala
  /// no exige aprobación (ver `ChatHostServer.requireApproval`) esto es
  /// casi instantáneo y no se nota; si la exige, es el tramo donde el
  /// anfitrión todavía no decidió. Devuelve `false` si el anfitrión
  /// rechazó el pedido (o algo cortó la espera) — en ese caso ya dejó
  /// todo listo para mostrar el error, no hace falta que quien llama
  /// haga nada más.
  Future<bool> _waitForAdmission(ParticipantRoomSession participantSession) async {
    // Recién si tarda más de lo que toma un ingreso normal asumimos que
    // es porque la sala pide aprobación — así no se ve "esperando
    // aprobación" ni por un instante en el caso común.
    final approvalTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _waitingForApproval = true);
    });

    final admitted = Completer<bool>();
    final memberSub = participantSession.membersStream.listen((_) {
      if (!admitted.isCompleted) admitted.complete(true);
    });
    final statusSub = participantSession.statusStream.listen((s) {
      if (s == ConnectionStatus.closedByHost && !admitted.isCompleted) admitted.complete(false);
    });

    bool ok;
    try {
      ok = await admitted.future.timeout(const Duration(minutes: 2), onTimeout: () => false);
    } finally {
      approvalTimer.cancel();
      await memberSub.cancel();
      await statusSub.cancel();
    }

    if (!mounted) return false;
    if (!ok) {
      setState(() {
        _connecting = false;
        _waitingForApproval = false;
        _error = participantSession.closeReason ?? 'No pudimos conectarnos. Probá de nuevo.';
      });
    }
    return ok;
  }

  Future<void> _connectTo(DiscoveredHost room) async {
    setState(() {
      _connecting = true;
      _waitingForApproval = false;
      _error = null;
    });
    try {
      // Persistido en disco (`DeviceIdentity`), no generado al vuelo: si
      // cambiara de una sesión a la siguiente (como pasaba antes, con un
      // id derivado de `identityHashCode(this)` — distinto cada vez que
      // se recrea esta pantalla), el historial restaurado dejaría de
      // reconocer como propios los mensajes de antes, mostrándolos
      // alineados como si fueran de otra persona.
      final senderId = await DeviceIdentity.get();

      // Ojo con el orden: `ParticipantRoomSession` tiene que suscribirse
      // a `_connection.messages` ANTES de que `connect()` abra el socket
      // — es un StreamController broadcast sin buffer, así que cualquier
      // roster/mensaje que llegue en el hueco entre "conectado" y
      // "alguien escuchando" se pierde para siempre (se ve en la lista
      // de miembros incompleta o en el primer mensaje "perdido"). Por
      // eso el `ParticipantRoomSession` se arma primero, todavía sin la
      // conexión abierta, y recién después se llama a `connect()`.
      final participantSession = ParticipantRoomSession(
        _connection,
        roomName: room.connectionName,
        mySenderId: senderId,
        myName: _yourName,
      );
      await _connection.connect(
        room.address,
        room.port,
        senderId: senderId,
        senderName: _yourName,
        code: room.code,
      );

      if (!await _waitForAdmission(participantSession)) return;

      await ProfileStore.save((await ProfileStore.load()).copyWith(name: _yourName));
      await RoomHistoryStore.record(RoomHistoryEntry(
        roomName: room.connectionName,
        code: room.code,
        wasHost: false,
        memberCount: 1,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      ));
      // Por si quedó un flag de "estoy siendo anfitrión" de una sala
      // anterior de este mismo dispositivo — unirse a mano a otra sala
      // como participante siempre gana sobre eso (ver
      // `host_session_resume.dart`).
      await HostSessionStore.clear();
      // Vive mientras siga en esta sala — permite reconectarse solo si
      // la app se cierra a la fuerza y se vuelve a abrir.
      await ParticipantSessionStore.save(ParticipantSessionSnapshot(
        code: room.code,
        yourName: _yourName,
      ));
      // Restaura el chat guardado localmente si es el mismo código de
      // sala — ver ChatHistoryStore. Si no hay nada (código nuevo para
      // este dispositivo), puede ser que estemos volviendo a una sala
      // que ESTE dispositivo transfirió hace poco (mismo nombre, código
      // distinto) — ver PendingTransferHistoryStore.
      var restoredHistory = await ChatHistoryStore.loadForCode(room.code);
      if (restoredHistory.isEmpty) {
        final carried = await PendingTransferHistoryStore.consumeIfMatches(room.connectionName);
        if (carried != null) restoredHistory = carried;
      }

      if (!mounted) return;
      _handedOff = true;
      // ResilientRoomSession: si el anfitrión desaparece sin avisar, este
      // dispositivo puede terminar continuando la sala solo (migración
      // automática de anfitrión) — ver HOST_MIGRATION.md. Transparente
      // para el resto de la UI: sigue siendo un RoomSession cualquiera.
      final session = NotifyingRoomSession(
        ResilientRoomSession(
          initial: participantSession,
          roomCode: room.code,
          yourName: _yourName,
        ),
        roomCode: room.code,
        restoredHistory: restoredHistory,
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => RoomShellScreen(session: session)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos conectarnos. Probá de nuevo.';
        _connecting = false;
      });
    }
  }

  Future<void> _connectWithCode(String rawCode) async {
    final code = normalizeConnectionCode(rawCode);
    if (code.isEmpty) {
      setState(() => _error = 'Ingresá un código válido.');
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final room = await _scanner.findByCode(code);
      if (room == null) {
        if (!mounted) return;
        setState(() {
          _connecting = false;
          _error = 'No encontramos ninguna sala con ese código cerca tuyo.';
        });
        return;
      }
      await _connectTo(room);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = 'No pudimos conectarnos. Probá de nuevo.';
      });
    }
  }

  Future<void> _scanQr() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (result == null || !mounted) return;
    _codeController.text = normalizeConnectionCode(result);
    await _connectWithCode(result);
  }

  void _showCodeSheet() {
    showModalBottomSheet<void>(
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
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(color: KenaColors.lineStrong, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text('Ingresar código', style: KenaTypography.title),
                const SizedBox(height: KenaSpacing.lg),
                KenaField(
                  label: 'Código de la sala',
                  controller: _codeController,
                  hint: 'Ej: KENA-482A',
                  textCapitalization: TextCapitalization.characters,
                  autofocus: true,
                  onSubmitted: (v) {
                    Navigator.of(sheetContext).pop();
                    _connectWithCode(v);
                  },
                ),
                KenaGlassButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _connectWithCode(_codeController.text);
                  },
                  child: const Text('Conectar con código'),
                ),
                const SizedBox(height: KenaSpacing.sm),
                KenaGhostButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _scanQr();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, size: 16),
                      const SizedBox(width: 8),
                      const Text('Escanear QR'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _connecting;

    return KenaBackground(
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Unirme a una sala')),
        body: AbsorbPointer(
          absorbing: busy,
          child: Opacity(
            opacity: busy ? 0.55 : 1,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                if (_connecting) ...[
                  Center(
                    child: Column(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: KenaColors.accent),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _waitingForApproval ? 'Esperando que el anfitrión te deje entrar…' : 'Conectando…',
                          textAlign: TextAlign.center,
                          style: KenaTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                KenaField(
                  label: 'Tu nombre',
                  controller: _yourNameController,
                  hint: 'Como te van a ver los demás',
                  textCapitalization: TextCapitalization.words,
                ),
                if (_error != null && !_connecting) ...[
                  Row(
                    children: [
                      Icon(Icons.error_outline_rounded, size: 13, color: KenaColors.red),
                      const SizedBox(width: 6),
                      Expanded(child: Text(_error!, style: KenaTypography.bodySmall.copyWith(color: KenaColors.red))),
                    ],
                  ),
                  const SizedBox(height: KenaSpacing.md),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text('CERCA TUYO', style: KenaTypography.label),
                    ),
                    IconButton(
                      onPressed: _scanning ? null : _scanNearby,
                      icon: _scanning
                          ? SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2, color: KenaColors.accent),
                            )
                          : Icon(Icons.refresh_rounded, color: KenaColors.text2, size: 18),
                    ),
                  ],
                ),
                if (_nearby.isEmpty && !_scanning) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No encontramos ninguna sala cerca.', style: KenaTypography.bodySmall),
                  ),
                  const WifiSetupGuide(role: WifiSetupRole.client),
                  const SizedBox(height: 12),
                ],
                for (var i = 0; i < _nearby.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: KenaSpacing.sm),
                    child: StaggerIn(
                      index: i,
                      child: OptionCard(
                        leading: Avatar.forName(_nearby[i].connectionName, size: 38),
                        title: _nearby[i].connectionName,
                        subtitle: formatConnectionCode(_nearby[i].code),
                        trailing: const SignalBars(strength: 4),
                        onTap: () => _connectTo(_nearby[i]),
                      ),
                    ),
                  ),
                const SizedBox(height: KenaSpacing.sm),
                OptionCard(
                  icon: Icons.qr_code_rounded,
                  title: '¿Tenés un código?',
                  subtitle: 'Ingresarlo a mano o escanear un QR',
                  onTap: _showCodeSheet,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
