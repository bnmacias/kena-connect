import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/protocol/chat_message.dart';

/// UI de chat minimalista: lista de mensajes + campo de texto + botón de
/// enviar, con burbujas en estilo Material 3 que siguen el modo claro u
/// oscuro del sistema. Mensajes propios alineados a la derecha, ajenos a
/// la izquierda; eventos de protocolo (join/leave/presence/ack)
/// centrados como texto de sistema. La reutilizan tanto la pantalla de
/// host como la de cliente.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.title,
    required this.messages,
    required this.onSend,
    required this.ownSenderId,
  });

  final String title;
  final Stream<ChatMessage> messages;
  final void Function(String text) onSend;
  final String ownSenderId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _log = <ChatMessage>[];
  late final StreamSubscription<ChatMessage> _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.messages.listen((msg) {
      setState(() => _log.add(msg));
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  String _describeSystemEvent(ChatMessage m) {
    switch (m.type) {
      case MessageType.join:
        return '${m.senderName} se unió';
      case MessageType.leave:
        return '${m.senderName} se desconectó';
      case MessageType.presence:
        return '${m.senderName} (presencia)';
      case MessageType.ack:
        return 'ACK de ${m.senderName}';
      case MessageType.message:
        return m.text ?? '';
    }
  }

  Widget _buildRow(BuildContext context, ChatMessage m) {
    final colors = Theme.of(context).colorScheme;

    if (m.type != MessageType.message) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Text(
            _describeSystemEvent(m),
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ),
      );
    }

    final isMine = m.senderId == widget.ownSenderId;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  m.senderName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: colors.primary,
                  ),
                ),
              ),
            Text(
              m.text ?? '',
              style: TextStyle(
                color: isMine ? colors.onPrimary : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _log.length,
              itemBuilder: (context, index) => _buildRow(context, _log[index]),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.outlineVariant)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Mensaje',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: _handleSend,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
