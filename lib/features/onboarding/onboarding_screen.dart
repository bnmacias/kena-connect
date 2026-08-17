import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/kena_colors.dart';
import '../../theme/kena_typography.dart';
import '../../widgets/kena_glass_button.dart';
import '../../widgets/signal_rings.dart';
import '../home/home_screen.dart';

const _seenOnboardingKey = 'kena.seenOnboarding';

Future<bool> hasSeenOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_seenOnboardingKey) ?? false;
}

class _Step {
  final String title;
  final String body;
  final IconData icon;
  const _Step(this.title, this.body, this.icon);
}

const _steps = [
  _Step(
    'Chateá sin Internet',
    'Kena convierte los dispositivos que tenés cerca en su propia red '
        'temporal. Sin datos, sin wifi público, sin señal de celular.',
    Icons.wifi_rounded,
  ),
  _Step(
    'Creá una red con tu grupo',
    'Armá una sala, compartí un código o un QR, y en segundos tenés un '
        'chat en vivo funcionando sobre la red local.',
    Icons.hub_rounded,
  ),
  _Step(
    'Solo funciona de cerca',
    'Los mensajes van y vienen mientras estén conectados a la misma red '
        'local. Si alguien se aleja, se reconecta solo al volver a estar cerca.',
    Icons.near_me_rounded,
  ),
];

/// Onboarding de 3 pasos, sólo la primera vez que se abre la app —
/// explica el concepto ("sin Internet, sin cuenta") antes de pedir
/// cualquier acción.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenOnboardingKey, true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    final isLast = _step == _steps.length - 1;

    return KenaBackground(
      builder: (context) => Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Column(
                      key: ValueKey(_step),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SignalRings(size: 100, icon: step.icon),
                        const SizedBox(height: 26),
                        Text(step.title, textAlign: TextAlign.center, style: KenaTypography.titleXL),
                        const SizedBox(height: 10),
                        Text(
                          step.body,
                          textAlign: TextAlign.center,
                          style: KenaTypography.bodySmall.copyWith(height: 1.55),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _steps.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _step ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: i == _step ? KenaColors.accent : KenaColors.track,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                KenaGlassButton(
                  onPressed: () {
                    if (isLast) {
                      _finish();
                    } else {
                      setState(() => _step++);
                    }
                  },
                  child: Text(isLast ? 'Empezar' : 'Siguiente'),
                ),
                if (!isLast)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: TextButton(
                      onPressed: _finish,
                      child: Text('Saltar', style: KenaTypography.bodySmall.copyWith(color: KenaColors.text3, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
