import 'dart:async';
import 'dart:math';

import '../../../core/network/chat_client_connection.dart';
import '../../../core/network/chat_host_server.dart';
import '../../../core/network/host_discovery_responder.dart';
import '../../../core/network/host_discovery_scanner.dart';
import '../../../core/protocol/chat_message.dart';
import '../../../core/utils/host_session_store.dart';
import '../../../core/utils/network_readiness.dart';
import '../../../core/utils/participant_session_store.dart';
import 'room_session.dart';

/// El participante no-anfitrión con el `joinOrder` más chico (el que
/// lleva más tiempo en la sala) de la última lista de miembros
/// conocida — es quien intenta continuar la sala si el anfitrión
/// desaparece. Determinística a propósito: cualquier dispositivo que
/// haya visto el mismo roster llega solo a la misma conclusión, sin
/// coordinarse con nadie (ver HOST_MIGRATION.md).
RoomMember? electStandby(List<RoomMember> roster) {
  RoomMember? standby;
  for (final m in roster) {
    if (m.isHost) continue;
    if (standby == null || m.joinOrder < standby.joinOrder) standby = m;
  }
  return standby;
}

/// Envuelve una [ParticipantRoomSession] y, si el anfitrión desaparece
/// sin avisar (no [ConnectionStatus.closedByHost] — eso es un cierre
/// explícito, no una migración), intenta que la sala siga viva sola:
///
/// 1. Espera un momento por si es sólo un corte breve que la propia
///    [ChatClientConnection] resuelve reconectando.
/// 2. Si sigue caída y este dispositivo es el sucesor elegido
///    ([electStandby]), escucha primero (para no pisar a alguien que ya
///    haya arrancado) y, si nadie responde, levanta su propia
///    [ChatHostServer] con el mismo nombre y **el mismo código** — así
///    el resto de los dispositivos (que ya están buscando ese código
///    solos, ver `ChatClientConnection._searchByCode`) se reconectan sin
///    que nadie tenga que escanear ni tipear nada de nuevo.
/// 3. Si no es el sucesor (o alguien se le adelantó), no hace nada
///    especial: la búsqueda por código de su propia conexión ya se
///    encarga de encontrar la sala continuada.
///
/// El usuario no ve ninguna pantalla nueva durante esto — mismo
/// `RoomShellScreen`, mismo historial de esta sesión, sólo la franja
/// global de conexión pasando por "Reconectando…" y después
/// "Conexión restablecida".
class ResilientRoomSession implements RoomSession {
  ResilientRoomSession({
    required ParticipantRoomSession initial,
    required this.roomCode,
    required this.yourName,
  }) {
    _attach(initial);
  }

  /// El código de sala original (`KENA-XXXX`) — no es lo mismo que
  /// [code] (el getter de [RoomSession], que sólo un anfitrión expone
  /// para compartir/invitar): esto es lo que se usa puertas adentro
  /// para reencontrar la sala si hay que migrar.
  final String roomCode;
  final String yourName;

  late RoomSession _current;

  final _log = <ChatMessage>[];
  final _messagesCtrl = StreamController<ChatMessage>.broadcast();
  final _membersCtrl = StreamController<List<RoomMember>>.broadcast();
  final _statusCtrl = StreamController<ConnectionStatus>.broadcast();
  final _healthyCtrl = StreamController<bool>.broadcast();
  final _typingCtrl = StreamController<ChatMessage>.broadcast();
  final _promotedCtrl = StreamController<String>.broadcast();
  final _becameHostAutoCtrl = StreamController<void>.broadcast();

  StreamSubscription<ChatMessage>? _msgSub;
  StreamSubscription<List<RoomMember>>? _memberSub;
  StreamSubscription<ConnectionStatus>? _statusSub;
  StreamSubscription<bool>? _healthySub;
  StreamSubscription<ChatMessage>? _typingSub;
  StreamSubscription<String>? _promotedSub;

  List<RoomMember> _lastRoster = const [];
  bool _attemptingMigration = false;
  bool _becameHost = false;
  Timer? _electionDelay;
  ChatHostServer? _ownServer;
  HostDiscoveryResponder? _ownResponder;

  /// `true` si ya hay una red local utilizable en este dispositivo. No
  /// lanza — cualquier falla es "no, no se pudo" en vez de una excepción,
  /// porque el llamador siempre tiene un camino de vuelta razonable
  /// (seguir participando normalmente). Kena no puede crear una red por
  /// su cuenta (ver ARCHITECTURE.md) — si la red del grupo dependía del
  /// propio anfitrión que desapareció (su Zona Wi-Fi personal) y este
  /// dispositivo tampoco tiene ninguna, la migración no puede completarse
  /// sola; ver la limitación ya documentada en HOST_MIGRATION.md.
  Future<bool> _hasNetworkOrCreateOne() async {
    try {
      return await hasUsableLocalNetwork();
    } catch (_) {
      return true; // no se pudo verificar: no bloquear por una comprobación rota.
    }
  }

