import 'package:flutter/material.dart';

import '../../theme/kena_colors.dart';
import '../../theme/kena_spacing.dart';
import '../../theme/kena_typography.dart';
import '../accounts/accounts_entry_screen.dart';
import '../profile/profile_screen.dart';
import 'about_kena_screen.dart';
import 'privacy_screen.dart';

class _SettingsCategory {
  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;

  const _SettingsCategory({required this.icon, required this.title, required this.subtitle, required this.builder});
}

/// Sólo se listan las categorías que realmente hacen algo (Perfil,
/// Privacidad, Acerca de Kena). Antes había 6 filas más marcadas
/// "Próximamente" — ocupaban la mayoría de la pantalla con promesas en
/// vez de funciones, lo que le restaba a la sensación de producto
/// terminado sin sumar nada real (ver auditoría de diseño, hallazgo #7
/// y sección E). El día que una de esas funciones exista de verdad,
/// gana su fila — no antes.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = <_SettingsCategory>[
      _SettingsCategory(
        icon: Icons.person_outline_rounded,
        title: 'Perfil',
        subtitle: 'Nombre, avatar y apariencia',
        builder: (_) => const ProfileScreen(),
      ),
      _SettingsCategory(
        icon: Icons.lock_outline_rounded,
        title: 'Privacidad',
        subtitle: 'Qué guarda Kena y qué no',
        builder: (_) => const PrivacyScreen(),
      ),
      _SettingsCategory(
        icon: Icons.info_outline_rounded,
        title: 'Acerca de Kena',
        subtitle: 'Versión y qué es la app',
        builder: (_) => const AboutKenaScreen(),
      ),
      _SettingsCategory(
        icon: Icons.groups_2_outlined,
        title: 'Cuentas y grupos',
        subtitle: 'Beta — login y planes en modo demo',
        builder: (_) => const AccountsEntryScreen(),
      ),
    ];

    return KenaBackground(
      builder: (context) => Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            for (final category in categories)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: KenaColors.card,
                    borderRadius: BorderRadius.circular(KenaRadius.card),
                    border: Border.all(color: KenaColors.line),
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KenaRadius.card)),
                    leading: Icon(category.icon, color: KenaColors.accent),
                    title: Text(category.title, style: KenaTypography.body.copyWith(fontWeight: FontWeight.w700, color: KenaColors.text)),
                    subtitle: Text(category.subtitle, style: KenaTypography.bodySmall.copyWith(fontSize: 12, color: KenaColors.text2)),
                    trailing: Icon(Icons.chevron_right_rounded, color: KenaColors.text3),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: category.builder)),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
              child: Text(
                'Más funciones en camino — Kena avisa cuando algo pasa de ser una idea a ser real.',
                textAlign: TextAlign.center,
                style: KenaTypography.caption.copyWith(color: KenaColors.text3, fontSize: 11.5, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
