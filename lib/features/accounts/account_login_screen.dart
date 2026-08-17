import 'package:flutter/material.dart';

import '../../accounts/domain/auth_controller.dart';
import '../../accounts/domain/models/auth_provider_type.dart';
import '../../theme/kena_colors.dart';
import '../../theme/kena_spacing.dart';
import '../../theme/kena_typography.dart';
import '../../widgets/gradient_text.dart';
import '../../widgets/kena_glass_button.dart';
import 'phone_auth_screen.dart';

/// Primera pantalla del flujo de cuentas (ver brief, sección 2) — login
/// social o teléfono. Puramente aditivo: no reemplaza el arranque
/// normal de Kena (`RootScreen`/`HomeScreen`), que sigue sin pedir
/// ninguna cuenta — esto sólo se alcanza desde "Cuentas y grupos" en
/// Configuración mientras el resto de las piezas (grupos, planes) no
/// esté conectado a servicios reales.
class AccountLoginScreen extends StatefulWidget {
  const AccountLoginScreen({super.key});

  @override
  State<AccountLoginScreen> createState() => _AccountLoginScreenState();
}

class _AccountLoginScreenState extends State<AccountLoginScreen> {
  AuthProviderType? _loading;
  String? _error;

  Future<void> _continueWith(AuthProviderType provider) async {
    setState(() {
      _loading = provider;
      _error = null;
    });
    try {
      await AuthController.instance.signInWithSocial(provider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No pudimos continuar con ese método. Probá de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  Future<void> _continueWithPhone() async {
    final signedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
    );
    if (signedIn == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return KenaBackground(
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            child: Column(
              children: [
                const Spacer(),
                GradientText('Tu cuenta de Kena', style: KenaTypography.titleL, gradient: KenaColors.brandGradient),
                const SizedBox(height: KenaSpacing.sm),
                Text(
                  'Para armar grupos y compartir salas entre tus dispositivos.',
                  textAlign: TextAlign.center,
                  style: KenaTypography.bodySmall,
                ),
                const Spacer(),
                if (_error != null) ...[
                  Text(_error!, textAlign: TextAlign.center, style: KenaTypography.bodySmall.copyWith(color: KenaColors.red)),
                  const SizedBox(height: KenaSpacing.md),
                ],
                _SocialButton(
                  label: 'Continuar con Apple',
                  icon: Icons.apple_rounded,
                  loading: _loading == AuthProviderType.apple,
                  onTap: () => _continueWith(AuthProviderType.apple),
                ),
                const SizedBox(height: KenaSpacing.sm),
                _SocialButton(
                  label: 'Continuar con Google',
                  icon: Icons.g_mobiledata_rounded,
                  loading: _loading == AuthProviderType.google,
                  onTap: () => _continueWith(AuthProviderType.google),
                ),
                const SizedBox(height: KenaSpacing.sm),
                _SocialButton(
                  label: 'Continuar con Facebook',
                  icon: Icons.facebook_rounded,
                  loading: _loading == AuthProviderType.facebook,
                  onTap: () => _continueWith(AuthProviderType.facebook),
                ),
                const SizedBox(height: KenaSpacing.sm),
                _SocialButton(
                  label: 'Continuar con teléfono',
                  icon: Icons.smartphone_rounded,
                  loading: false,
                  onTap: _continueWithPhone,
                ),
                const SizedBox(height: KenaSpacing.lg),
                Text(
                  'Los proveedores sociales y el SMS todavía están en modo demo — '
                  'no se conecta a Google/Apple/Facebook/Twilio de verdad.',
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

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.label, required this.icon, required this.loading, required this.onTap});

  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KenaGhostButton(
      onPressed: loading ? null : onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: KenaColors.accent))
          else
            Icon(icon, size: 18),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}
