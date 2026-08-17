import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/protocol/chat_message.dart';
import '../../core/utils/avatar.dart';
import '../../theme/kena_colors.dart';
import '../../theme/kena_spacing.dart';
import '../../theme/kena_typography.dart';
import '../../widgets/avatar.dart';
import '../../widgets/connection_phase_style.dart';
import '../../widgets/kena_glass_button.dart';
import 'domain/connection_phase.dart';
import 'domain/room_session.dart';

String _formatTime(int timestampMs) {
  final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _statusLabel(ConnectionPhase phase) {
  switch (phase) {
    case ConnectionPhase.connected:
      return 'Sala activa';
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

/// Un hilo de chat dentro de una sala: el chat General (todos lo ven) o
/// una conversación privada con un participante puntual — es la misma
/// UI de burbujas para los dos casos, sólo cambia qué mensajes del log
/// de la sesión se muestran y a quién van dirigidos los que se manden.
///
/// [peerId] en `null` significa General; con valor, es el `id` del otro
/// participante de la conversación privada.
class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({super.key, required this.session, this.peerId});

  final RoomSession session;
  final String? peerId;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

/// Cuánto esperar sin tipear antes de avisar "dejó de escribir" (lado de
/// quien escribe) y cuánto tiempo tolerar sin refresco antes de limpiar
/// solos a alguien que quedó marcado como escribiendo (lado de quien
/// mira, por si se pierde el aviso de "dejó de escribir" — ver sección
/// 19 del brief: nunca debe quedar visible para siempre).
const _typingSendIdle = Duration(seconds: 3);
const _typingReceiveTimeout = Duration(seconds: 6);

String? _describeTypers(List<String> names) {
  if (names.isEmpty) return null;
  if (names.length == 1) return '${names.first} está escribiendo…';
  if (names.length == 2) return '${names[0]} y ${names[1]} están escribiendo…';
  return '${names.length} personas están escribiendo…';
}

class _ChatThreadScreenState extends State<ChatThreadScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _log = <ChatMessage>[];
  late final Stream<ChatMessage> _threadMessages;
  late final ConnectionPhaseTracker _phaseTracker;
  ConnectionPhase _phase = ConnectionPhase.connected;

  // Cuánto hay que estar lejos del final para dejar de considerarse
  // "cerca" — un margen chico, no hace falta estar exactamente al pie.
  static const _nearBottomThreshold = 120.0;
  bool _nearBottom = true;
  int _newMessagesBelow = 0;

  // Lado de quien mira: id -> nombre de quien está escribiendo ahora en
  // este hilo, con un timeout de seguridad por si se pierde el evento
  // de "dejó de escribir" (corte de red, app en background, etc.).
  final _typingPeers = <String, String>{};
  final _typingTimeouts = <String, Timer>{};

  // Lado de quien escribe: sólo mandar el aviso al empezar (no en cada
  // tecla) y un timer de inactividad para avisar que se dejó de escribir.
  bool _iAmTyping = false;
  Timer? _typingIdleTimer;

  bool get _isGeneral => widget.peerId == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.session.setActiveThread(widget.peerId);
    _phaseTracker = ConnectionPhaseTracker(widget.session);
    _phase = _phaseTracker.current;
    _log.addAll(widget.session.messageLog.where(_matchesThread));
    // Abre directo mostrando lo último, no la primera burbuja del
    // historial — sin esto, un hilo con muchos mensajes arrancaba
    // mostrando el principio, "estático", como si nada nuevo hubiera
    // llegado.
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    _threadMessages = widget.session.messages.where(_matchesThread);
    _threadMessages.listen((m) {
      if (!mounted) return;
      // Acuse de entrega/lectura: igual que en `NotifyingRoomSession`,
      // muta el `deliveryStatus` del mensaje propio referenciado en vez
      // de agregar una fila — esta copia local (`_log`) necesita la
      // misma mutación para que la burbuja ya dibujada cambie de tilde
      // sin tener que volver a entrar al hilo.
      if ((m.type == MessageType.delivered || m.type == MessageType.read) && m.targetId != null) {
        final idx = _log.indexWhere((e) => e.id == m.targetId);
        if (idx == -1) return;
        final next = m.type == MessageType.read ? MessageDeliveryStatus.read : MessageDeliveryStatus.delivered;
        if (deliveryStatusRank(next) <= deliveryStatusRank(_log[idx].deliveryStatus)) return;
        setState(() => _log[idx].deliveryStatus = next);
        return;
      }
      // Edición/borrado: mutan la fila del mensaje original en vez de
      // agregar una fila nueva — ver `NotifyingRoomSession._handleMessage`,
      // que hace lo mismo sobre el log persistido. Esta copia local
      // (`_log`) tiene que aplicar la misma mutación para que la pantalla
      // ya abierta se actualice sin tener que volver a entrar al hilo.
      if (m.type == MessageType.edited && m.targetId != null) {
        setState(() {
          final idx = _log.indexWhere((e) => e.id == m.targetId);
          if (idx != -1) {
            _log[idx].text = m.text;
            _log[idx].edited = true;
          }
        });
        return;
      }
      if (m.type == MessageType.deletedForEveryone && m.targetId != null) {
        setState(() => _log.removeWhere((e) => e.id == m.targetId));
        return;
      }

      // Un mensaje reintentado tras reconectar (ver
      // ChatClientConnection._flushOutbox) es el MISMO objeto que ya
      // está en `_log`, sólo con `deliveryStatus` actualizado — no hay
      // que duplicarlo, sólo redibujar su burbuja.
      final isNew = !_log.contains(m);
      // Propio: siempre baja solo (lo acabás de mandar). Ajeno: sólo si
      // ya estabas cerca del final — si estabas leyendo algo más arriba,
      // forzar el scroll te sacaría de donde estabas mirando; en vez de
      // eso, se acumula en el aviso "N mensajes nuevos ↓" (ver
      // `_NewMessagesPill`).
      final isMine = m.senderId == widget.session.mySenderId;
      final shouldAutoScroll = isNew && (isMine || _nearBottom);
      setState(() {
        if (isNew) _log.add(m);
        if (shouldAutoScroll) {
          _newMessagesBelow = 0;
        } else if (isNew && m.type == MessageType.message) {
          _newMessagesBelow++;
        }
      });
      if (shouldAutoScroll) _scrollToBottomNextFrame();
    });
    _phaseTracker.stream.listen((p) {
      if (!mounted) return;
      setState(() => _phase = p);
    });
    widget.session.typingEvents.where(_matchesTypingThread).listen(_handleTypingEvent);
    _controller.addListener(_handleTextChanged);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final distanceFromBottom = position.maxScrollExtent - position.pixels;
    final nearBottom = distanceFromBottom < _nearBottomThreshold;
    if (nearBottom == _nearBottom) return;
    setState(() {
      _nearBottom = nearBottom;
      if (nearBottom) _newMessagesBelow = 0;
    });
  }

  void _jumpToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  void _scrollToBottomNextFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  // Sin esto, "estar mirando este hilo" (`setActiveThread`) seguía activo
  // aunque la app pasara a segundo plano con la pantalla del chat todavía
  // montada (minimizar no dispara `dispose()`) — como
  // `NotifyingRoomSession` no distingue "en pantalla" de "en foreground",
  // un mensaje nuevo se trataba como "ya lo estás mirando" y sólo sonaba
  // el tick corto en vez de la notificación real (bug reportado: con el
  // chat abierto y la app minimizada, no llegaba ninguna notificación).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        widget.session.setActiveThread(widget.peerId);
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        widget.session.clearActiveThread();
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void dispose() {
    if (_iAmTyping) _sendTyping(false);
    _typingIdleTimer?.cancel();
    for (final t in _typingTimeouts.values) {
      t.cancel();
    }
    _phaseTracker.dispose();
    WidgetsBinding.instance.removeObserver(this);
    widget.session.clearActiveThread();
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  bool _matchesThread(ChatMessage m) {
    // Un acuse de entrega/lectura no tiene la misma forma que el mensaje
    // que referencia (siempre va dirigido puntualmente a su autor,
    // aunque el mensaje original haya sido General — ver el protocolo en
    // chat_message.dart), así que no se puede clasificar con las mismas
    // reglas de abajo. En cambio, pertenece a este hilo si el mensaje
    // que referencia (`targetId`) ya está en la copia local del hilo.
    if (m.type == MessageType.delivered || m.type == MessageType.read) {
      return m.targetId != null && _log.any((e) => e.id == m.targetId);
    }
    if (_isGeneral) {
      return isGeneralMessage(m);
    }
    return isPrivateMessageBetween(m, widget.session.mySenderId, widget.peerId!);
  }

  /// El anfitrión/servidor nunca hace eco de un aviso de "escribiendo"
  /// hacia quien lo mandó, así que sólo hace falta matchear la
  /// dirección: General (`recipientId == null`) o un privado dirigido a
  /// mí desde exactamente este `peerId`.
  bool _matchesTypingThread(ChatMessage m) {
    if (_isGeneral) return m.recipientId == null;
    return m.recipientId == widget.session.mySenderId && m.senderId == widget.peerId;
  }

  void _handleTypingEvent(ChatMessage m) {
    if (!mounted) return;
    _typingTimeouts.remove(m.senderId)?.cancel();
    final isTyping = m.text == '1';
    setState(() {
      if (isTyping) {
        _typingPeers[m.senderId] = m.senderName;
        _typingTimeouts[m.senderId] = Timer(_typingReceiveTimeout, () {
          if (!mounted) return;
          setState(() => _typingPeers.remove(m.senderId));
        });
      } else {
        _typingPeers.remove(m.senderId);
      }
    });
  }

  void _handleTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText && !_iAmTyping) {
      _sendTyping(true);
    } else if (!hasText && _iAmTyping) {
      _sendTyping(false);
    }
    _typingIdleTimer?.cancel();
    if (hasText) {
      _typingIdleTimer = Timer(_typingSendIdle, () => _sendTyping(false));
    }
  }

  void _sendTyping(bool isTyping) {
    _iAmTyping = isTyping;
    widget.session.sendTyping(isTyping, toMemberId: widget.peerId);
  }

  /// Hoja "Adjuntar" — sólo UI: compartir archivos no forma parte del
  /// protocolo de chat todavía (ver ROADMAP.md), así que las dos
  /// opciones están deshabilitadas y marcadas "Próximamente" en vez de
  /// simular un envío que no va a pasar a ningún lado.
  void _showAttachSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Adjuntar', style: KenaTypography.body.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: _AttachOption(icon: Icons.image_rounded, label: 'Foto')),
                SizedBox(width: 12),
                Expanded(child: _AttachOption(icon: Icons.location_on_rounded, label: 'Ubicación')),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Todavía no se pueden compartir archivos ni ubicación — llega más adelante.',
              style: KenaTypography.caption.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (_isGeneral) {
      widget.session.sendGeneral(text);
    } else {
      widget.session.sendPrivate(text, toMemberId: widget.peerId!);
    }
    _controller.clear();
    _typingIdleTimer?.cancel();
    if (_iAmTyping) _sendTyping(false);
  }

  /// Hoja de acciones sobre un mensaje propio (long-press) — editarlo,
  /// ocultarlo sólo acá, o borrarlo para todos los que ya lo vieron.
  void _showMessageActions(ChatMessage m) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit_rounded, color: KenaColors.text2),
              title: const Text('Editar'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _startEdit(m);
              },
            ),
            ListTile(
              leading: Icon(Icons.visibility_off_rounded, color: KenaColors.text2),
              title: const Text('Borrar para mí'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _deleteForMe(m);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_forever_rounded, color: KenaColors.red),
              title: const Text('Borrar para todos'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _deleteForEveryone(m);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startEdit(ChatMessage m) async {
    final editController = TextEditingController(text: m.text ?? '');
    final newText = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditMessageSheet(controller: editController),
    );
    editController.dispose();
    if (newText == null || newText.isEmpty || newText == m.text) return;
    widget.session.editMessage(m.id, newText, toMemberId: widget.peerId);
  }

  /// Sólo en este dispositivo — nunca sale a la red (ver
  /// `RoomSession.hideMessageLocally`). Se saca también de la copia
  /// local (`_log`) en el mismo gesto: no hace falta esperar ningún
  /// evento de vuelta, es una acción puramente local.
  void _deleteForMe(ChatMessage m) {
    widget.session.hideMessageLocally(m.id);
    setState(() => _log.remove(m));
  }

  void _deleteForEveryone(ChatMessage m) {
    widget.session.deleteMessageForEveryone(m.id, toMemberId: widget.peerId);
  }

  /// Copia de los mensajes de sistema. `join`/`leave` distinguen la
  /// primera vez que alguien se suma de una reconexión: si ya había un
  /// `leave` anterior del mismo `senderId` en este hilo, un nuevo `join`
  /// se lee como "volvió a conectarse" en vez de "se unió". Todo deriva
  /// del log de eventos que ya emite la sesión — no hay estado de red
  /// nuevo ni copy que implique conectividad remota.
  String _describeSystemEvent(ChatMessage m, int index) {
    switch (m.type) {
      case MessageType.join:
        final hadLeftBefore =
            _log.take(index).any((e) => e.type == MessageType.leave && e.senderId == m.senderId);
        return hadLeftBefore ? '${m.senderName} volvió a conectarse' : '${m.senderName} se unió';
      case MessageType.leave:
        return 'Se perdió la conexión con ${m.senderName}';
      case MessageType.presence:
        return '${m.senderName} sigue conectado';
      case MessageType.message:
      case MessageType.roster:
      case MessageType.roomClosed:
      case MessageType.hostTransferOffer:
      case MessageType.typing:
        return m.text ?? '';
      case MessageType.edited:
      case MessageType.deletedForEveryone:
      case MessageType.delivered:
      case MessageType.read:
        // Nunca deberían llegar hasta acá como fila propia — se
        // interceptan en el listener de `_threadMessages` y mutan la
        // fila del mensaje original en vez de agregar una nueva (ver
        // más arriba en `initState`). Caso defensivo, no un flujo real.
        return '';
    }
  }

  Widget _buildRow(BuildContext context, ChatMessage m, int index) {
    if (m.type != MessageType.message) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: KenaColors.card2, borderRadius: BorderRadius.circular(12)),
            child: Text(
              _describeSystemEvent(m, index),
              style: KenaTypography.bodySmall,
            ),
          ),
        ),
      );
    }

    final isMine = m.senderId == widget.session.mySenderId;
    final timeColor = isMine ? KenaColors.onAccent.withValues(alpha: 0.75) : KenaColors.text3;
    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMine ? 16 : 4),
      bottomRight: Radius.circular(isMine ? 4 : 16),
    );

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
      decoration: BoxDecoration(
        color: isMine ? null : KenaColors.card2,
        gradient: isMine ? KenaColors.brandGradient : null,
        borderRadius: bubbleRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMine && _isGeneral)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                m.senderName,
                style: KenaTypography.bodySmall.copyWith(fontWeight: FontWeight.w600, color: avatarColorFor(m.senderName)),
              ),
            ),
          Text(
            m.text ?? '',
            style: KenaTypography.bodyLarge.copyWith(color: isMine ? KenaColors.onAccent : KenaColors.text),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (m.edited) ...[
                Text('editado', style: KenaTypography.caption.copyWith(color: timeColor, fontStyle: FontStyle.italic)),
                const SizedBox(width: 4),
              ],
              Text(_formatTime(m.timestamp), style: KenaTypography.caption.copyWith(color: timeColor)),
              if (isMine) ...[
                const SizedBox(width: 3),
                _DeliveryIcon(status: m.deliveryStatus, color: timeColor, readColor: KenaColors.onAccent),
              ],
            ],
          ),
        ],
      ),
    );

    if (isMine) {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          child: GestureDetector(
            onLongPress: () => _showMessageActions(m),
            child: bubble,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Avatar.forName(m.senderName, size: 28),
          const SizedBox(width: 6),
          Flexible(child: bubble),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isGeneral
        ? widget.session.roomName
        : widget.session.members.where((m) => m.id == widget.peerId).map((m) => m.name).firstOrNull ??
            'Participante';
    final subtitleText = _isGeneral ? _statusLabel(_phase) : 'Conversación privada';
    final subtitleDot = _isGeneral ? connectionPhaseColor(_phase) : KenaColors.green;

    return KenaBackground(
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(title),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(20),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: subtitleDot),
                  ),
                  const SizedBox(width: 6),
                  Text(subtitleText, style: KenaTypography.bodySmall),
                ],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _log.length,
                    itemBuilder: (context, index) {
                      final m = _log[index];
                      // Key por id: ListView reusa el Element de una fila
                      // ya animada en vez de reconstruirla desde cero, así
                      // que un mensaje que ya apareció no vuelve a
                      // "saltar" cada vez que la pantalla se redibuja por
                      // otra razón (p.ej. el indicador de "escribiendo").
                      return _MessageIn(key: ValueKey(m.id), child: _buildRow(context, m, index));
                    },
                  ),
                  if (_newMessagesBelow > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 10,
                      child: _NewMessagesPill(
                        count: _newMessagesBelow,
                        onTap: () {
                          setState(() => _newMessagesBelow = 0);
                          _scrollToBottomNextFrame();
                        },
                      ),
                    ),
                ],
              ),
            ),
            _TypingIndicator(text: _describeTypers(_typingPeers.values.toList())),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Adjuntar',
                      onPressed: () => _showAttachSheet(context),
                      icon: Icon(Icons.attach_file_rounded, color: KenaColors.text3, size: 20),
                    ),
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: KenaColors.card2,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: KenaColors.line),
                        ),
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 5,
                          style: TextStyle(color: KenaColors.text),
                          decoration: InputDecoration(
                            hintText: 'Mensaje',
                            hintStyle: TextStyle(color: KenaColors.text3),
                            border: InputBorder.none,
                            // filled:false — sin esto el TextField pinta su
                            // propio fondo (heredado del InputDecorationTheme
                            // global) por encima del Container que ya lo
                            // envuelve, y se ven dos cajas superpuestas.
                            filled: false,
                            isCollapsed: true,
                          ),
                          onSubmitted: (_) => _handleSend(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SendButton(onTap: _handleSend),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Entrada suave para una fila del historial — se anima una sola vez,
/// la primera vez que esa fila se construye (el `ListView.builder` la
/// referencia por el id del mensaje, ver más arriba, así que no vuelve
/// a dispararse en reconstrucciones posteriores de la misma fila).
class _MessageIn extends StatelessWidget {
  const _MessageIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, (1 - value) * 8), child: child),
      ),
      child: child,
    );
  }
}

