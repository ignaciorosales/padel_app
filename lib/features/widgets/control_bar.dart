import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:Puntazo/config/app_config.dart';
import 'package:Puntazo/features/models/scoring_models.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_event.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_state.dart';

/// Tournament mode: simple, obvious controls for a referee (no hotkeys, no hints).
class ControlBar extends StatelessWidget {
  const ControlBar({super.key});

  @override
  Widget build(BuildContext context) {
    final cfg = context.read<AppConfig>();
    final team1 = cfg.teams.isNotEmpty ? cfg.teams[0].displayName : 'Azul';
    final team2 = cfg.teams.length > 1 ? cfg.teams[1].displayName : 'Rojo';

    return _Panel(team1: team1, team2: team2);
  }
}

class _Panel extends StatelessWidget {
  final String team1, team2;
  const _Panel({required this.team1, required this.team2});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ScoringBloc>();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: BlocBuilder<ScoringBloc, ScoringState>(
          buildWhen: (p, n) => p.match != n.match,
          builder: (_, state) {
            final settings = state.match.settings;
            final golden = settings.goldenPoint;
            final tbGames = settings.tieBreakAtGames;

            return LayoutBuilder(
              builder: (_, c) {
                final tight = c.maxWidth < 760;
                final btnHeight = tight ? 56.0 : 64.0;
                final bigBtnHeight = tight ? 72.0 : 84.0;

                final primaryRow = [
                  _BigActionButton(
                    label: 'Punto $team1',
                    icon: Icons.add,
                    color: const Color(0xFF1E88E5),
                    onPressed: () => bloc.add(const ScoringEvent.pointFor(Team.blue)),
                    height: bigBtnHeight,
                  ),
                  _BigActionButton(
                    label: 'Punto $team2',
                    icon: Icons.add,
                    color: const Color(0xFFE53935),
                    onPressed: () => bloc.add(const ScoringEvent.pointFor(Team.red)),
                    height: bigBtnHeight,
                  ),
                ];

                final utilityRow = [
                  _ActionButton(
                    label: 'Deshacer',
                    icon: Icons.undo,
                    onPressed: () => bloc.add(const ScoringEvent.undo()),
                    height: btnHeight,
                  ),
                  _ActionButton(
                    label: 'Rehacer',
                    icon: Icons.redo,
                    onPressed: () => bloc.add(const ScoringEvent.redo()),
                    height: btnHeight,
                  ),
                  _ActionButton(
                    label: 'Saque (toggle)',
                    icon: Icons.sports_tennis,
                    onPressed: () => bloc.add(const ScoringEvent.bleCommand('cmd:toggle-server')),
                    height: btnHeight,
                  ),
                  _DangerButton(
                    label: 'Nuevo partido',
                    icon: Icons.restart_alt,
                    onPressed: () => _confirmNewMatch(context),
                    height: btnHeight,
                  ),
                ];

                final rulesRow = [
                  _ToggleChip(
                    selected: golden,
                    onTap: () => bloc.add(ScoringEvent.toggleGoldenPoint(!golden)),
                    labelOn: 'Oro ON',
                    labelOff: 'Oro OFF',
                    iconOn: Icons.star,
                    iconOff: Icons.star_border,
                  ),
                  _SegmentedTb(
                    selected: tbGames,
                    onChanged: (v) => bloc.add(ScoringEvent.toggleTieBreakGames(v)),
                  ),
                ];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RowWrap(children: primaryRow),
                    const SizedBox(height: 10),
                    _RowWrap(children: utilityRow),
                    const SizedBox(height: 6),
                    const Divider(height: 20),
                    _RowWrap(children: rulesRow),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// ---------- Controls (building blocks) ----------

class _RowWrap extends StatelessWidget {
  final List<Widget> children;
  const _RowWrap({required this.children});
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

class _BigActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final double height;
  final Color color;
  const _BigActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220),
      child: SizedBox(
        height: height,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            // Usamos un color más opaco y con mayor contraste
            backgroundColor: isDark 
                ? color.withOpacity(0.5) // Más brillante en modo oscuro
                : color.withOpacity(0.8), // Más oscuro en modo claro
            foregroundColor: isDark 
                ? Colors.white 
                : Colors.white, // Texto blanco en ambos modos para mejorar contraste
            padding: const EdgeInsets.symmetric(horizontal: 16),
            textStyle: const TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.w800,
              shadows: [Shadow(color: Colors.black54, blurRadius: 2)], // Sombra para mejorar legibilidad
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onPressed,
          icon: Icon(icon, size: 24), // Icono ligeramente más grande
          label: Text(label),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final double height;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final double height;
  const _DangerButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dangerColor = const Color(0xFFB71C1C);
    return SizedBox(
      height: height,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          // Color más opaco para mayor visibilidad
          backgroundColor: isDark 
              ? dangerColor.withOpacity(0.5) // Más brillante en modo oscuro
              : dangerColor.withOpacity(0.9), // Más oscuro en modo claro
          foregroundColor: Colors.white, // Texto blanco para mejor contraste
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            shadows: [Shadow(color: Colors.black54, blurRadius: 2)], // Sombra para legibilidad
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(label),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final String labelOn, labelOff;
  final IconData iconOn, iconOff;
  const _ToggleChip({
    required this.selected,
    required this.onTap,
    required this.labelOn,
    required this.labelOff,
    required this.iconOn,
    required this.iconOff,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(selected ? iconOn : iconOff, size: 18),
          const SizedBox(width: 6),
          Text(selected ? labelOn : labelOff),
        ],
      ),
    );
  }
}

class _SegmentedTb extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _SegmentedTb({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 6, label: Text('TB a 6–6')),
        ButtonSegment(value: 12, label: Text('TB a 12–12')),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// ---------- Helpers ----------

Future<void> _confirmNewMatch(BuildContext context) async {
  final bloc = context.read<ScoringBloc>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Nuevo partido'),
      content: const Text('Esto reinicia el marcador. ¿Continuar?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true), 
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB71C1C),
            foregroundColor: Colors.white,
          ),
          child: const Text('Sí, reiniciar', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
  if (ok == true) {
    bloc.add(const ScoringEvent.newMatch());
  }
}
