import 'package:flutter/material.dart';

import '../../accounts/domain/auth_controller.dart';
import '../../accounts/domain/group_controller.dart';
import '../../accounts/domain/models/kena_group.dart';
import '../../accounts/domain/providers/billing_service.dart';
import '../../theme/kena_colors.dart';
import '../../theme/kena_spacing.dart';
import '../../theme/kena_typography.dart';
import '../../widgets/kena_glass_button.dart';
import '../create_room/create_room_screen.dart';
import 'account_login_screen.dart';

enum _PlanChoice { trial, pass, groupPass }

/// Paywall "Kena Pass" (ver brief) — se llega acá después del
/// instructivo (`RoomWalkthroughScreen`). A propósito, la cuenta **no**
/// existe todavía en este punto: recién se crea después de tocar
/// "Activar prueba gratuita"/"Kena Pass"/"Kena Group Pass" — nunca
/// antes, para no pedir login sin que el usuario haya visto ni elegido
/// nada todavía.
class KenaPassPlansScreen extends StatefulWidget {
  const KenaPassPlansScreen({super.key});

  @override
  State<KenaPassPlansScreen> createState() => _KenaPassPlansScreenState();
}

class _KenaPassPlansScreenState extends State<KenaPassPlansScreen> {
  _PlanChoice? _busy;
  String? _error;

  Future<void> _choose(_PlanChoice choice) async {
    setState(() {
      _busy = choice;
      _error = null;
    });
    try {
      // 1) Cuenta — recién ahora, disparada por la elección de plan (ver
      // brief: "quiero que la creación de cuenta sea después de tocar
      // en prueba gratuita, en kena pass... o kena group pass").
      final signedIn = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const AccountLoginScreen()),
      );
      if (!mounted) return;
      if (signedIn != true) {
        setState(() => _busy = null);
        return;
      }

      final user = AuthController.instance.value;
      if (user == null) {
        setState(() {
          _busy = null;
          _error = 'No pudimos iniciar sesión. Probá de nuevo.';
        });
        return;
      }

      // 2) Grupo — todo plan/entitlement es del grupo, nunca del
      // usuario ni de la sala (ver el modelo de dominio del brief).
      // Quien recién se crea una cuenta todavía no tiene ninguno.
      final groupController = GroupController(userId: user.id);
      await groupController.load();
      if (!mounted) return;
      if (groupController.groups.isEmpty) {
        await groupController.createGroup('Grupo de ${user.firstName}');
        if (!mounted) return;
      }

      // 3) El plan elegido.
      final PurchaseResult result;
      switch (choice) {
        case _PlanChoice.trial:
          result = await groupController.activateFreeTrial();
        case _PlanChoice.pass:
          result = await groupController.activatePlan(GroupPlanType.personal);
        case _PlanChoice.groupPass:
          result = await groupController.activatePlan(GroupPlanType.group);
      }
      if (!mounted) return;
      if (result.outcome != PurchaseOutcome.success) {
        setState(() {
          _busy = null;
          _error = result.errorMessage ?? 'No pudimos activar el plan. Probá de nuevo.';
        });
        return;
      }

      // Listo: directo a crear la sala, sin dejar todo este flujo en el
      // stack (un "volver atrás" desde la sala no debería reaparecer en
      // mitad del paywall).
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const CreateRoomScreen()),
        (route) => route.isFirst,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _error = 'Algo salió mal. Probá de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return KenaBackground(
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                const SizedBox(height: KenaSpacing.sm),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(gradient: KenaColors.brandGradient, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Icon(Icons.workspace_premium_rounded, color: KenaColors.onAccent, size: 28),
                ),
                const SizedBox(height: KenaSpacing.lg),
                Text('Kena Pass', style: KenaTypography.titleL),
                const SizedBox(height: KenaSpacing.sm),
                Text(
                  'Para armar tu grupo, invitar gente y tener salas ilimitadas.',
                  style: KenaTypography.bodySmall,
                ),
                const SizedBox(height: KenaSpacing.xl),
                Expanded(
                  child: ListView(
                    children: [
                      _PlanTile(
                        title: 'Kena Pass',
                        subtitle: 'Hasta ${GroupPlanType.personal.maxMembers} miembros · salas ilimitadas',
                        price: 'USD ${GroupPlanType.personal.referencePriceUsd.toStringAsFixed(2)} / 30 días',
                        busy: _busy == _PlanChoice.pass,
                        highlighted: false,
                        onTap: () => _choose(_PlanChoice.pass),
                      ),
                      const SizedBox(height: KenaSpacing.sm),
                      _PlanTile(
                        title: 'Kena Group Pass',
                        subtitle: 'Hasta ${GroupPlanType.group.maxMembers} miembros · salas ilimitadas',
                        price: 'USD ${GroupPlanType.group.referencePriceUsd.toStringAsFixed(2)} / 30 días',
                        busy: _busy == _PlanChoice.groupPass,
                        highlighted: true,
                        onTap: () => _choose(_PlanChoice.groupPass),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: KenaSpacing.md),
                        Text(_error!, textAlign: TextAlign.center, style: KenaTypography.bodySmall.copyWith(color: KenaColors.red)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: KenaSpacing.md),
                KenaGlassButton(
                  onPressed: _busy == null ? () => _choose(_PlanChoice.trial) : null,
                  child: _busy == _PlanChoice.trial
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: KenaColors.onAccent))
                      : const Text('Activar prueba gratuita'),
                ),
                const SizedBox(height: KenaSpacing.sm),
                Text(
                  '7 días gratis con los límites de Kena Pass. Compra simulada — todavía no '
                  'está conectado a Apple IAP ni Google Play Billing.',
                  textAlign: TextAlign.center,
                  style: KenaTypography.caption,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.busy,
    required this.highlighted,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String price;
  final bool busy;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? KenaColors.accentSoft : KenaColors.card,
      borderRadius: BorderRadius.circular(KenaRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(KenaRadius.card),
        onTap: busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KenaRadius.card),
            border: Border.all(color: highlighted ? KenaColors.accent : KenaColors.line, width: highlighted ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: KenaTypography.body.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: KenaTypography.caption),
                    const SizedBox(height: 6),
                    Text(price, style: KenaTypography.bodySmall.copyWith(fontWeight: FontWeight.w700, color: KenaColors.accent)),
                  ],
                ),
              ),
              if (busy)
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: KenaColors.accent))
              else
                Icon(Icons.chevron_right_rounded, color: KenaColors.text3),
            ],
          ),
        ),
      ),
    );
  }
}
