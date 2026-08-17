import 'package:flutter/material.dart';

import '../../accounts/domain/entitlement_gate.dart';
import '../../core/utils/profile_store.dart';
import '../../core/utils/room_history.dart';
import '../../theme/kena_colors.dart';
import '../../theme/kena_spacing.dart';
import '../../theme/kena_typography.dart';
import '../../widgets/avatar.dart';
import '../../widgets/gradient_text.dart';
import '../../widgets/option_row.dart';
import '../../widgets/signal_rings.dart';
import '../../widgets/stagger_in.dart';
import '../accounts/room_walkthrough_screen.dart';
import '../create_room/create_room_screen.dart';
import '../join_room/join_room_screen.dart';
import '../profile/profile_screen.dart';
import '../room/domain/active_room_registry.dart';
import '../room/domain/room_session.dart';
import '../room/room_shell_screen.dart';
import '../settings/settings_screen.dart';

String _relativeLabel(int timestampMs) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  final now = DateTime.now();
  final diff = DateTime(now.year, now.month, now.day).difference(DateTime(date.year, date.month, date.day)).inDays;
  if (diff <= 0) return 'Hoy';
  if (diff == 1) return 'Ayer';
  if (diff < 30) return 'Hace $diff días';
  final months = (diff / 30).floor();
  return months == 1 ? 'Hace 1 mes' : 'Hace $months meses';
}

/// Pantalla inicial: la marca (anillos de señal), las dos acciones
/// principales, y — si el dispositivo sigue conectado a una sala, o
/// participó de alguna antes — la forma de retomarla sin pedir nada de
/// nuevo. Elevada visualmente respecto de la versión anterior (ver
/// auditoría de diseño, hallazgo #1): tipografía propia para el nombre
/// de marca y entrada escalonada de las filas, en vez de una lista
/// estática con un logo arriba.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  KenaProfile _profile = KenaProfile.empty;
  List<RoomHistoryEntry> _recent = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ProfileStore.load();
    final recent = await RoomHistoryStore.all();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _recent = recent.take(4).toList();
    });
  }

  /// "Crear sala" pasa primero por el paywall (instructivo + Kena Pass)
  /// salvo que este dispositivo ya tenga una cuenta con un grupo con
  /// plan/prueba vigente — ver `hasActiveGroupEntitlement`. "Unirme a
  /// una sala" (el otro botón principal) no lo necesita: quien se une
  /// ya está entrando a una sala que otro armó, con su propio plan.
  Future<void> _startCreateRoom() async {
    final alreadyEntitled = await hasActiveGroupEntitlement();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => alreadyEntitled ? const CreateRoomScreen() : const RoomWalkthroughScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarColor = KenaColors.avatarPalette[_profile.avatarColorIndex % KenaColors.avatarPalette.length];

    return KenaBackground(
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Configuración',
                      icon: Icon(Icons.settings_outlined, color: KenaColors.text2),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tu perfil',
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        );
                        _load();
                      },
                      icon: Avatar(
                        color: avatarColor,
                        initial: _profile.name.isEmpty ? '?' : _profile.name[0].toUpperCase(),
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 14),
                      const SignalRings(size: 76),
                      const SizedBox(height: 16),
                      GradientText(
                        'Kena Connect',
                        style: KenaTypography.titleL,
                        gradient: KenaColors.brandGradient,
                      ),
                      const SizedBox(height: 4),
                      Text('Conectados, incluso sin Internet', style: KenaTypography.caption),
                      const SizedBox(height: KenaSpacing.xxl),
                      ValueListenableBuilder<RoomSession?>(
                        valueListenable: ActiveRoomRegistry.current,
                        builder: (context, session, _) {
                          if (session == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: KenaSpacing.md),
                            child: _ActiveRoomCard(session: session),
                          );
                        },
                      ),
                      StaggerIn(
                        index: 0,
                        child: OptionCard(
                          icon: Icons.add_rounded,
                          title: 'Crear una sala',
                          subtitle: 'Red local para tu grupo',
                          onTap: _startCreateRoom,
                        ),
                      ),
                      const SizedBox(height: KenaSpacing.sm),
                      StaggerIn(
                        index: 1,
                        child: OptionCard(
                          icon: Icons.group_add_rounded,
                          title: 'Unirme a una sala',
                          subtitle: 'Con código, QR o cerca tuyo',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const JoinRoomScreen()),
                          ),
                        ),
                      ),
                      if (_recent.isNotEmpty) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(top: KenaSpacing.xl, bottom: KenaSpacing.sm, left: 2),
                            child: Text('RECIENTES', style: KenaTypography.label),
                          ),
                        ),
                        for (var i = 0; i < _recent.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: KenaSpacing.sm),
                            child: StaggerIn(
                              index: i + 2,
                              child: OptionCard(
                                dense: true,
                                color: Colors.transparent,
                                leading: Icon(Icons.history_rounded, size: 15, color: KenaColors.text3),
                                title: _recent[i].roomName,
                                subtitle: _relativeLabel(_recent[i].timestampMs),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => JoinRoomScreen(prefillCode: _recent[i].code)),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveRoomCard extends StatelessWidget {
  const _ActiveRoomCard({required this.session});

  final RoomSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KenaColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KenaRadius.card),
        border: Border.all(color: KenaColors.accent.withValues(alpha: 0.35)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(KenaRadius.card),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => RoomShellScreen(session: session)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.circle, size: 9, color: KenaColors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SALA ACTIVA', style: KenaTypography.label.copyWith(color: KenaColors.accent)),
                      const SizedBox(height: 2),
                      Text(session.roomName, style: KenaTypography.title.copyWith(fontSize: 15)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: KenaColors.text2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
