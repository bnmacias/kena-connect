import 'package:flutter/material.dart';

import '../../core/utils/profile_store.dart';
import '../../theme/kena_colors.dart';
import '../../theme/kena_palette.dart';
import '../../theme/kena_spacing.dart';
import '../../theme/kena_theme_controller.dart';
import '../../theme/kena_typography.dart';
import '../../widgets/avatar.dart';
import '../../widgets/kena_field.dart';

/// Identidad local: nombre + color de avatar. No hace falta cuenta para
/// usar Kena — esto es lo único que te identifica ante los demás
/// mientras estás en una sala.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  int _avatarColorIndex = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ProfileStore.load().then((profile) {
      if (!mounted) return;
      setState(() {
        _nameController.text = profile.name;
        _avatarColorIndex = profile.avatarColorIndex;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ProfileStore.save(KenaProfile(
      name: _nameController.text.trim(),
      avatarColorIndex: _avatarColorIndex,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return KenaBackground(
        builder: (context) => Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator(color: KenaColors.accent)),
        ),
      );
    }
    final avatarColor = KenaColors.avatarPalette[_avatarColorIndex % KenaColors.avatarPalette.length];
    final initial = _nameController.text.trim().isEmpty ? '?' : _nameController.text.trim()[0].toUpperCase();

    return PopScope(
      onPopInvokedWithResult: (didPop, _) => _save(),
      child: KenaBackground(
        builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Tu perfil')),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              Center(child: Avatar(color: avatarColor, initial: initial, size: 64)),
              const SizedBox(height: 22),
              KenaField(
                label: 'Tu nombre',
                controller: _nameController,
                hint: 'Tu nombre',
                onChanged: (_) {
                  setState(() {});
                  _save();
                },
              ),
              Text('COLOR', style: KenaTypography.label.copyWith(color: KenaColors.text2)),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 0; i < KenaColors.avatarPalette.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setState(() => _avatarColorIndex = i);
                          _save();
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: KenaColors.avatarPalette[i],
                            border: Border.all(
                              // KenaColors.text (no blanco fijo): un aro
                              // blanco desaparece contra un tema con
                              // fondo claro — ver auditoría, sección I.
                              color: i == _avatarColorIndex ? KenaColors.text : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text('APARIENCIA', style: KenaTypography.label.copyWith(color: KenaColors.text2)),
              const SizedBox(height: 10),
              const _ThemePicker(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selector de tema — reemplaza el preview deshabilitado Oscuro/Claro
/// que hubo acá antes (ver ROADMAP.md, "Tema dark-only"): ya no es un
/// preview de algo futuro, cambia el tema de toda la app en el momento
/// (ver `KenaThemeController`/`KenaBackground`).
class _ThemePicker extends StatefulWidget {
  const _ThemePicker();

  @override
  State<_ThemePicker> createState() => _ThemePickerState();
}

class _ThemePickerState extends State<_ThemePicker> {
  @override
  void initState() {
    super.initState();
    KenaThemeController.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    KenaThemeController.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final active = KenaThemeController.instance.value.preset;
    return Row(
      children: [
        for (final preset in kenaPresetOrder) ...[
          Expanded(child: _ThemeSwatch(preset: preset, selected: preset == active)),
          if (preset != kenaPresetOrder.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.preset, required this.selected});

  final KenaPreset preset;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = kenaPalettes[preset]!;
    return InkWell(
      borderRadius: BorderRadius.circular(KenaRadius.card),
      onTap: () => KenaThemeController.instance.setPreset(preset),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: KenaColors.card2,
          borderRadius: BorderRadius.circular(KenaRadius.card),
          border: Border.all(color: selected ? KenaColors.accent : KenaColors.lineStrong, width: selected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [palette.gradA, palette.gradB]),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              palette.label,
              style: KenaTypography.caption.copyWith(color: selected ? KenaColors.text : KenaColors.text2),
            ),
          ],
        ),
      ),
    );
  }
}
