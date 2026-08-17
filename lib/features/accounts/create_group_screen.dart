import 'package:flutter/material.dart';

import '../../accounts/domain/group_controller.dart';
import '../../theme/kena_colors.dart';
import '../../theme/kena_spacing.dart';
import '../../theme/kena_typography.dart';
import '../../widgets/kena_field.dart';
import '../../widgets/kena_glass_button.dart';

/// Tercer paso del onboarding de cuentas (ver brief, sección 8) —
/// arma el primer [KenaGroup] del usuario, siempre en plan `free` hasta
/// que active uno pago en [ActivatePlanScreen].
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key, required this.groupController});

  final GroupController groupController;

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController(text: 'Familia');
  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Ponele un nombre al grupo.');
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      await widget.groupController.createGroup(name);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No pudimos crear el grupo. Probá de nuevo.');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KenaBackground(
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Creá tu primer grupo')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Un grupo junta a la gente con la que armás salas seguido — '
                  'todos sus miembros comparten el mismo plan.',
                  style: KenaTypography.bodySmall,
                ),
                const SizedBox(height: KenaSpacing.lg),
                KenaField(
                  label: 'Nombre del grupo',
                  controller: _nameController,
                  hint: 'Ej: Familia Macías',
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                ),
                if (_error != null) Text(_error!, style: KenaTypography.bodySmall.copyWith(color: KenaColors.red)),
                const Spacer(),
                KenaGlassButton(
                  onPressed: _creating ? null : _create,
                  child: _creating
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: KenaColors.onAccent))
                      : const Text('Crear grupo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
