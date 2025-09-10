import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text_min/config/app_config.dart';
import 'package:speech_to_text_min/features/models/scoring_models.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_bloc.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_event.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_state.dart';

/// Panel lateral minimalista para el árbitro.
/// Ocupa aproximadamente el 10% del ancho de la pantalla.
class RefereeSidebar extends StatelessWidget {
  final ValueNotifier<bool> visibleNotifier;
  
  const RefereeSidebar({
    super.key,
    required this.visibleNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = context.read<AppConfig>();
    final team1 = cfg.teams.isNotEmpty ? cfg.teams[0].displayName : 'Azul';
    final team2 = cfg.teams.length > 1 ? cfg.teams[1].displayName : 'Rojo';

    return ValueListenableBuilder<bool>(
      valueListenable: visibleNotifier,
      builder: (context, isVisible, _) {
        if (!isVisible) return const SizedBox.shrink();
        
        return _SidebarContent(team1: team1, team2: team2);
      },
    );
  }
}

class _SidebarContent extends StatelessWidget {
  final String team1, team2;
  
  const _SidebarContent({
    required this.team1, 
    required this.team2,
  });

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ScoringBloc>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      margin: EdgeInsets.zero,
      color: isDark 
          ? Colors.black.withOpacity(0.6)
          : Theme.of(context).colorScheme.surface.withOpacity(0.9),
      elevation: 4,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 120), // Ancho aumentado para acomodar etiquetas
        height: double.infinity,
        child: BlocBuilder<ScoringBloc, ScoringState>(
          buildWhen: (p, n) => p.match != n.match,
          builder: (_, state) {
            final settings = state.match.settings;
            final golden = settings.goldenPoint;

            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Encabezado
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    'ÁRBITRO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                
                // Sección de puntuación
                _SectionTitle(title: 'PUNTUACIÓN'),
                
                // Botones de puntuación
                _SidebarButton(
                  label: team1,
                  icon: Icons.add,
                  color: const Color(0xFF1E88E5),
                  onPressed: () => bloc.add(const ScoringEvent.pointFor(Team.blue)),
                ),
                _SidebarButton(
                  label: team2,
                  icon: Icons.add,
                  color: const Color(0xFFE53935),
                  onPressed: () => bloc.add(const ScoringEvent.pointFor(Team.red)),
                ),
                
                const Divider(height: 1, indent: 8, endIndent: 8),
                
                // Sección de acciones
                _SectionTitle(title: 'ACCIONES'),
                
                // Botones de utilidad
                _SidebarIconButton(
                  icon: Icons.undo,
                  tooltip: 'Deshacer punto',
                  label: 'Deshacer',
                  onPressed: () => bloc.add(const ScoringEvent.undo()),
                ),
                _SidebarIconButton(
                  icon: Icons.redo,
                  tooltip: 'Rehacer punto',
                  label: 'Rehacer',
                  onPressed: () => bloc.add(const ScoringEvent.redo()),
                ),
                _SidebarIconButton(
                  icon: Icons.sports_tennis,
                  tooltip: 'Cambiar servidor',
                  label: 'Saque',
                  onPressed: () => bloc.add(const ScoringEvent.bleCommand('cmd:toggle-server')),
                ),
                
                const Divider(height: 1, indent: 8, endIndent: 8),
                
                // Sección de reglas
                _SectionTitle(title: 'REGLAS'),
                
                // Configuración de Punto Decisivo (40-40)
                _SidebarToggleButton(
                  icon: golden ? Icons.star : Icons.star_border,
                  tooltip: golden ? 'Cambiar a Ventaja/Desventaja' : 'Cambiar a Punto de Oro',
                  label: golden ? 'Punto Oro: ON' : 'Punto Oro: OFF',
                  isActive: golden,
                  onPressed: () => bloc.add(ScoringEvent.toggleGoldenPoint(!golden)),
                ),
                
                // Explicación breve del punto de oro
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                  child: Text(
                    golden ? 'En 40-40, un punto decide' : 'En 40-40, jugar ventajas',
                    style: TextStyle(
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const Divider(height: 16, indent: 8, endIndent: 8),
                
                // Configuración del Set Decisivo (3er set)
                _SidebarToggleButton(
                  icon: Icons.looks_3,
                  tooltip: settings.tieBreakAtGames == 1 ? 
                    'Cambiar a set completo' : 'Cambiar a Super TB',
                  label: settings.tieBreakAtGames == 1 ? 
                    '3er Set: Super TB' : '3er Set: Completo',
                  isActive: settings.tieBreakAtGames == 1,
                  onPressed: () => bloc.add(
                    ScoringEvent.toggleTieBreakGames(settings.tieBreakAtGames == 6 ? 1 : 6)
                  ),
                ),
                
                // Explicación breve del set decisivo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                  child: Text(
                    settings.tieBreakAtGames == 1 ? 
                      'Tie-break a 10 pts en vez de 3er set' : 'Set normal con posible TB en 6-6',
                    style: TextStyle(
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                // Solo mostramos información sobre TB regular si jugamos set completo
                if (settings.tieBreakAtGames != 1) ...[
                  const Divider(height: 16, indent: 8, endIndent: 8),
                  
                  // Información sobre el Tie-Break en 6-6
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sports_score,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'En 6-6: Tie-break a 7 puntos',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const Spacer(),
                
                // Botón de nuevo partido
                _SidebarDangerButton(
                  icon: Icons.restart_alt,
                  label: 'Nuevo partido',
                  onPressed: () => _confirmNewMatch(context),
                ),
              ],
            );
          },
        ),
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
          backgroundColor: isDark 
              ? color.withOpacity(0.5)
              : color.withOpacity(0.8),
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
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (label != null)
              Text(
                label!,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
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
                backgroundColor: isActive
                    ? Theme.of(context).colorScheme.tertiaryContainer
                    : Theme.of(context).colorScheme.surfaceVariant,
                foregroundColor: isActive
                    ? Theme.of(context).colorScheme.onTertiaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (label != null)
              Text(
                label!,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Botón de peligro (rojo) para acciones destructivas
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
          backgroundColor: isDark 
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
      ),
    );
  }
}

/// Diálogo de confirmación para nuevo partido
Future<void> _confirmNewMatch(BuildContext context) async {
  final bloc = context.read<ScoringBloc>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Nuevo partido'),
      content: const Text('Esto reinicia el marcador. ¿Continuar?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false), 
          child: const Text('Cancelar')
        ),
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

/// Widget para mostrar títulos de sección
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
          color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
        ),
      ),
    );
  }
}
