import 'package:flutter/material.dart';

import 'home/home_screen.dart';
import 'onboarding/onboarding_screen.dart';
import 'room/domain/host_session_resume.dart';
import 'room/room_shell_screen.dart';

/// Decide qué mostrar al arrancar la app en frío: si este dispositivo
/// estaba siendo anfitrión de una sala cuando el proceso murió (cierre a
/// la fuerza), la recupera sola antes que nada — ver
/// `host_session_resume.dart`. Si no, el onboarding (primera vez) o
/// Inicio directo.
class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  Future<Widget> _decideStartScreen() async {
    final resumed = await tryResumeActiveRoom();
    if (resumed != null) return RoomShellScreen(session: resumed);

    final seenOnboarding = await hasSeenOnboarding();
    return seenOnboarding ? const HomeScreen() : const OnboardingScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _decideStartScreen(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: SizedBox.shrink());
        }
        return snapshot.data!;
      },
    );
  }
}