/// Un tilde (enviado), dos tildes (entregado — al menos un destinatario
/// lo recibió), dos tildes de otro color (leído — al menos un
/// destinatario lo tuvo abierto en pantalla). Ver el protocolo de
/// acuses en chat_message.dart — `readColor` es siempre un color de más
/// contraste que `color` (mismo tono, sin atenuar) para que el cambio
/// se note sin depender de un tinte nuevo que pudiera no funcionar en
/// los 4 temas.
class _DeliveryIcon extends StatelessWidget {
  const _DeliveryIcon({required this.status, required this.color, required this.readColor});

  final MessageDeliveryStatus? status;
  final Color color;
  final Color readColor;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageDeliveryStatus.sending:
        return SizedBox(
          width: 11,
          height: 11,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
        );
      case MessageDeliveryStatus.failed:
        return Icon(Icons.error_outline_rounded, size: 14, color: KenaColors.red);
      case MessageDeliveryStatus.sent:
      case null:
        return Icon(Icons.done_rounded, size: 14, color: color);
      case MessageDeliveryStatus.delivered:
        return Icon(Icons.done_all_rounded, size: 14, color: color);
      case MessageDeliveryStatus.read:
        return Icon(Icons.done_all_rounded, size: 14, color: readColor);
    }
  }
}