  void _attach(RoomSession session) {
    _msgSub?.cancel();
    _memberSub?.cancel();
    _statusSub?.cancel();
    _healthySub?.cancel();
    _typingSub?.cancel();
    _promotedSub?.cancel();

    _current = session;
    _log.addAll(session.messageLog);
    if (session.members.isNotEmpty) _lastRoster = session.members;

    _msgSub = session.messages.listen((m) {
      _log.add(m);
      _messagesCtrl.add(m);
    });
    _memberSub = session.membersStream.listen((members) {
      _lastRoster = members;
      _membersCtrl.add(members);
    });
    _statusSub = session.statusStream.listen(_onStatus);
    _healthySub = session.linkHealthy.listen((h) => _healthyCtrl.add(h));
    _typingSub = session.typingEvents.listen((t) => _typingCtrl.add(t));
    // La transferencia MANUAL (ver ARCHITECTURE.md) sigue existiendo
    // además de la migración automática — hay que reenviar este aviso
    // o RoomShellScreen nunca se entera de que lo eligieron.
    _promotedSub = session.promotedToHostStream.listen(_promotedCtrl.add);
  }

  void _onStatus(ConnectionStatus status) {
    _statusCtrl.add(status);
    _electionDelay?.cancel();
    if (status != ConnectionStatus.reconnecting || _becameHost) return;
    // Le da un respiro a la reconexión directa (el caso más común: un
    // microcorte que se resuelve solo) antes de siquiera considerar
    // tomar la posta.
    _electionDelay = Timer(const Duration(seconds: 3), _maybeStartMigration);
  }

  Future<void> _maybeStartMigration() async {
    if (_becameHost || _attemptingMigration) return;
    if (_current.currentStatus != ConnectionStatus.reconnecting) return;

    final standby = electStandby(_lastRoster);
    if (standby == null || standby.id != _current.mySenderId) return;

    _attemptingMigration = true;
    try {
      // "Escuchá antes de hablar": jitter corto + un scan propio para no
      // pisar a otro dispositivo si el roster que veíamos estaba
      // levemente desactualizado, o si el anfitrión en realidad sigue
      // vivo y sólo se cortó este socket puntual.
      await Future.delayed(Duration(milliseconds: 250 + Random().nextInt(500)));
      if (_becameHost || _current.currentStatus != ConnectionStatus.reconnecting) return;

      final stillThere = await HostDiscoveryScanner().findByCode(roomCode, timeout: const Duration(seconds: 2));
      if (stillThere != null) return; // el anfitrión (u otro sucesor) ya está.
      if (_becameHost || _current.currentStatus != ConnectionStatus.reconnecting) return;

      await _becomeHost();
    } finally {
      _attemptingMigration = false;
    }
  }

  Future<void> _becomeHost() async {
    // Si la red que compartía el grupo dependía del propio anfitrión que
    // desapareció (su punto de acceso personal, típico en el caso
    // "avión"/"camping" sin infraestructura previa), esa red se fue con
    // él — no hay forma de que siga viva sola. Antes de resignarse,
    // intenta crear una nueva acá mismo (ver ARCHITECTURE.md). Si el
    // grupo en cambio estaba sobre una red independiente (un router), esto
    // ni hace falta: `hasUsableLocalNetwork()` ya da `true`.
    if (!await _hasNetworkOrCreateOne()) return;

    final server = ChatHostServer();
    final responder = HostDiscoveryResponder();
    try {
      await server.start(roomName: _current.roomName, hostDisplayName: yourName, code: roomCode);
      try {
        await responder.start(connectionName: _current.roomName, code: roomCode, chatPort: ChatHostServer.defaultPort);
      } catch (_) {
        // El descubrimiento es un extra — el resto ya está buscando este
        // código solo; si esto falla no hay forma de invitar a nadie
        // nuevo, pero quienes ya estaban se van a encontrar igual en
        // cuanto reintenten (mismo puerto fijo, misma IP de este equipo).
      }
    } catch (_) {
      // No se pudo levantar el servidor acá (puerto ocupado, etc.) —
      // seguimos como participante normal, buscando por código como
      // cualquier otro dispositivo.
      await server.stop();
      responder.stop();
      return;
    }

    _becameHost = true;
    final previous = _current;
    if (previous is ParticipantRoomSession) previous.cancelReconnect();
    _ownServer = server;
    _ownResponder = responder;
    _attach(HostRoomSession(server));
    previous.dispose();
    // Este dispositivo pasa a ser el que puede (y debe) recuperar la
    // sala solo si a él también lo matan más adelante — mismo mecanismo
    // que al crear una sala desde cero, ver `host_session_resume.dart`.
    // Puramente best-effort: nunca debe interrumpir una migración que ya
    // está en marcha (p.ej. en tests sin el binding de Flutter
    // inicializado, `SharedPreferences` no tiene con qué hablar).
    unawaited(
      HostSessionStore.save(HostSessionSnapshot(
        code: roomCode,
        roomName: _current.roomName,
        hostDisplayName: yourName,
      )).catchError((_) {}),
    );
    unawaited(ParticipantSessionStore.clear().catchError((_) {}));
    // Antes del cambio de estado: `ConnectionBanner` necesita saber que
    // el "restablecida" que está por venir es en realidad un ascenso a
    // anfitrión, para mostrar ese texto en vez del genérico.
    _becameHostAutoCtrl.add(null);
    // El estado ya venía en `reconnecting`: emitir `connected` acá hace
    // que la franja global lo lea como "restablecida" (ver
    // ConnectionPhaseTracker) — exactamente lo que corresponde, sin
    // agregar un estado nuevo sólo para esto.
    _statusCtrl.add(ConnectionStatus.connected);
  }

