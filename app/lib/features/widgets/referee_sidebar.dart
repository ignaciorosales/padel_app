import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:Puntazo/config/app_theme.dart';
import 'package:Puntazo/config/team_selection_service.dart';
import 'package:Puntazo/features/models/scoring_models.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_event.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_state.dart';
import 'package:Puntazo/features/widgets/settings_screen.dart';
import 'package:Puntazo/l10n/app_localizations.dart';

/// Minimalist side panel for the referee.
class RefereeSidebar extends StatelessWidget {
  final ValueNotifier<bool> visibleNotifier;

  const RefereeSidebar({super.key, required this.visibleNotifier});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final teamService = context.read<TeamSelectionService>();
    final team1Name = teamService.getTeam1()?.displayName ?? l10n.team1Default;
    final team2Name = teamService.getTeam2()?.displayName ?? l10n.team2Default;

    return ValueListenableBuilder<bool>(
      valueListenable: visibleNotifier,
      builder: (context, isVisible, _) {
        if (!isVisible) return const SizedBox.shrink();

        return Align(
          alignment: Alignment.centerRight,
          child: _SidebarContent(
            team1: team1Name,
            team2: team2Name,
            visibleNotifier: visibleNotifier,
          ),
        );
      },
    );
  }
}

class _SidebarContent extends StatelessWidget {
  final String team1, team2;
  final ValueNotifier<bool> visibleNotifier;

  const _SidebarContent({
    required this.team1,
    required this.team2,
    required this.visibleNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<ScoringBloc>();
    final padelTheme = context.padelTheme;

    return Card(
      margin: EdgeInsets.zero,
      color: padelTheme.sidebarBackground,
      elevation: 8,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
      ),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 120,
        ), // Ancho aumentado para acomodar etiquetas
        height: double.infinity,
        child: BlocBuilder<ScoringBloc, ScoringState>(
          buildWhen: (p, n) => p.match != n.match,
          builder: (_, state) {
            final settings = state.match.settings;
            final golden = settings.goldenPoint;

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),

                  // Botón de configuración prominente al inicio
                  _SettingsButton(
                    onPressed: () {
                      visibleNotifier.value = false; // Cerrar sidebar
                      SettingsScreen.open(context);
                    },
                  ),

                  const SizedBox(height: 8),

                  // Botones de puntuación
                  _SidebarButton(
                    label: team1,
                    icon: Icons.add,
                    color: padelTheme.teamBlueColor,
                    onPressed:
                        () => bloc.add(const ScoringEvent.pointFor(Team.blue)),
                  ),
                  _SidebarButton(
                    label: team2,
                    icon: Icons.add,
                    color: padelTheme.teamRedColor,
                    onPressed:
                        () => bloc.add(const ScoringEvent.pointFor(Team.red)),
                  ),

                  Divider(
                    height: 1,
                    indent: 8,
                    endIndent: 8,
                    color: padelTheme.sidebarDivider,
                  ),

                  // Sección de acciones
                  _SectionTitle(title: l10n.actionsSection),

                  // Botones de utilidad
                  _SidebarIconButton(
                    icon: Icons.undo,
                    tooltip: l10n.undoPoint,
                    label: l10n.undo,
                    onPressed: () => bloc.add(const ScoringEvent.undo()),
                  ),
                  _SidebarIconButton(
                    icon: Icons.redo,
                    tooltip: l10n.redoPoint,
                    label: l10n.redo,
                    onPressed: () => bloc.add(const ScoringEvent.redo()),
                  ),
                  _SidebarIconButton(
                    icon: Icons.sports_tennis,
                    tooltip: l10n.changeServer,
                    label: l10n.serve,
                    onPressed: () {
                      // Cambiar servidor - lógica pendiente
                    },
                  ),

                  const Divider(height: 1, indent: 8, endIndent: 8),

                  // Sección de reglas
                  _SectionTitle(title: l10n.rulesSection),

                  // Configuración de Punto Decisivo (40-40)
                  _SidebarToggleButton(
                    icon: golden ? Icons.star : Icons.star_border,
                    tooltip:
                        golden
                            ? l10n.changeToAdvantage
                            : l10n.changeToGoldenPoint,
                    label: golden ? l10n.goldenPointOn : l10n.goldenPointOff,
                    isActive: golden,
                    onPressed:
                        () => bloc.add(ScoringEvent.toggleGoldenPoint(!golden)),
                  ),

                  // Explicación breve del punto de oro
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 2.0,
                    ),
                    child: Text(
                      golden
                          ? l10n.goldenPointExplanation
                          : l10n.advantageExplanation,
                      style: TextStyle(
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const Divider(height: 16, indent: 8, endIndent: 8),

                  // Configuración del Set Decisivo (3er set)
                  _SidebarToggleButton(
                    icon: Icons.looks_3,
                    tooltip:
                        settings.tieBreakAtGames == 1
                            ? l10n.changeToComplete
                            : l10n.changeToSuperTB,
                    label:
                        settings.tieBreakAtGames == 1
                            ? l10n.thirdSetSuperTB
                            : l10n.thirdSetComplete,
                    isActive: settings.tieBreakAtGames == 1,
                    onPressed:
                        () => bloc.add(
                          ScoringEvent.toggleTieBreakGames(
                            settings.tieBreakAtGames == 6 ? 1 : 6,
                          ),
                        ),
                  ),

                  // Explicación breve del set decisivo
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 2.0,
                    ),
                    child: Text(
                      settings.tieBreakAtGames == 1
                          ? l10n.superTBExplanation
                          : l10n.completeSetExplanation,
                      style: TextStyle(
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Solo mostramos información sobre TB regular si jugamos set completo
                  if (settings.tieBreakAtGames != 1) ...[
                    const Divider(height: 16, indent: 8, endIndent: 8),

                    // Información sobre el Tie-Break en 6-6
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 6.0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sports_score,
                            size: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.8),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              l10n.tieBreakAt66,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.8),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Divider(height: 16, indent: 8, endIndent: 8),

                  // Botón de nuevo partido
                  _SidebarDangerButton(
                    icon: Icons.restart_alt,
                    label: l10n.newMatch,
                    onPressed: () => _confirmNewMatch(context, l10n),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Botón prominente de configuración
class _SettingsButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _SettingsButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(44),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.tune, size: 18),
        label: Text(l10n.settingsTitle),
      ),
    );
  }
}

