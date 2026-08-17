import 'package:flutter/material.dart';

import '../../accounts/domain/group_controller.dart';
import '../../accounts/domain/models/kena_group.dart';
import '../../accounts/domain/providers/billing_service.dart';
import '../../theme/kena_colors.dart';
import '../../theme/kena_spacing.dart';
import '../../theme/kena_typography.dart';
import '../../widgets/kena_glass_button.dart';

/// Cuarto paso del onboarding de cuentas (ver brief, secciones 6 y 8) —
/// Free/Personal/Grupo. La compra real pasa por [BillingService]
/// (mockeado hoy, ver `AccountsEnvironment`): "activar" un plan pago acá
/// no cobra nada de verdad todavía.
class ActivatePlanScreen extends StatefulWidget {
  const ActivatePlanScreen({super.key, required this.groupController});

  final GroupController groupController;

  @override
  State<ActivatePlanScreen> createState() => _ActivatePlanScreenState();
}

class _ActivatePlanScreenState extends State<ActivatePlanScreen> {
  GroupPlanType? _activating;
  String? _error;

  Future<void> _activate(GroupPlanType plan) async {
    setState(() {
      _activating = plan;
      _error = null;
    });
    try {
      final result = await widget.groupController.activatePlan(plan);
      if (!mounted) return;
      if (result.outcome != PurchaseOutcome.success) {
        setState(() => _error = result.errorMessage ?? 'No se pudo activar el plan.');
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo activar el plan. Probá de nuevo.');
    } finally {
      if (mounted) setState(() => _activating = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.groupController.active;
    return KenaBackground(
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Elegí un plan')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              Text(
                'El plan es del grupo${group != null ? ' "${group.name}"' : ''}, no de un dispositivo ni de una sala '
                '— todos sus miembros lo comparten.',
                style: KenaTypography.bodySmall,
              ),
              const SizedBox(height: KenaSpacing.xl),
              _PlanCard(
                plan: GroupPlanType.free,
                current: group?.planType == GroupPlanType.free,
                busy: _activating == GroupPlanType.free,
                onActivate: () => _activate(GroupPlanType.free),
              ),
              const SizedBox(height: KenaSpacing.sm),
              _PlanCard(
                plan: GroupPlanType.personal,
                current: group?.planType == GroupPlanType.personal,
                busy: _activating == GroupPlanType.personal,
                onActivate: () => _activate(GroupPlanType.personal),
              ),
              const SizedBox(height: KenaSpacing.sm),
              _PlanCard(
                plan: GroupPlanType.group,
                current: group?.planType == GroupPlanType.group,
                busy: _activating == GroupPlanType.group,
                onActivate: () => _activate(GroupPlanType.group),
              ),
              if (_error != null) ...[
                const SizedBox(height: KenaSpacing.md),
                Text(_error!, style: KenaTypography.bodySmall.copyWith(color: KenaColors.red)),
              ],
              const SizedBox(height: KenaSpacing.lg),
              Text(
                'Compra simulada — todavía no está conectado a Apple IAP ni Google Play Billing.',
                textAlign: TextAlign.center,
                style: KenaTypography.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.current, required this.busy, required this.onActivate});

  final GroupPlanType plan;
  final bool current;
  final bool busy;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: current ? KenaColors.accentSoft : KenaColors.card,
        borderRadius: BorderRadius.circular(KenaRadius.card),
        border: Border.all(color: current ? KenaColors.accent : KenaColors.line, width: current ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(plan.label, style: KenaTypography.body.copyWith(fontWeight: FontWeight.w700)),
                    if (current) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: KenaColors.accent, borderRadius: BorderRadius.circular(KenaRadius.sm)),
                        child: Text('ACTIVO', style: KenaTypography.label.copyWith(color: KenaColors.onAccent)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  plan == GroupPlanType.free
                      ? 'Hasta ${plan.maxMembers} miembros, salas ilimitadas.'
                      : 'USD ${plan.referencePriceUsd.toStringAsFixed(2)} · ${plan.durationDays} días · hasta ${plan.maxMembers} miembros',
                  style: KenaTypography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            child: current
                ? const SizedBox.shrink()
                : KenaGlassButton(
                    onPressed: busy ? null : onActivate,
                    child: busy
                        ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: KenaColors.onAccent))
                        : const Text('Elegir'),
                  ),
          ),
        ],
      ),
    );
  }
}