  @override
  String get roomName => _current.roomName;
  @override
  String? get code => _current.code;
  @override
  bool get isHost => _current.isHost;
  @override
  String get mySenderId => _current.mySenderId;
  @override
  String get myName => _current.myName;
  @override
  List<ChatMessage> get messageLog => List.unmodifiable(_log);
  @override
  Stream<ChatMessage> get messages => _messagesCtrl.stream;
  @override
  List<RoomMember> get members => _current.members;
  @override
  Stream<List<RoomMember>> get membersStream => _membersCtrl.stream;
  @override
  ConnectionStatus get currentStatus => _current.currentStatus;
  @override
  Stream<ConnectionStatus> get statusStream => _statusCtrl.stream;
  @override
  Stream<bool> get linkHealthy => _healthyCtrl.stream;
  @override
  String? get closeReason => _current.closeReason;
  @override
  Stream<String> get promotedToHostStream => _promotedCtrl.stream;
  @override
  Stream<void> get becameHostAutomaticallyStream => _becameHostAutoCtrl.stream;

  @override
  void sendGeneral(String text) => _current.sendGeneral(text);
  @override
  void sendPrivate(String text, {required String toMemberId}) => _current.sendPrivate(text, toMemberId: toMemberId);
  @override
  void editMessage(String messageId, String newText, {String? toMemberId}) =>
      _current.editMessage(messageId, newText, toMemberId: toMemberId);
  @override
  void deleteMessageForEveryone(String messageId, {String? toMemberId}) =>
      _current.deleteMessageForEveryone(messageId, toMemberId: toMemberId);
  @override
  void hideMessageLocally(String messageId) {}
  @override
  void sendReceipt(MessageType type, {required String targetMessageId, required String toMemberId}) =>
      _current.sendReceipt(type, targetMessageId: targetMessageId, toMemberId: toMemberId);
  @override
  Stream<ChatMessage> get typingEvents => _typingCtrl.stream;
  @override
  void sendTyping(bool isTyping, {String? toMemberId}) => _current.sendTyping(isTyping, toMemberId: toMemberId);

  @override
  Future<void> leaveRoom() async {
    _electionDelay?.cancel();
    await _current.leaveRoom();
    await _ownServer?.stop();
    _ownResponder?.stop();
  }

  @override
  Future<void> finishRoom() => _current.finishRoom();
  @override
  Future<void> transferHostTo(RoomMember member) => _current.transferHostTo(member);

  @override
  void setActiveThread(String? peerId) => _current.setActiveThread(peerId);
  @override
  void clearActiveThread() => _current.clearActiveThread();
  @override
  Map<String?, int> get unreadCounts => _current.unreadCounts;
  @override
  Stream<Map<String?, int>> get unreadStream => _current.unreadStream;
  @override
  bool get isMuted => _current.isMuted;
  @override
  void setMuted(bool muted) => _current.setMuted(muted);

  @override
  List<PendingJoinRequest> get pendingJoinRequests => _current.pendingJoinRequests;
  @override
  Stream<List<PendingJoinRequest>> get joinRequestsStream => _current.joinRequestsStream;
  @override
  void acceptJoinRequest(String connKey) => _current.acceptJoinRequest(connKey);
  @override
  void rejectJoinRequest(String connKey) => _current.rejectJoinRequest(connKey);

  @override
  void dispose() {
    _electionDelay?.cancel();
    _msgSub?.cancel();
    _memberSub?.cancel();
    _statusSub?.cancel();
    _healthySub?.cancel();
    _typingSub?.cancel();
    _promotedSub?.cancel();
    _messagesCtrl.close();
    _membersCtrl.close();
    _statusCtrl.close();
    _healthyCtrl.close();
    _typingCtrl.close();
    _promotedCtrl.close();
    _becameHostAutoCtrl.close();
    _current.dispose();
    _ownServer?.stop();
    _ownResponder?.stop();
  }
}
