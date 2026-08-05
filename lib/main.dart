import 'package:flutter/material.dart';

import 'features/client/client_screen.dart';
import 'features/host/host_screen.dart';

void main() {
  runApp(const KenaApp());
}

class KenaApp extends StatelessWidget {
  const KenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kena Connect',
      home: const ModeSelectionScreen(),
    );
  }
}

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kena Connect')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HostScreen()),
              ),
              child: const Text('Modo Host'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ClientScreen()),
              ),
              child: const Text('Modo Cliente'),
            ),
          ],
        ),
      ),
    );
  }
}