/// El círculo de enviar: junto con [KenaGlassButton], una de las dos
/// únicas excepciones al "sin blur en listas" — acá marca la acción
/// principal de la pantalla de chat.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [KenaColors.gradA.withValues(alpha: 0.32), KenaColors.gradB.withValues(alpha: 0.32)],
            ),
            // Border.all: un Border por lado con colores distintos no se
            // puede pintar sobre BoxShape.circle (Flutter lo prohíbe).
            // Con alfa bajo (vidrio translúcido) un blanco fijo se pierde
            // sobre fondo claro — el borde y el ícono usan `accent` (ya
            // ajustado por tema para dar contraste) en vez de blanco fijo.
            border: Border.all(color: KenaColors.accent.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(color: KenaColors.accent.withValues(alpha: 0.16), blurRadius: 18, offset: const Offset(0, 6)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: Icon(Icons.send_rounded, color: KenaColors.accent, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso flotante de que llegaron mensajes mientras se estaba mirando
/// más arriba en el historial — evita el "queda estático" (sección
/// reportada por prueba de usuario): en vez de forzar el scroll y
/// sacarte de donde estabas leyendo, avisa y deja que vos decidas bajar.
class _NewMessagesPill extends StatelessWidget {
  const _NewMessagesPill({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: KenaColors.bg.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: KenaColors.accent.withValues(alpha: 0.45)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count == 1 ? '1 mensaje nuevo' : '$count mensajes nuevos',
                  style: KenaTypography.bodySmall.copyWith(fontWeight: FontWeight.w700, color: KenaColors.accent),
                ),
                const SizedBox(width: 6),
                Icon(Icons.arrow_downward_rounded, size: 14, color: KenaColors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Franja fina sobre el input, sólo visible mientras alguien más está
/// escribiendo en este hilo — se anima entrando/saliendo para no
/// "saltar" el layout del resto de la pantalla.
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      alignment: Alignment.bottomCenter,
      child: text == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.6, color: KenaColors.accent),
                  ),
                  const SizedBox(width: 8),
                  Text(text!, style: KenaTypography.bodySmall.copyWith(fontStyle: FontStyle.italic)),
                ],
              ),
            ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  const _AttachOption({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.5,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: KenaColors.card,
          borderRadius: BorderRadius.circular(KenaRadius.card),
          border: Border.all(color: KenaColors.line),
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: KenaColors.accentSoft, borderRadius: BorderRadius.circular(KenaRadius.sm)),
              child: Icon(icon, size: 18, color: KenaColors.accent),
            ),
            const SizedBox(height: 8),
            Text(label, style: KenaTypography.caption.copyWith(color: KenaColors.text)),
            const SizedBox(height: 2),
            Text('Próximamente', style: KenaTypography.caption),
          ],
        ),
      ),
    );
  }
}

/// Hoja para editar el texto de un mensaje propio — reemplaza el
/// `AlertDialog` nativo que había acá antes (el otro, junto con el
/// selector de transferencia de anfitrión en [RoomShellScreen], eran
/// los dos únicos diálogos de Material que quedaban en la app).
class _EditMessageSheet extends StatelessWidget {
  const _EditMessageSheet({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(KenaSpacing.xl, KenaSpacing.xl, KenaSpacing.xl, KenaSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Editar mensaje', style: KenaTypography.titleXL),
              const SizedBox(height: KenaSpacing.lg),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 1,
                maxLines: 5,
                style: KenaTypography.body.copyWith(fontWeight: FontWeight.w600, color: KenaColors.text),
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KenaRadius.input),
                    borderSide: BorderSide(color: KenaColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KenaRadius.input),
                    borderSide: BorderSide(color: KenaColors.lineStrong),
                  ),
                ),
              ),
              const SizedBox(height: KenaSpacing.xxl),
              KenaGlassButton(
                onPressed: () => Navigator.of(context).pop(controller.text.trim()),
                child: const Text('Guardar'),
              ),
              const SizedBox(height: KenaSpacing.sm),
              KenaGhostButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
