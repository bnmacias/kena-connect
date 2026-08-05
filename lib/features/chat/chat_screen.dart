import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/protocol/chat_message.dart';

/// UI mínima de chat: lista de mensajes recibidos + campo de texto + botón
/// de enviar. Mensajes propios alineados a la derecha, ajenos a la
/// izquierda; eventos de protocolo (join/leave/presence/ack) centrados
/// como texto de sistema. Sin estilos elaborados, es solo para validar
/// que la conexión funciona. La reutilizan tanto la pantalla de host
/// como la de cliente.
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
    if (m.type != MessageType.message) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Text(
            _describeSystemEvent(m),
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMine ? Colors.deepPurple.shade100 : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMine)
              Text(
                m.senderName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            Text(m.text ?? ''),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Mensaje'),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _handleSend,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
