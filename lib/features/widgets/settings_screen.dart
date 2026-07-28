import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:Puntazo/config/app_config.dart';
import 'package:Puntazo/config/box_pairing_service.dart';
import 'package:Puntazo/config/debug_settings_cubit.dart';
import 'package:Puntazo/config/scoreboard_font_cubit.dart';
import 'package:Puntazo/config/team_selection_service.dart';
import 'package:Puntazo/config/theme_cubit.dart';
import 'package:Puntazo/features/models/scoring_models.dart' show MatchMode, Team;
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_event.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_state.dart';
import 'package:Puntazo/l10n/app_localizations.dart';

// Color para el FOCUS/cursor - azul claro visible
const _focusBorderColor = Color(0xFF42A5F5); // Azul entre skyblue y blue
const _focusBorderWidth = 3.0;

/// Pantalla completa de configuración con tabs
/// Optimizada para navegación con control remoto de TV (d-pad)
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  /// Abre Settings como pantalla completa
  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<ScoringBloc>()),
                BlocProvider.value(value: context.read<ThemeCubit>()),
                BlocProvider.value(value: context.read<DebugSettingsCubit>()),
                BlocProvider.value(
                  value: context.read<ScoreboardFontCubit>(),
                ),
              ],
              child: MultiRepositoryProvider(
                providers: [
                  RepositoryProvider.value(value: context.read<AppConfig>()),
                  RepositoryProvider.value(
                    value: context.read<TeamSelectionService>(),
                  ),
                  RepositoryProvider.value(
                    value: context.read<BoxPairingService>(),
                  ),
                ],
                child: const SettingsScreen(),
              ),
            ),
      ),
    );
  }

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _currentTabIndex = 0;

  void _changeTab(int index) {
    if (index >= 0 && index < 4) {
      setState(() => _currentTabIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.goBack): const DismissIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),
        LogicalKeySet(LogicalKeyboardKey.browserBack): const DismissIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) => Navigator.of(context).pop(),
          ),
        },
        child: Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
          body: Column(
            children: [
              // Header compacto con título, botón volver y tabs en una sola barra
              Container(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      _FocusableIconButton(
                        icon: Icons.arrow_back,
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: l10n.close,
                        autofocus: true,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.settingsTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Tabs inline
                      Expanded(
                        child: _FocusableTabBar(
                          currentIndex: _currentTabIndex,
                          onTabChanged: _changeTab,
                          tabs: [
                            _TabInfo(Icons.groups, l10n.tabTeams),
                            _TabInfo(Icons.rule, l10n.tabRules),
                            _TabInfo(Icons.palette, l10n.tabDisplay),
                            _TabInfo(Icons.sports_esports, 'Mandos'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Contenido del tab actual
              Expanded(
                child: FocusTraversalGroup(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _buildTabContent(_currentTabIndex),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(int index) {
    switch (index) {
      case 0:
        return const _TeamsTab(key: ValueKey('teams'));
      case 1:
        return const _RulesTab(key: ValueKey('rules'));
      case 2:
        return const _DisplayTab(key: ValueKey('display'));
      case 3:
        return const _ControllersTab(key: ValueKey('controllers'));
      default:
        return const _TeamsTab(key: ValueKey('teams'));
    }
  }
}

// ============================================================================
// TAB BAR NAVEGABLE CON D-PAD
// ============================================================================

class _TabInfo {
  final IconData icon;
  final String label;
  const _TabInfo(this.icon, this.label);
}

class _FocusableTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;
  final List<_TabInfo> tabs;

  const _FocusableTabBar({
    required this.currentIndex,
    required this.onTabChanged,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children:
            tabs.asMap().entries.map((entry) {
              final index = entry.key;
              final tab = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _FocusableTab(
                  icon: tab.icon,
                  label: tab.label,
                  isSelected: currentIndex == index,
                  onTap: () => onTabChanged(index),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _FocusableTab extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FocusableTab({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FocusableTab> createState() => _FocusableTabState();
}

class _FocusableTabState extends State<_FocusableTab> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          decoration: BoxDecoration(
            color:
                widget.isSelected
                    ? primaryColor.withValues(alpha: 0.15)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _focused ? _focusBorderColor : Colors.transparent,
              width: _focusBorderWidth,
            ),
            boxShadow:
                _focused
                    ? [
                      BoxShadow(
                        color: _focusBorderColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                    : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color:
                    widget.isSelected
                        ? primaryColor
                        : (isDark ? Colors.white60 : Colors.black54),
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      widget.isSelected ? FontWeight.bold : FontWeight.normal,
                  color:
                      widget.isSelected
                          ? primaryColor
                          : (isDark ? Colors.white60 : Colors.black54),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TAB: EQUIPOS
// ============================================================================

class _TeamsTab extends StatelessWidget {
  const _TeamsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final teamService = context.read<TeamSelectionService>();
    final config = context.read<AppConfig>();

    // Layout horizontal compacto para TV
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Equipo 1
          Expanded(
            child: _CompactSection(
              title: l10n.team1Color,
              child: _TeamColorSelector(
                teamIndex: 1,
                teamService: teamService,
                config: config,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Equipo 2
          Expanded(
            child: _CompactSection(
              title: l10n.team2Color,
              child: _TeamColorSelector(
                teamIndex: 2,
                teamService: teamService,
                config: config,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamColorSelector extends StatefulWidget {
  final int teamIndex;
  final TeamSelectionService teamService;
  final AppConfig config;

  const _TeamColorSelector({
    required this.teamIndex,
    required this.teamService,
    required this.config,
  });

  @override
  State<_TeamColorSelector> createState() => _TeamColorSelectorState();
}

class _TeamColorSelectorState extends State<_TeamColorSelector> {
  @override
  Widget build(BuildContext context) {
    final availableTeams = widget.config.availableTeams;
    final currentSelection =
        widget.teamIndex == 1
            ? widget.teamService.team1Selection.value
            : widget.teamService.team2Selection.value;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          availableTeams.map((team) {
            final color = _hexToColor(team.colorHex);
            final isSelected = currentSelection == team.id;

            return _FocusableColorChip(
              color: color,
              label: team.displayName,
              isSelected: isSelected,
              onTap: () {
                if (widget.teamIndex == 1) {
                  widget.teamService.setTeam1(team.id);
                } else {
                  widget.teamService.setTeam2(team.id);
                }
                setState(() {});
              },
            );
          }).toList(),
    );
  }

  Color _hexToColor(String hex) {
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    return Color(int.tryParse(h, radix: 16) ?? 0xFF2196F3);
  }
}

class _FocusableColorChip extends StatefulWidget {
  final Color color;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FocusableColorChip({
    required this.color,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FocusableColorChip> createState() => _FocusableColorChipState();
}

class _FocusableColorChipState extends State<_FocusableColorChip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _focused ? _focusBorderColor : Colors.transparent,
              width: _focusBorderWidth,
            ),
            boxShadow:
                _focused
                    ? [
                      BoxShadow(
                        color: _focusBorderColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ]
                    : null,
          ),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.isSelected ? Colors.white : Colors.white30,
                width: widget.isSelected ? 3 : 2,
              ),
            ),
            child: widget.isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TAB: REGLAS
// ============================================================================

class _RulesTab extends StatelessWidget {
  const _RulesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<ScoringBloc, ScoringState>(
      buildWhen: (p, n) => p.match.settings != n.match.settings,
      builder: (context, state) {
        final settings = state.match.settings;
        final bloc = context.read<ScoringBloc>();
        final isChampionship = settings.matchMode == MatchMode.championship;

        // Layout vertical con secciones
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =============== MODO DE PARTIDO ===============
              Text(
                'Modo de Partido',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Amateur
                  Expanded(
                    child: _ModeCard(
                      title: 'AMATEUR',
                      description: 'Sets 5-5 → diferencia de 2\nMáximo 9-8\nSin tie-break en sets',
                      isSelected: !isChampionship,
                      icon: Icons.sports_tennis,
                      onTap: () => bloc.add(const ScoringEvent.setMatchMode(MatchMode.amateur)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Campeonato
                  Expanded(
                    child: _ModeCard(
                      title: 'CAMPEONATO',
                      description: 'Sets 6-6 → Tie-break a 7\nEmpate 1-1 → Super TB a 11\nReglas oficiales',
                      isSelected: isChampionship,
                      icon: Icons.emoji_events,
                      onTap: () => bloc.add(const ScoringEvent.setMatchMode(MatchMode.championship)),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              
              // =============== OTRAS REGLAS ===============
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Golden Point
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.goldenPointOn.split(':')[0],
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _CompactSwitch(
                          label: settings.goldenPoint ? 'ON' : 'OFF',
                          value: settings.goldenPoint,
                          onChanged: (v) => bloc.add(ScoringEvent.toggleGoldenPoint(v)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.goldenPointExplanation,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Info del modo actual
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reglas del Set',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white10
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isChampionship
                                ? '• Sets: primero a 6 juegos\n• Empate 6-6: Tie-break a 7\n• Empate 1-1 sets: Super TB a 11'
                                : '• Sets: primero a 6 juegos\n• Empate 5-5: diferencia de 2\n• Máximo permitido: 9-8',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tarjeta de selección de modo
class _ModeCard extends StatefulWidget {
  final String title;
  final String description;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.description,
    required this.isSelected,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? primaryColor.withValues(alpha: isDark ? 0.3 : 0.15)
                : (isDark ? Colors.white10 : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focused
                  ? _focusBorderColor
                  : (widget.isSelected ? primaryColor : Colors.transparent),
              width: _focused ? _focusBorderWidth : 2,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: _focusBorderColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                widget.icon,
                size: 32,
                color: widget.isSelected ? primaryColor : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.isSelected ? primaryColor : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
              if (widget.isSelected) ...[
                const SizedBox(height: 8),
                Icon(
                  Icons.check_circle,
                  color: primaryColor,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Switch compacto para TV
class _CompactSwitch extends StatefulWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CompactSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_CompactSwitch> createState() => _CompactSwitchState();
}

class _CompactSwitchState extends State<_CompactSwitch> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onChanged(!widget.value);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => widget.onChanged(!widget.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white10
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _focused ? _focusBorderColor : Colors.transparent,
              width: _focusBorderWidth,
            ),
            boxShadow: _focused
                ? [BoxShadow(color: _focusBorderColor.withValues(alpha: 0.4), blurRadius: 8)]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: widget.value ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 24,
                child: Switch(
                  value: widget.value,
                  onChanged: widget.onChanged,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusableSwitch extends StatefulWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FocusableSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_FocusableSwitch> createState() => _FocusableSwitchState();
}

class _FocusableSwitchState extends State<_FocusableSwitch> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onChanged(!widget.value);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => widget.onChanged(!widget.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focused ? _focusBorderColor : Colors.transparent,
              width: _focusBorderWidth,
            ),
            boxShadow:
                _focused
                    ? [
                      BoxShadow(
                        color: _focusBorderColor.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                    : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        widget.value ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              // Indicador visual del estado
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.value ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.value ? 'ON' : 'OFF',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Switch(value: widget.value, onChanged: widget.onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TAB: PANTALLA
// ============================================================================

class _DisplayTab extends StatelessWidget {
  const _DisplayTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeCubit = context.read<ThemeCubit>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.themeMode,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CompactThemeChip(
                icon: Icons.light_mode,
                label: l10n.lightTheme,
                isSelected: !isDark,
                onTap: () => themeCubit.setThemeMode(ThemeMode.light),
              ),
              const SizedBox(width: 12),
              _CompactThemeChip(
                icon: Icons.dark_mode,
                label: l10n.darkTheme,
                isSelected: isDark,
                onTap: () => themeCubit.setThemeMode(ThemeMode.dark),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Botón de depuración (mostrar/ocultar el panel de pruebas)
          BlocBuilder<DebugSettingsCubit, bool>(
            builder: (context, showDebug) {
              return _FocusableSwitch(
                label: l10n.showDebugButton,
                value: showDebug,
                onChanged: (v) =>
                    context.read<DebugSettingsCubit>().setShowDebugButton(v),
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            l10n.showDebugButtonHint,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          // Tamaño de los números del marcador (solo pantalla del marcador)
          const Text(
            'Tamaño de números (marcador)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          BlocBuilder<ScoreboardFontCubit, ScoreboardFontSize>(
            builder: (context, current) {
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final size in ScoreboardFontSize.values)
                    _CompactThemeChip(
                      icon: Icons.format_size,
                      label: size.label,
                      isSelected: size == current,
                      onTap: () =>
                          context.read<ScoreboardFontCubit>().setSize(size),
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

/// Chip compacto para tema
class _CompactThemeChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CompactThemeChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CompactThemeChip> createState() => _CompactThemeChipState();
}

class _CompactThemeChipState extends State<_CompactThemeChip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? primaryColor.withValues(alpha: 0.12)
                : (isDark ? Colors.white10 : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _focused ? _focusBorderColor : Colors.transparent,
              width: _focusBorderWidth,
            ),
            boxShadow: _focused
                ? [BoxShadow(color: _focusBorderColor.withValues(alpha: 0.4), blurRadius: 8)]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: widget.isSelected
                    ? primaryColor
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
                  color: widget.isSelected ? primaryColor : null,
                ),
              ),
              if (widget.isSelected) ...[
                const SizedBox(width: 6),
                Icon(Icons.check, size: 16, color: primaryColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGETS COMUNES
// ============================================================================

/// Sección compacta para TV
class _CompactSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _CompactSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({required this.title, required this.child, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _FocusableIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool autofocus;

  const _FocusableIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.autofocus = false,
  });

  @override
  State<_FocusableIconButton> createState() => _FocusableIconButtonState();
}

class _FocusableIconButtonState extends State<_FocusableIconButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _focused ? _focusBorderColor : Colors.transparent,
            width: _focusBorderWidth,
          ),
          boxShadow:
              _focused
                  ? [
                    BoxShadow(
                      color: _focusBorderColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ]
                  : null,
        ),
        child: IconButton(
          icon: Icon(widget.icon),
          onPressed: widget.onPressed,
          tooltip: widget.tooltip,
        ),
      ),
    );
  }
}

// ============================================================================
// TAB: MANDOS (emparejamiento caja → equipo)
// ============================================================================

class _ControllersTab extends StatelessWidget {
  const _ControllersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final pairing = context.read<BoxPairingService>();
    final teamService = context.read<TeamSelectionService>();

    return AnimatedBuilder(
      animation: Listenable.merge([
        pairing.pairings,
        pairing.lastUnpairedBox,
        teamService.team1Selection,
        teamService.team2Selection,
      ]),
      builder: (context, _) {
        final entries = pairing.pairings.value.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        final unpaired = pairing.lastUnpairedBox.value;

        final team1Name = teamService.getTeam1()?.displayName ?? 'Equipo 1';
        final team2Name = teamService.getTeam2()?.displayName ?? 'Equipo 2';
        final team1Color = teamService.getColor1();
        final team2Color = teamService.getColor2();

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Emparejar mandos con equipos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Cada mando tiene un ID fijo. Asigna cada uno al equipo que '
                'debe puntuar. El emparejamiento se recuerda hasta que lo '
                'cambies. Si conectas un mando nuevo, pulsa uno de sus botones '
                'para que aparezca aquí.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),

              // Aviso de mando nuevo detectado sin emparejar.
              if (unpaired != null) ...[
                _UnpairedBoxCard(
                  boxId: unpaired,
                  team1Color: team1Color,
                  team2Color: team2Color,
                  team1Name: team1Name,
                  team2Name: team2Name,
                  onAssign: (idx) => pairing.setPairing(unpaired, idx),
                  onDismiss: pairing.clearUnpairedBox,
                ),
                const SizedBox(height: 16),
              ],

              if (entries.isEmpty)
                Text(
                  'No hay mandos emparejados.',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                )
              else
                ...entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BoxPairingRow(
                      boxId: e.key,
                      teamIndex: e.value,
                      team1Color: team1Color,
                      team2Color: team2Color,
                      team1Name: team1Name,
                      team2Name: team2Name,
                      onSelect: (idx) => pairing.setPairing(e.key, idx),
                      onRemove: () => pairing.removeBox(e.key),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Fila de un mando emparejado: ID + selector de equipo + eliminar.
class _BoxPairingRow extends StatelessWidget {
  const _BoxPairingRow({
    required this.boxId,
    required this.teamIndex,
    required this.team1Color,
    required this.team2Color,
    required this.team1Name,
    required this.team2Name,
    required this.onSelect,
    required this.onRemove,
  });

  final String boxId;
  final int teamIndex;
  final Color team1Color;
  final Color team2Color;
  final String team1Name;
  final String team2Name;
  final ValueChanged<int> onSelect;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.sports_esports, size: 20),
          const SizedBox(width: 10),
          Text(
            'Mando ${boxId.toUpperCase()}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          _TeamPickChip(
            color: team1Color,
            label: team1Name,
            selected: teamIndex == 1,
            onTap: () => onSelect(1),
          ),
          const SizedBox(width: 8),
          _TeamPickChip(
            color: team2Color,
            label: team2Name,
            selected: teamIndex == 2,
            onTap: () => onSelect(2),
          ),
          const SizedBox(width: 12),
          _FocusableSquareButton(
            icon: Icons.delete_outline,
            color: Colors.red.shade400,
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}

/// Tarjeta destacada cuando se detecta un mando sin emparejar.
class _UnpairedBoxCard extends StatelessWidget {
  const _UnpairedBoxCard({
    required this.boxId,
    required this.team1Color,
    required this.team2Color,
    required this.team1Name,
    required this.team2Name,
    required this.onAssign,
    required this.onDismiss,
  });

  final String boxId;
  final Color team1Color;
  final Color team2Color;
  final String team1Name;
  final String team2Name;
  final ValueChanged<int> onAssign;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.new_releases, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mando nuevo detectado: ${boxId.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _FocusableSquareButton(
                icon: Icons.close,
                color: Colors.grey,
                onTap: onDismiss,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Asignar a:', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              _TeamPickChip(
                color: team1Color,
                label: team1Name,
                selected: false,
                onTap: () => onAssign(1),
              ),
              const SizedBox(width: 12),
              _TeamPickChip(
                color: team2Color,
                label: team2Name,
                selected: false,
                onTap: () => onAssign(2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chip seleccionable de equipo (punto de color + nombre), navegable por d-pad.
class _TeamPickChip extends StatefulWidget {
  const _TeamPickChip({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TeamPickChip> createState() => _TeamPickChipState();
}

class _TeamPickChipState extends State<_TeamPickChip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? widget.color.withValues(alpha: 0.18)
                : (isDark ? Colors.white10 : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _focused
                  ? _focusBorderColor
                  : (widget.selected ? widget.color : Colors.transparent),
              width: _focused ? _focusBorderWidth : 2,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: _focusBorderColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white30),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      widget.selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (widget.selected) ...[
                const SizedBox(width: 6),
                Icon(Icons.check, size: 16, color: widget.color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón cuadrado con icono, navegable por d-pad (eliminar / cerrar).
class _FocusableSquareButton extends StatefulWidget {
  const _FocusableSquareButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_FocusableSquareButton> createState() => _FocusableSquareButtonState();
}

class _FocusableSquareButtonState extends State<_FocusableSquareButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _focused ? _focusBorderColor : Colors.transparent,
              width: _focused ? _focusBorderWidth : 2,
            ),
          ),
          child: Icon(widget.icon, color: widget.color, size: 20),
        ),
      ),
    );
  }
}
