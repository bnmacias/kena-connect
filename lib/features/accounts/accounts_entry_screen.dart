import 'package:flutter/material.dart';

import '../../accounts/domain/auth_controller.dart';
import '../../accounts/domain/group_controller.dart';
import '../../accounts/domain/models/kena_group.dart';
import '../../theme/kena_colors.dart';
import 'account_login_screen.dart';
import 'activate_plan_screen.dart';
import 'create_group_screen.dart';
import 'group_home_screen.dart';

/// Punto de entrada único al flujo de cuentas/grupos/plan (ver brief,
/// sección 8: Bienvenida → Login social → Crear primer grupo → Activar
/// plan → Home) — alcanzable desde "Cuentas y grupos" en Configuración,
/// nunca reemplaza el arranque normal de Kena (`RootScreen`): un
/// dispositivo puede seguir usando salas locales sin cuenta como
/// siempre, esto es una capa aparte, encima.
class AccountsEntryScreen extends StatefulWidget {
  const AccountsEntryScreen({super.key});

  @override
  State<AccountsEntryScreen> createState() => _AccountsEntryScreenState();
}

class _AccountsEntryScreenState extends State<AccountsEntryScreen> {
  GroupController? _groupController;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    await AuthController.instance.load();
    if (!mounted) return;

    if (AuthController.instance.value == null) {
      final signedIn = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const AccountLoginScreen()),
      );
      if (!mounted) return;
      if (signedIn != true) {
        Navigator.of(context).pop();
        return;
      }
    }

    final signedInUser = AuthController.instance.value;
    if (signedInUser == null) {
      Navigator.of(context).pop();
      return;
    }

    final groupController = GroupController(userId: signedInUser.id);
    await groupController.load();
    if (!mounted) return;

    if (groupController.active == null) {
      final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => CreateGroupScreen(groupController: groupController)),
      );
      if (!mounted) return;
      if (created != true) {
        Navigator.of(context).pop();
        return;
      }
    }

    final active = groupController.active;
    if (active != null && active.planType == GroupPlanType.free) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ActivatePlanScreen(groupController: groupController)),
      );
      if (!mounted) return;
    }

    setState(() {
      _groupController = groupController;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _groupController == null) {
      return KenaBackground(
        builder: (context) => Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator(color: KenaColors.accent)),
        ),
      );
    }
    return GroupHomeScreen(groupController: _groupController!);
  }
}
