import '../models/kena_group.dart';

/// Un producto de suscripción tal como lo vendería la tienda
/// correspondiente — `storeProductId` es el id que hay que dar de alta
/// en App Store Connect / Play Console (no configurado todavía).
class BillingProduct {
  final GroupPlanType planType;
  final String storeProductId;
  final String displayPrice;

  const BillingProduct({required this.planType, required this.storeProductId, required this.displayPrice});
}

enum PurchaseOutcome { success, cancelled, failed }

class PurchaseResult {
  final PurchaseOutcome outcome;
  final GroupPlanType? planType;
  final String? errorMessage;

  const PurchaseResult({required this.outcome, this.planType, this.errorMessage});
}

/// Desacopla la compra de un plan del store real (ver brief, sección
/// 10: Apple IAP / Google Play Billing, nunca Stripe). `ActivatePlanScreen`
/// y `EntitlementManager` sólo conocen esta interfaz.
abstract class BillingService {
  Future<List<BillingProduct>> fetchProducts();
  Future<PurchaseResult> purchase(GroupPlanType planType);
  Future<List<PurchaseResult>> restorePurchases();
}

/// Implementación real para iOS — pensada sobre el plugin
/// `in_app_purchase` (StoreKit por debajo). No integrada todavía: hace
/// falta el plugin, los productos dados de alta en App Store Connect, y
/// un servidor propio que valide el recibo de compra contra Apple antes
/// de activar el plan (nunca confiar el estado "pagado" sólo al
/// dispositivo). Falla explícito en vez de fingir un cobro.
class AppleIapBillingService implements BillingService {
  const AppleIapBillingService();

  @override
  Future<List<BillingProduct>> fetchProducts() => throw UnimplementedError(
        'AppleIapBillingService no está integrado — falta el plugin in_app_purchase, '
        'los productos en App Store Connect, y el backend de validación de recibos.',
      );

  @override
  Future<PurchaseResult> purchase(GroupPlanType planType) => throw UnimplementedError(
        'AppleIapBillingService no está integrado — ver fetchProducts().',
      );

  @override
  Future<List<PurchaseResult>> restorePurchases() => throw UnimplementedError(
        'AppleIapBillingService no está integrado — ver fetchProducts().',
      );
}

/// Implementación real para Android — pensada sobre el mismo plugin
/// `in_app_purchase` (Play Billing por debajo). Mismos requisitos
/// pendientes que [AppleIapBillingService]: productos dados de alta en
/// Play Console + validación de recibo server-side.
class GooglePlayBillingService implements BillingService {
  const GooglePlayBillingService();

  @override
  Future<List<BillingProduct>> fetchProducts() => throw UnimplementedError(
        'GooglePlayBillingService no está integrado — falta el plugin in_app_purchase, '
        'los productos en Play Console, y el backend de validación de recibos.',
      );

  @override
  Future<PurchaseResult> purchase(GroupPlanType planType) => throw UnimplementedError(
        'GooglePlayBillingService no está integrado — ver fetchProducts().',
      );

  @override
  Future<List<PurchaseResult>> restorePurchases() => throw UnimplementedError(
        'GooglePlayBillingService no está integrado — ver fetchProducts().',
      );
}

/// Para desarrollo/demo sin cuentas de comercio reales: "vende" el plan
/// al instante, sin ningún cobro real. Es la que usa la app hoy (ver
/// `AccountsEnvironment`) hasta que haya productos reales configurados
/// en las tiendas y se pueda elegir entre [AppleIapBillingService]/
/// [GooglePlayBillingService] según la plataforma.
class MockBillingService implements BillingService {
  @override
  Future<List<BillingProduct>> fetchProducts() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const [
      BillingProduct(planType: GroupPlanType.personal, storeProductId: 'kena.plan.personal.mock', displayPrice: 'USD 0.99'),
      BillingProduct(planType: GroupPlanType.group, storeProductId: 'kena.plan.group.mock', displayPrice: 'USD 5.99'),
    ];
  }

  @override
  Future<PurchaseResult> purchase(GroupPlanType planType) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (planType == GroupPlanType.free) {
      return const PurchaseResult(outcome: PurchaseOutcome.success, planType: GroupPlanType.free);
    }
    return PurchaseResult(outcome: PurchaseOutcome.success, planType: planType);
  }

  @override
  Future<List<PurchaseResult>> restorePurchases() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const [];
  }
}
