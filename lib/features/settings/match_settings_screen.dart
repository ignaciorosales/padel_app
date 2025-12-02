import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:Puntazo/config/app_config.dart';
import 'package:Puntazo/config/team_selection_service.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_event.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_state.dart';
import 'package:Puntazo/main.dart' show ThemeController;
import 'package:Puntazo/features/models/scoring_models.dart';

/// Pantalla completa de configuración - optimizada para Android TV
class MatchSettingsScreen extends StatefulWidget {
  const MatchSettingsScreen({super.key});

  @override
  State<MatchSettingsScreen> createState() => _MatchSettingsScreenState();
}

class _MatchSettingsScreenState extends State<MatchSettingsScreen> {
  int _selectedSection = 0; // 0: Reglas, 1: Apariencia

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _changeSection(int index) {
    setState(() => _selectedSection = index);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Configuración del Partido'),
          centerTitle: true,
        ),
        body: Row(
          children: [
            // Panel lateral izquierdo con las secciones (20%)
            Container(
              width: MediaQuery.of(context).size.width * 0.2,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionButton(
                    icon: Icons.sports_tennis,
                    label: 'Reglas',
                    isSelected: _selectedSection == 0,
                    onPressed: () => _changeSection(0),
                  ),
                  _SectionButton(
                    icon: Icons.settings,
                    label: 'Apariencia',
                    isSelected: _selectedSection == 1,
                    onPressed: () => _changeSection(1),
                  ),
                  const Spacer(),
                  // Botón de cerrar
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.check),
                      label: const Text('Cerrar'),
                    ),
                  ),
                ],
              ),
            ),

            // Contenido principal (80%)
            Expanded(
              child: BlocBuilder<ScoringBloc, ScoringState>(
                builder: (_, state) {
                  final s = state.match.settings;

                  void setTbGames(int games) =>
                      context.read<ScoringBloc>().add(ScoringEvent.toggleTieBreakGames(games));
                  void setGolden(bool v) =>
                      context.read<ScoringBloc>().add(ScoringEvent.toggleGoldenPoint(v));
                  void setTieBreakTarget(int v) {
                    try {
                      context.read<ScoringBloc>().add(ScoringEvent.toggleTieBreakTarget(v));
                    } catch (_) {}
                  }

                  final themeCtrl = context.read<ThemeController>();
                  final isDark = themeCtrl.current == ThemeMode.dark;

                  // Renderizar contenido según sección seleccionada
                  Widget content;
                  if (_selectedSection == 0) {
                    content = _RulesContent(
                      settings: s,
                      setTbGames: setTbGames,
                      setTieBreakTarget: setTieBreakTarget,
                      setGolden: setGolden,
                    );
                  } else {
                    content = _AppearanceContent(
                      isDark: isDark,
                      themeCtrl: themeCtrl,
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.all(32),
                    child: content,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================================
// Botón focusable mejorado para TV - con efecto visual muy notorio
// =======================================================================
class _TVFocusableButton extends StatefulWidget {
  const _TVFocusableButton({
    required this.onPressed,
    required this.child,
    required this.isSelected,
    this.scrollController,
  });

  final VoidCallback onPressed;
  final Widget child;
  final bool isSelected;
  final ScrollController? scrollController;

  @override
  State<_TVFocusableButton> createState() => _TVFocusableButtonState();
}

class _TVFocusableButtonState extends State<_TVFocusableButton> {
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _hasFocus = _focusNode.hasFocus;
    });
    
    // Auto-scroll cuando el botón recibe focus
    if (_hasFocus && widget.scrollController != null && context.mounted) {
      Future.microtask(() {
        if (context.mounted) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.5, // Centrar el elemento
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _hasFocus ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: _hasFocus
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 4,
                )
              : null,
          boxShadow: _hasFocus
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: widget.isSelected
            ? FilledButton(
                focusNode: _focusNode,
                onPressed: widget.onPressed,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: widget.child,
              )
            : OutlinedButton(
                focusNode: _focusNode,
                onPressed: widget.onPressed,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: widget.child,
              ),
      ),
    );
  }
}

// =======================================================================
// Botón de sección lateral
// =======================================================================
class _SectionButton extends StatefulWidget {
  const _SectionButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  State<_SectionButton> createState() => _SectionButtonState();
}

class _SectionButtonState extends State<_SectionButton> {
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _hasFocus = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: AnimatedScale(
        scale: _hasFocus ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: _hasFocus
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  )
                : null,
            boxShadow: _hasFocus
                ? [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: widget.isSelected
              ? FilledButton.icon(
                  focusNode: _focusNode,
                  onPressed: widget.onPressed,
                  icon: Icon(widget.icon),
                  label: Text(widget.label),
                  style: FilledButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                )
              : OutlinedButton.icon(
                  focusNode: _focusNode,
                  onPressed: widget.onPressed,
                  icon: Icon(widget.icon),
                  label: Text(widget.label),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
        ),
      ),
    );
  }
}

