import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:Puntazo/config/app_theme.dart';
import 'package:Puntazo/config/team_selection_service.dart';
import 'package:Puntazo/features/models/scoring_models.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_event.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_state.dart';
import 'package:Puntazo/features/widgets/scoreboard.dart'; // ▲ Para telemetría UI

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
    final teamService = context.read<TeamSelectionService>();
    final team1Name = teamService.getTeam1()?.displayName ?? 'Equipo 1';
    final team2Name = teamService.getTeam2()?.displayName ?? 'Equipo 2';

    return ValueListenableBuilder<bool>(
      valueListenable: visibleNotifier,
      builder: (context, isVisible, _) {
        if (!isVisible) return const SizedBox.shrink();
        
        return Align(
          alignment: Alignment.centerRight,
          child: _SidebarContent(team1: team1Name, team2: team2Name),
        );
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
    final padelTheme = context.padelTheme;
    
    return Card(
      margin: EdgeInsets.zero,
      color: padelTheme.sidebarBackground,
      elevation: 8,
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

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                const SizedBox(height: 12),
                // Botones de puntuación
                _SidebarButton(
                  label: team1,
                  icon: Icons.add,
                  color: padelTheme.teamBlueColor,
                  onPressed: () => bloc.add(const ScoringEvent.pointFor(Team.blue)),
                ),
                _SidebarButton(
                  label: team2,
                  icon: Icons.add,
                  color: padelTheme.teamRedColor,
                  onPressed: () => bloc.add(const ScoringEvent.pointFor(Team.red)),
                ),
                
                Divider(height: 1, indent: 8, endIndent: 8, color: padelTheme.sidebarDivider),
                
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
                  onPressed: () {
                    // Cambiar servidor - lógica pendiente
                  },
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
                
                const SizedBox(height: 16), // Espaciado antes del botón de peligro
                
                // ▲ NUEVO: Botón de TEST UI para medir performance sin BLE
                const Divider(height: 1, indent: 8, endIndent: 8),
                _SidebarIconButton(
                  icon: Icons.speed,
                  tooltip: 'Test de rendimiento UI',
                  label: 'TEST UI',
                  onPressed: () => _runUIPerformanceTest(context),
                ),
                
                const SizedBox(height: 8),
                
                // Botón de nuevo partido
                _SidebarDangerButton(
                  icon: Icons.restart_alt,
                  label: 'Nuevo partido',
                  onPressed: () => _confirmNewMatch(context),
                ),
                const SizedBox(height: 12), // Padding inferior
              ],
            ),
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
                backgroundColor: isDark 
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
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
                backgroundColor: isActive
                    ? (isDark 
                        ? Theme.of(context).colorScheme.tertiaryContainer
                        : Theme.of(context).colorScheme.tertiary.withOpacity(0.2))
                    : (isDark
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : Theme.of(context).colorScheme.surfaceVariant),
                foregroundColor: isActive
                    ? (isDark
                        ? Theme.of(context).colorScheme.onTertiaryContainer
                        : Theme.of(context).colorScheme.tertiary)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                side: BorderSide(
                  color: isActive
                      ? Theme.of(context).colorScheme.tertiary.withOpacity(0.5)
                      : Theme.of(context).colorScheme.outline.withOpacity(0.2),
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
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
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

/// ========== TEST DE RENDIMIENTO UI ==========
/// Ejecuta múltiples puntos y muestra estadísticas de rebuilds
Future<void> _runUIPerformanceTest(BuildContext context) async {
  final bloc = context.read<ScoringBloc>();
  
  // Resetear telemetría UI
  Scoreboard.resetUIStats();
  
  // Mostrar diálogo de inicio
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.speed, color: Colors.purple),
          SizedBox(width: 8),
          Text('Test de Rendimiento UI'),
        ],
      ),
      content: const Text(
        'Este test ejecutará 10 puntos alternados (azul/rojo) '
        'y medirá cuántas veces se redibuja cada widget.\n\n'
        '✅ Objetivo: Solo 1-2 rebuilds por punto\n'
        '⚠️ Problema: 50+ rebuilds por punto',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: Colors.purple),
          child: const Text('Iniciar Test'),
        ),
      ],
    ),
  );
  
  if (confirmed != true) return;
  
  // Ejecutar test: 10 puntos alternados
  for (int i = 0; i < 10; i++) {
    final team = i.isEven ? Team.blue : Team.red;
    bloc.add(ScoringEvent.pointFor(team));
    
    // Pequeño delay para simular comportamiento real
    await Future.delayed(const Duration(milliseconds: 50));
  }
  
  // Esperar a que se completen todos los rebuilds
  await Future.delayed(const Duration(milliseconds: 200));
  
  // Obtener estadísticas
  final stats = Scoreboard.getUIStats();
  final total = stats.values.fold<int>(0, (sum, val) => sum + val);
  final bluePoints = stats['blue_points'] ?? 0;
  final redPoints = stats['red_points'] ?? 0;
  final setGames = stats['set_games'] ?? 0;
  final header = stats['header'] ?? 0;
  final status = stats['status'] ?? 0;
  final background = stats['background'] ?? 0;
  
  // Determinar veredicto
  final String veredicto;
  final Color verdictColor;
  final IconData verdictIcon;
  
  if (total <= 20) {
    veredicto = '🎉 EXCELENTE';
    verdictColor = Colors.green;
    verdictIcon = Icons.check_circle;
  } else if (total <= 50) {
    veredicto = '✅ BUENO';
    verdictColor = Colors.lightGreen;
    verdictIcon = Icons.thumb_up;
  } else if (total <= 100) {
    veredicto = '⚠️ MEJORABLE';
    verdictColor = Colors.orange;
    verdictIcon = Icons.warning;
  } else {
    veredicto = '❌ PROBLEMÁTICO';
    verdictColor = Colors.red;
    verdictIcon = Icons.error;
  }
  
  // Mostrar resultados
  if (!context.mounted) return;
  
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Row(
        children: [
          Icon(verdictIcon, color: verdictColor),
          const SizedBox(width: 8),
          Text(veredicto, style: TextStyle(color: verdictColor)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '10 puntos ejecutados',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text('REBUILDS POR WIDGET:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildStatRow('Puntos Azules', bluePoints, 5, 10),
            _buildStatRow('Puntos Rojos', redPoints, 5, 10),
            _buildStatRow('Set Actual', setGames, 0, 5),
            _buildStatRow('Header', header, 0, 5),
            _buildStatRow('Status', status, 0, 5),
            _buildStatRow('Fondo', background, 0, 0, shouldBeZero: true),
            const Divider(height: 24),
            _buildStatRow('TOTAL', total, 20, 50, isTotal: true),
            const SizedBox(height: 16),
            if (total <= 20)
              const Text(
                '✨ Optimización perfecta! Solo se redibujan los widgets que cambian.',
                style: TextStyle(color: Colors.green, fontSize: 12),
              )
            else if (total <= 50)
              const Text(
                '👍 Buen rendimiento. Hay algunos rebuilds extra pero aceptable.',
                style: TextStyle(color: Colors.lightGreen, fontSize: 12),
              )
            else
              const Text(
                '⚠️ Demasiados rebuilds. Revisar BlocSelector y RepaintBoundary.',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            if (background > 1)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '🚨 CRÍTICO: El fondo se redibujó múltiples veces! '
                  'Verificar RepaintBoundary.',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Scoreboard.resetUIStats();
            Navigator.pop(context);
          },
          child: const Text('Resetear'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

Widget _buildStatRow(String label, int value, int goodThreshold, int badThreshold, {bool isTotal = false, bool shouldBeZero = false}) {
  final Color color;
  
  if (shouldBeZero) {
    color = value <= 1 ? Colors.green : Colors.red;
  } else if (isTotal) {
    if (value <= goodThreshold) {
      color = Colors.green;
    } else if (value <= badThreshold) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }
  } else {
    if (value <= goodThreshold) {
      color = Colors.green;
    } else if (value <= badThreshold) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }
  }
  
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Text(
            '$value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: isTotal ? 18 : 14,
            ),
          ),
        ),
      ],
    ),
  );
}

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
          color: Colors.white.withOpacity(0.6),
        ),
      ),
    );
  }
}
