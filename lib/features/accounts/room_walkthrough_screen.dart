import 'package:flutter/material.dart';

import '../../core/utils/avatar.dart';
import '../../theme/kena_colors.dart';
import '../../theme/kena_spacing.dart';
import '../../theme/kena_typography.dart';
import '../../widgets/avatar.dart';
import '../../widgets/kena_glass_button.dart';
import '../../widgets/stagger_in.dart';
import 'kena_pass_plans_screen.dart';

/// Instructivo interactivo que se ve antes de mostrar los planes (ver
/// brief: "antes de crear sala... mostrale un instructivo interactivo
/// con pantallas de ejemplo de lo que hay dentro de cada sala") — 3
/// pantallas de ejemplo (chat grupal, chat privado, sala de juegos),
/// puramente ilustrativas: los mensajes son inventados para mostrar el
/// producto, no vienen de ninguna sala real ni de ningún backend.
class RoomWalkthroughScreen extends StatefulWidget {
  const RoomWalkthroughScreen({super.key});

  @override
  State<RoomWalkthroughScreen> createState() => _RoomWalkthroughScreenState();
}

class _WalkthroughStep {
  final String title;
  final String body;
  final Widget Function() previewBuilder;
  const _WalkthroughStep({required this.title, required this.body, required this.previewBuilder});
}

class _RoomWalkthroughScreenState extends State<RoomWalkthroughScreen> {
  final _pageController = PageController();
  int _page = 0;

  late final _steps = [
    _WalkthroughStep(
      title: 'Chat grupal, para todos',
      body: 'Todos los que están en la sala ven los mismos mensajes, en vivo — como armar '
          'un grupo, pero sin depender de Internet.',
      previewBuilder: () => const _GroupChatPreview(),
    ),
    _WalkthroughStep(
      title: 'Y un privado con cada uno',
      body: 'Tocá a cualquier participante para abrir una conversación aparte, sin salir de la sala.',
      previewBuilder: () => const _PrivateChatPreview(),
    ),
    _WalkthroughStep(
      title: 'Sala de juegos',
      body: 'Para cuando la espera se hace larga — juegos rápidos para jugar entre todos, sin salir de Kena.',
      previewBuilder: () => const _GameRoomPreview(),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _steps.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    } else {
      _goToPlans();
    }
  }

  void _goToPlans() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const KenaPassPlansScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _steps.length - 1;
    return KenaBackground(
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _goToPlans,
                      child: Text('Saltar', style: KenaTypography.bodySmall.copyWith(color: KenaColors.text3, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _steps.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    final step = _steps[i];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Column(
                        children: [
                          Expanded(child: Center(child: step.previewBuilder())),
                          const SizedBox(height: KenaSpacing.xl),
                          Text(step.title, textAlign: TextAlign.center, style: KenaTypography.titleXL),
                          const SizedBox(height: KenaSpacing.sm),
                          Text(step.body, textAlign: TextAlign.center, style: KenaTypography.bodySmall.copyWith(height: 1.5)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _steps.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: i == _page ? KenaColors.accent : KenaColors.track,
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                child: KenaGlassButton(onPressed: _next, child: Text(isLast ? 'Ver planes' : 'Siguiente')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marco tipo "pantalla dentro de la pantalla" — mismo recurso visual
/// para las 3 preview (chat grupal/privado/juegos), sólo cambia el
/// contenido de adentro.
class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 300,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KenaColors.card,
        borderRadius: BorderRadius.circular(KenaRadius.sheet),
        border: Border.all(color: KenaColors.lineStrong),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 28, offset: const Offset(0, 14))],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(KenaRadius.card), child: child),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.name, required this.text, required this.isMine, this.index = 0});

  final String name;
  final String text;
  final bool isMine;
  final int index;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isMine ? null : KenaColors.card2,
        gradient: isMine ? KenaColors.brandGradient : null,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(13),
          topRight: const Radius.circular(13),
          bottomLeft: Radius.circular(isMine ? 13 : 3),
          bottomRight: Radius.circular(isMine ? 3 : 13),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMine)
            Text(name, style: KenaTypography.caption.copyWith(fontWeight: FontWeight.w700, color: avatarColorFor(name))),
          Text(text, style: KenaTypography.bodySmall.copyWith(color: isMine ? KenaColors.onAccent : KenaColors.text, height: 1.3)),
        ],
      ),
    );

    return StaggerIn(
      index: index,
      baseDelayMs: 90,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMine) ...[Avatar.forName(name, size: 22), const SizedBox(width: 6)],
            Flexible(child: bubble),
          ],
        ),
      ),
    );
  }
}

class _GroupChatPreview extends StatelessWidget {
  const _GroupChatPreview();

  @override
  Widget build(BuildContext context) {
    return _PreviewFrame(
      child: Container(
        color: KenaColors.bgSoft,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('General', style: KenaTypography.label.copyWith(color: KenaColors.text2)),
            const SizedBox(height: 6),
            const Expanded(
              child: SingleChildScrollView(
                physics: NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Bubble(name: 'Fede', text: '¿Todos llegaron bien? 👋', isMine: false, index: 0),
                    _Bubble(name: 'Lu', text: 'Sí, ya estamos acomodando todo', isMine: false, index: 1),
                    _Bubble(name: 'Vos', text: 'Dale, en 5 min llegamos', isMine: true, index: 2),
                    _Bubble(name: 'Ceci', text: 'Traje algo para picar 🧀', isMine: false, index: 3),
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

class _PrivateChatPreview extends StatelessWidget {
  const _PrivateChatPreview();

  @override
  Widget build(BuildContext context) {
    return _PreviewFrame(
      child: Container(
        color: KenaColors.bgSoft,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar.forName('Lu', size: 20),
                const SizedBox(width: 6),
                Text('Lu', style: KenaTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            const Expanded(
              child: SingleChildScrollView(
                physics: NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Bubble(name: 'Lu', text: '¿Le decimos ya de la sorpresa? 🎉', isMine: false, index: 0),
                    _Bubble(name: 'Vos', text: 'Todavía no, esperemos que llegue Fede', isMine: true, index: 1),
                    _Bubble(name: 'Lu', text: 'Dale jaja va a explotar', isMine: false, index: 2),
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

class _GameRoomPreview extends StatelessWidget {
  const _GameRoomPreview();

  static const _games = [
    (icon: Icons.quiz_rounded, name: 'Trivia'),
    (icon: Icons.gesture_rounded, name: 'Ahorcado'),
    (icon: Icons.grid_3x3_rounded, name: 'Ta-Te-Ti'),
  ];

  @override
  Widget build(BuildContext context) {
    return _PreviewFrame(
      child: Container(
        color: KenaColors.bgSoft,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sala de juegos', style: KenaTypography.label.copyWith(color: KenaColors.text2)),
            const SizedBox(height: 8),
            for (var i = 0; i < _games.length; i++)
              StaggerIn(
                index: i,
                baseDelayMs: 90,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: KenaColors.card,
                      borderRadius: BorderRadius.circular(KenaRadius.sm),
                      border: Border.all(color: KenaColors.line),
                    ),
                    child: Row(
                      children: [
                        Icon(_games[i].icon, size: 16, color: KenaColors.accent),
                        const SizedBox(width: 8),
                        Text(_games[i].name, style: KenaTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            const Spacer(),
            Center(child: Text('Vista previa', style: KenaTypography.caption)),
          ],
        ),
      ),
    );
  }
}