// =======================================================================
// Widget reutilizable para cajas de información
// =======================================================================
class _InfoBox extends StatelessWidget {
  final String text;

  const _InfoBox({required this.text});

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
// Contenido de Reglas
// =======================================================================
class _RulesContent extends StatefulWidget {
  final MatchSettings settings;
  final Function(int) setTbGames;
  final Function(int) setTieBreakTarget;
  final Function(bool) setGolden;

  const _RulesContent({
    required this.settings,
    required this.setTbGames,
    required this.setTieBreakTarget,
    required this.setGolden,
  });

  @override
  State<_RulesContent> createState() => _RulesContentState();
}

class _RulesContentState extends State<_RulesContent> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _isSetCompleted(SetScore set, MatchSettings settings) {
    final a = set.blueGames, b = set.redGames;
    final effectiveTbGames = settings.tieBreakAtGames == 1 ? 6 : settings.tieBreakAtGames;

    if ((a >= 6 || b >= 6) && (a - b).abs() >= 2) return true;
    if ((a == 7 && b == 5) || (a == 5 && b == 7)) return true;
    if (a == effectiveTbGames + 1 && b == effectiveTbGames) return true;
    if (b == effectiveTbGames + 1 && a == effectiveTbGames) return true;
    if (a >= 8 || b >= 8) return true;

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Punto decisivo
          Text('Punto decisivo (40–40)', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(
          'Qué sucede cuando ambos equipos llegan a 40-40',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _TVFocusableButton(
                scrollController: _scrollController,
                onPressed: () => widget.setGolden(false),
                isSelected: !widget.settings.goldenPoint,
                child: const Text('Ventaja/Desventaja', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _TVFocusableButton(
                scrollController: _scrollController,
                onPressed: () => widget.setGolden(true),
                isSelected: widget.settings.goldenPoint,
                child: const Text('Punto de oro', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
          const SizedBox(height: 12),
          _InfoBox(
            text: widget.settings.goldenPoint
                ? 'En 40-40, un único punto decide el juego (formato WPT)'
                : 'En 40-40, se juega Ventaja/Desventaja hasta ganar por 2 puntos',
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 32),

          // Set decisivo
          Text('Set decisivo (3er set)', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            'Formato del tercer set cuando se llega a 1-1 en sets',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),

          BlocBuilder<ScoringBloc, ScoringState>(
            builder: (_, state) {
              final match = state.match;
              final isInThirdSet = match.currentSetIndex == 2 &&
                  match.sets.length > 2 &&
                  !_isSetCompleted(match.sets[2], widget.settings);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _TVFocusableButton(
                          scrollController: _scrollController,
                          onPressed: () => widget.setTbGames(6),
                          isSelected: widget.settings.tieBreakAtGames != 1,
                          child: const Text('Set completo', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _TVFocusableButton(
                          scrollController: _scrollController,
                          onPressed: () => widget.setTbGames(1),
                          isSelected: widget.settings.tieBreakAtGames == 1,
                          child: const Text('Súper TB a 10', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isInThirdSet)
                    _InfoBox(
                      text: 'Estás cambiando el formato del tercer set mientras está en progreso. '
                          'La puntuación del juego actual se reseteará a 0-0.',
                    )
                  else
                    _InfoBox(
                      text: 'El Super Tie-Break se juega a 10 puntos (con diferencia de 2) '
                          'en lugar de un set completo en el tercer set.',
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// =======================================================================
// Contenido de Apariencia
// =======================================================================
class _AppearanceContent extends StatefulWidget {
  final bool isDark;
  final ThemeController themeCtrl;

  const _AppearanceContent({
    required this.isDark,
    required this.themeCtrl,
  });

  @override
  State<_AppearanceContent> createState() => _AppearanceContentState();
}

class _AppearanceContentState extends State<_AppearanceContent> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamService = context.read<TeamSelectionService>();
    final config = context.read<AppConfig>();
    
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tema de la aplicación', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _TVFocusableButton(
                  scrollController: _scrollController,
                  onPressed: () => widget.themeCtrl.set(ThemeMode.light),
                  isSelected: !widget.isDark,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.light_mode),
                      SizedBox(width: 8),
                      Text('Claro', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _TVFocusableButton(
                  scrollController: _scrollController,
                  onPressed: () => widget.themeCtrl.set(ThemeMode.dark),
                  isSelected: widget.isDark,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.dark_mode),
                      SizedBox(width: 8),
                      Text('Oscuro', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoBox(
            text: 'El tema seleccionado se aplicará inmediatamente a toda la aplicación.',
          ),
          
          // =======================================================================
          // NUEVA SECCIÓN: Colores de Equipos
          // =======================================================================
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 32),
          
          Text('Colores de equipos', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            'Selecciona los colores que representarán a cada equipo en el marcador',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          
          // Equipo 1 (Izquierda)
          Text('Equipo 1 (Lado izquierdo)', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ValueListenableBuilder<String>(
            valueListenable: teamService.team1Selection,
            builder: (_, selectedId, __) {
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: config.availableTeams.map((team) {
                  final isSelected = team.id == selectedId;
                  final color = _hexToColor(team.colorHex);
                  
                  return _ColorTile(
                    team: team,
                    color: color,
                    isSelected: isSelected,
                    onPressed: () async {
                      await teamService.setTeam1(team.id);
                      // El tema se reconstruirá automáticamente por el listener en main.dart
                    },
                    scrollController: _scrollController,
                  );
                }).toList(),
              );
            },
          ),
          
          const SizedBox(height: 32),
          
          // Equipo 2 (Derecha)
          Text('Equipo 2 (Lado derecho)', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ValueListenableBuilder<String>(
            valueListenable: teamService.team2Selection,
            builder: (_, selectedId, __) {
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: config.availableTeams.map((team) {
                  final isSelected = team.id == selectedId;
                  final color = _hexToColor(team.colorHex);
                  
                  return _ColorTile(
                    team: team,
                    color: color,
                    isSelected: isSelected,
                    onPressed: () async {
                      await teamService.setTeam2(team.id);
                      // El tema se reconstruirá automáticamente por el listener en main.dart
                    },
                    scrollController: _scrollController,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Color _hexToColor(String hex) {
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16) ?? 0xFF1976D2;
    return Color(v);
  }
}

// =======================================================================
// Widget para cada opción de color de equipo
// =======================================================================
class _ColorTile extends StatefulWidget {
  final TeamDef team;
  final Color color;
  final bool isSelected;
  final VoidCallback onPressed;
  final ScrollController? scrollController;
  
  const _ColorTile({
    required this.team,
    required this.color,
    required this.isSelected,
    required this.onPressed,
    this.scrollController,
  });
  
  @override
  State<_ColorTile> createState() => _ColorTileState();
}

class _ColorTileState extends State<_ColorTile> {
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _hasFocus = _focusNode.hasFocus;
    });
    
    if (_hasFocus && widget.scrollController != null && context.mounted) {
      Future.microtask(() {
        if (context.mounted) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _hasFocus ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: _hasFocus
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 4,
                )
              : widget.isSelected
                  ? Border.all(color: widget.color, width: 3)
                  : Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
          boxShadow: _hasFocus
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : widget.isSelected
                  ? [
                      BoxShadow(
                        color: widget.color.withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            focusNode: _focusNode,
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 140,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Círculo de color
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: widget.isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 32)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  // Nombre del equipo
                  Text(
                    widget.team.displayName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
                      color: widget.isSelected 
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
