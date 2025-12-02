import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_event.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_state.dart';
import 'package:Puntazo/main.dart' show ThemeController; // theme controller
import 'package:Puntazo/features/models/scoring_models.dart'; // Para MatchSettings

Future<void> showMatchSettingsSheet(BuildContext context) async {

  return showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return WillPopScope(
        onWillPop: () async { return true; },
        child: BlocBuilder<ScoringBloc, ScoringState>(
          builder: (_, state) {
            final s = state.match.settings;

            // Helpers to despachar cambios
            void setTbGames(int games) =>
                context.read<ScoringBloc>().add(ScoringEvent.toggleTieBreakGames(games));
            void setGolden(bool v) =>
                context.read<ScoringBloc>().add(ScoringEvent.toggleGoldenPoint(v));

            // NOTA: tu Bloc ya maneja tieBreakTarget al calcular el cierre de TB.
            void setTieBreakTarget(int v) {
              try {
                context.read<ScoringBloc>().add(ScoringEvent.toggleTieBreakTarget(v));
              } catch (_) {
                // Quitar esto cuando agregues el evento real.
              }
            }

            final themeCtrl = RepositoryProvider.of<ThemeController>(context);
            final isDark = themeCtrl.current == ThemeMode.dark;

            return Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 8,
                bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.85,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Configuración',
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Cerrar',
                        onPressed: () { 
                          Navigator.of(ctx).maybePop(); 
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Tabs para organizar el contenido
                  Expanded(
                    child: DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          TabBar(
                            tabs: const [
                              Tab(
                                icon: Icon(Icons.sports_tennis),
                                text: 'Reglas',
                              ),
                              Tab(
                                icon: Icon(Icons.settings),
                                text: 'Apariencia',
                              ),
                            ],
                            labelColor: Theme.of(ctx).colorScheme.primary,
                            unselectedLabelColor: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.6),
                            indicatorSize: TabBarIndicatorSize.tab,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Contenido de las pestañas
                          Expanded(
                            child: TabBarView(
                              children: [
                                // ===== TAB 1: REGLAS DEL PARTIDO =====
                                _RulesTab(
                                  settings: s,
                                  setTbGames: setTbGames,
                                  setTieBreakTarget: setTieBreakTarget,
                                  setGolden: setGolden,
                                ),
                                
                                // ===== TAB 2: APARIENCIA =====
                                _AppearanceTab(
                                  isDark: isDark,
                                  themeCtrl: themeCtrl,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Botones de acción - FOCUSABLES para control remoto
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: ctx,
                              builder: (dialogCtx) => AlertDialog(
                                title: const Text('Restablecer reglas'),
                                content: const Text(
                                  '¿Estás seguro de que quieres restablecer todas las reglas a los valores por defecto?\n\n'
                                  '• Tie-break en 6-6 (sets normales)\n'
                                  '• Ventaja/Desventaja en 40-40',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(dialogCtx).pop(false),
                                    child: const Text('Cancelar'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.of(dialogCtx).pop(true),
                                    child: const Text('Restablecer'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              setTbGames(6); // Tie-break en 6-6 (set normal)
                              setGolden(false); // Ventaja/Desventaja en 40-40
                            }
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Restablecer'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () { Navigator.of(ctx).maybePop(); },
                          icon: const Icon(Icons.check),
                          label: const Text('Cerrar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            );
          },
        ),
      );
    },
  );
}

// =======================================================================
// Widget reutilizable para cajas de información
// =======================================================================
class _InfoBox extends StatelessWidget {
  final String text;

  const _InfoBox({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================================
// Widget para la pestaña de Reglas
// =======================================================================
class _RulesTab extends StatelessWidget {
  final MatchSettings settings;
  final Function(int) setTbGames;
  final Function(int) setTieBreakTarget;
  final Function(bool) setGolden;

  const _RulesTab({
    required this.settings,
    required this.setTbGames,
    required this.setTieBreakTarget,
    required this.setGolden,
  });
  
  // Determina si un set está completado (ganado por algún equipo)
  bool _isSetCompleted(SetScore set) {
    final a = set.blueGames, b = set.redGames;
    
    // CORRECCIÓN: Usar siempre 6 como valor efectivo para sets normales
    // Si tieBreakAtGames es 1, esto indica Super TB para el 3er set, pero
    // para verificar si un set normal está completo, siempre usamos 6
    final effectiveTbGames = settings.tieBreakAtGames == 1 ? 6 : settings.tieBreakAtGames;
    
    // CORRECCIÓN: Ahora aplicamos correctamente las reglas de finalización de set en pádel
    
    // Regla 1: Victoria cuando un jugador alcanza 6 juegos con ventaja de 2 o más
    // Ejemplo: 6-4, 6-3, 6-0
    if ((a >= 6 || b >= 6) && (a - b).abs() >= 2) return true;
    
    // Regla 2: Victoria cuando el marcador llega a 7-5 o 5-7 (un jugador alcanza 7 con ventaja de 2)
    if ((a == 7 && b == 5) || (a == 5 && b == 7)) return true;
    
    // Regla 3: Victoria tras tie-break (7-6 o 6-7)
    if (a == effectiveTbGames + 1 && b == effectiveTbGames) return true;
    if (b == effectiveTbGames + 1 && a == effectiveTbGames) return true;
    
    // Caso límite: Si alguno alcanzó 8 o más juegos, el set debe terminar
    if (a >= 8 || b >= 8) return true;
    
    // Set no completado
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Configuración de Punto Decisivo (40-40)
        Text('Punto decisivo (40–40)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Qué sucede cuando ambos equipos llegan a 40-40'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: settings.goldenPoint
                    ? OutlinedButton(
                        onPressed: () => setGolden(false),
                        child: const Text('Ventaja/Desventaja'),
                      )
                    : FilledButton(
                        onPressed: () => setGolden(false),
                        child: const Text('Ventaja/Desventaja'),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: settings.goldenPoint
                    ? FilledButton(
                        onPressed: () => setGolden(true),
                        child: const Text('Punto de oro'),
                      )
                    : OutlinedButton(
                        onPressed: () => setGolden(true),
                        child: const Text('Punto de oro'),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _InfoBox(
            text: settings.goldenPoint
                ? 'En 40-40, un único punto decide el juego (formato WPT)'
                : 'En 40-40, se juega Ventaja/Desventaja hasta ganar por 2 puntos',
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Configuración del Set Decisivo (3er set)
          Text('Set decisivo (3er set)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Formato del tercer set cuando se llega a 1-1 en sets'),
          const SizedBox(height: 6),
          
          // Verificar si ya estamos en el tercer set
          BlocBuilder<ScoringBloc, ScoringState>(
            builder: (_, state) {
              final match = state.match;
              
              // Verificar si estamos realmente en un tercer set activo
              final isInThirdSet = match.currentSetIndex == 2 && 
                                  match.sets.length > 2 && 
                                  !_isSetCompleted(match.sets[2]);
              
              // Verificar si estamos en un set incompleto que no es el tercero
              final bool isInIncompleteSet = match.currentSetIndex < 2 && 
                  match.sets.isNotEmpty && 
                  !_isSetCompleted(match.currentSet);
              
              if (isInThirdSet) {
                // Si estamos en el tercer set, mostrar advertencia sobre el reseteo de puntos
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: settings.tieBreakAtGames == 1
                              ? OutlinedButton(
                                  onPressed: () => setTbGames(6),
                                  child: const Text('Set completo'),
                                )
                              : FilledButton(
                                  onPressed: () => setTbGames(6),
                                  child: const Text('Set completo'),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: settings.tieBreakAtGames == 1
                              ? FilledButton(
                                  onPressed: () => setTbGames(1),
                                  child: const Text('Súper TB a 10'),
                                )
                              : OutlinedButton(
                                  onPressed: () => setTbGames(1),
                                  child: const Text('Súper TB a 10'),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _InfoBox(
                      text: 'Estás cambiando el formato del tercer set mientras está en progreso. La puntuación del juego actual se reseteará a 0-0.',
                    ),
                  ],
                );
              } else if (isInIncompleteSet) {
                // Si estamos en medio de un set incompleto (1ro o 2do), mostrar que la configuración
                // se aplicará solo al tercer set cuando se llegue a él
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: settings.tieBreakAtGames == 1
                              ? OutlinedButton(
                                  onPressed: () => setTbGames(6),
                                  child: const Text('Set completo'),
                                )
                              : FilledButton(
                                  onPressed: () => setTbGames(6),
                                  child: const Text('Set completo'),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: settings.tieBreakAtGames == 1
                              ? FilledButton(
                                  onPressed: () => setTbGames(1),
                                  child: const Text('Súper TB a 10'),
                                )
                              : OutlinedButton(
                                  onPressed: () => setTbGames(1),
                                  child: const Text('Súper TB a 10'),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _InfoBox(
                      text: 'Esta configuración se aplicará cuando se llegue al tercer set. El set ${match.currentSetIndex + 1} en curso debe completarse normalmente.',
                    ),
                  ],
                );
              } else {
                // Mostrar selector normal con información sobre el Super Tie-Break
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: settings.tieBreakAtGames == 1
                              ? OutlinedButton(
                                  onPressed: () => setTbGames(6),
                                  child: const Text('Set completo'),
                                )
                              : FilledButton(
                                  onPressed: () => setTbGames(6),
                                  child: const Text('Set completo'),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: settings.tieBreakAtGames == 1
                              ? FilledButton(
                                  onPressed: () => setTbGames(1),
                                  child: const Text('Súper TB a 10'),
                                )
                              : OutlinedButton(
                                  onPressed: () => setTbGames(1),
                                  child: const Text('Súper TB a 10'),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _InfoBox(
                      text: 'El Super Tie-Break se juega a 10 puntos (con diferencia de 2) en lugar de un set completo en el tercer set.',
                    ),
                  ],
                );
              }
            },
          ),

          // Solo mostramos información sobre el tie-break regular si el 3er set es completo
          if (settings.tieBreakAtGames != 1) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            
          // Tie-break en 6-6 (Set normal)
            Text('Tie-break en 6-6', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('En los sets normales, cuando se llega a 6-6, se juega un tie-break a 7 puntos (con diferencia de 2)'),
            const SizedBox(height: 10),
            _InfoBox(
              text: 'El tie-break se juega hasta que un jugador alcanza 7 puntos con una diferencia de al menos 2 puntos.',
            ),
          ],
        ],
    );
  }
}

// =======================================================================
// Widget para la pestaña de Apariencia
// =======================================================================
class _AppearanceTab extends StatelessWidget {
  final bool isDark;
  final ThemeController themeCtrl;

  const _AppearanceTab({
    required this.isDark,
    required this.themeCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tema de la aplicación', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        
        // Selector de tema
        Row(
          children: [
            Expanded(
              child: isDark
                  ? OutlinedButton.icon(
                      onPressed: () => themeCtrl.set(ThemeMode.light),
                      icon: const Icon(Icons.light_mode),
                      label: const Text('Claro'),
                    )
                  : FilledButton.icon(
                      onPressed: () => themeCtrl.set(ThemeMode.light),
                      icon: const Icon(Icons.light_mode),
                      label: const Text('Claro'),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: isDark
                  ? FilledButton.icon(
                      onPressed: () => themeCtrl.set(ThemeMode.dark),
                      icon: const Icon(Icons.dark_mode),
                      label: const Text('Oscuro'),
                    )
                  : OutlinedButton.icon(
                      onPressed: () => themeCtrl.set(ThemeMode.dark),
                      icon: const Icon(Icons.dark_mode),
                      label: const Text('Oscuro'),
                    ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        _InfoBox(
          text: 'El tema seleccionado se aplicará inmediatamente a toda la aplicación.',
        ),
      ],
    );
  }
}