/// Botón de acción principal para el panel lateral
class _SidebarButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _SidebarButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor:
              isDark ? color.withOpacity(0.5) : color.withOpacity(0.8),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(46),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

/// Botón de icono para acciones secundarias
class _SidebarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final String? label;
  final VoidCallback onPressed;

  const _SidebarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
      child: Tooltip(
        message: tooltip,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(icon),
              onPressed: onPressed,
              style: IconButton.styleFrom(
                backgroundColor:
                    isDark
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withOpacity(0.3),
                foregroundColor: Theme.of(context).colorScheme.primary,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            if (label != null)
              Text(
                label!,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Botón toggle para configuraciones booleanas
class _SidebarToggleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final String? label;
  final bool isActive;
  final VoidCallback onPressed;

  const _SidebarToggleButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onPressed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
      child: Tooltip(
        message: tooltip,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(icon),
              onPressed: onPressed,
              style: IconButton.styleFrom(
                backgroundColor:
                    isActive
                        ? (isDark
                            ? Theme.of(context).colorScheme.tertiaryContainer
                            : Theme.of(
                              context,
                            ).colorScheme.tertiary.withOpacity(0.2))
                        : (isDark
                            ? Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest
                            : Theme.of(context).colorScheme.surfaceVariant),
                foregroundColor:
                    isActive
                        ? (isDark
                            ? Theme.of(context).colorScheme.onTertiaryContainer
                            : Theme.of(context).colorScheme.tertiary)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                side: BorderSide(
                  color:
                      isActive
                          ? Theme.of(
                            context,
                          ).colorScheme.tertiary.withOpacity(0.5)
                          : Theme.of(
                            context,
                          ).colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            if (label != null)
              Text(
                label!,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Botón de peligro (negro) para acciones destructivas
class _SidebarDangerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _SidebarDangerButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dangerColor = const Color(0xFFB71C1C);

    return Padding(
      padding: const EdgeInsets.all(6),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor:
              isDark
                  ? dangerColor.withOpacity(0.5)
                  : dangerColor.withOpacity(0.9),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(40),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
      ),
    );
  }
}

Future<void> _confirmNewMatch(
  BuildContext context,
  AppLocalizations l10n,
) async {
  final bloc = context.read<ScoringBloc>();
  final ok = await showDialog<bool>(
    context: context,
    builder:
        (_) => AlertDialog(
          title: Text(l10n.newMatchConfirmTitle),
          content: Text(l10n.newMatchConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB71C1C),
                foregroundColor: Colors.white,
              ),
              child: Text(
                l10n.yesReset,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
  );
  if (ok == true) {
    // Resetear estado de swap al iniciar nuevo partido
    bloc.add(const ScoringEvent.resetSwap());
    bloc.add(const ScoringEvent.newMatch());
  }
}

/// Widget for section titles
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 10, bottom: 2),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: Colors.white.withOpacity(0.6),
        ),
      ),
    );
  }
}
