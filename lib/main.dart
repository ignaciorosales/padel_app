import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:Puntazo/config/app_config.dart';
import 'package:Puntazo/config/app_theme.dart';
import 'package:Puntazo/config/config_loader.dart';
import 'package:Puntazo/config/team_selection_service.dart';
import 'package:Puntazo/features/ble/padel_ble_client.dart';
import 'package:Puntazo/features/models/scoring_models.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_event.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_state.dart';
import 'package:Puntazo/features/widgets/scoreboard.dart';
import 'package:Puntazo/features/widgets/referee_sidebar.dart';
import 'package:Puntazo/features/widgets/winner_overlay.dart';
import 'package:Puntazo/features/settings/match_settings_screen.dart';

/// Simple app-wide theme controller
class ThemeController {
  ThemeController(ThemeMode initial) : mode = ValueNotifier<ThemeMode>(initial);

  final ValueNotifier<ThemeMode> mode;

  void set(ThemeMode m) => mode.value = m;

  ThemeMode get current => mode.value;

  void dispose() => mode.dispose();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final config = await ConfigLoader.load();
  final teamSelection = await TeamSelectionService.init(config);
  runApp(PadelApp(config: config, teamSelection: teamSelection));
}

class PadelApp extends StatefulWidget {
  const PadelApp({super.key, required this.config, required this.teamSelection});

  final AppConfig config;
  final TeamSelectionService teamSelection;

  @override
  State<PadelApp> createState() => _PadelAppState();
}

class _PadelAppState extends State<PadelApp> {
  late final ThemeController _themeCtrl;

  @override
  void dispose() {
    widget.teamSelection.team1Selection.removeListener(_onTeamColorsChanged);
    widget.teamSelection.team2Selection.removeListener(_onTeamColorsChanged);
    _themeCtrl.dispose();
    widget.teamSelection.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Start however you prefer (Dark by default). You could persist this.
    _themeCtrl = ThemeController(ThemeMode.dark);
    
    // Escuchar cambios en la selección de equipos para reconstruir el tema
    widget.teamSelection.team1Selection.addListener(_onTeamColorsChanged);
    widget.teamSelection.team2Selection.addListener(_onTeamColorsChanged);
  }
  
  void _onTeamColorsChanged() {
    if (mounted) {
      setState(() {
        // Forzar reconstrucción del MaterialApp con nuevos colores
      });
    }
  }

  // --------- THEME DEFINITIONS (Material 3 with Padel Custom Colors) ---------

  ThemeData _lightTheme() {
    final team1Color = widget.teamSelection.getColor1();
    final team2Color = widget.teamSelection.getColor2();
    return PadelTheme.lightTheme(team1Color: team1Color, team2Color: team2Color);
  }

  ThemeData _darkTheme() {
    final team1Color = widget.teamSelection.getColor1();
    final team2Color = widget.teamSelection.getColor2();
    return PadelTheme.darkTheme(team1Color: team1Color, team2Color: team2Color);
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AppConfig>.value(value: widget.config),
        RepositoryProvider<ThemeController>.value(value: _themeCtrl),
        RepositoryProvider<TeamSelectionService>.value(value: widget.teamSelection),
      ],
      child: BlocProvider(
        create: (_) {
          final bloc = ScoringBloc();
          final cfg = widget.config;
          final starting = (cfg.rules.startingServerId == 'team2') ? Team.red : Team.blue;

          bloc.add(
            ScoringEvent.newMatch(
              startingServer: starting,
              settings: MatchSettings(
                goldenPoint: cfg.rules.goldenPoint,
                tieBreakAtGames: cfg.rules.tiebreakAtSixSix ? 6 : 1, // 6 para TB en 6-6, 1 para Super TB en 3er set
                tieBreakTarget: 7, // Siempre 7 para el tie-break estándar
                setsToWin: cfg.rules.setsToWin,
              ),
            ),
          );
          return bloc;
        },
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: _themeCtrl.mode,
          builder: (_, mode, __) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: _lightTheme(),
              darkTheme: _darkTheme(),
              themeMode: mode,
              home: const _ScoreOnlyScreen(),
            );
          },
        ),
      ),
    );
  }
}

class _ScoreOnlyScreen extends StatefulWidget {
  const _ScoreOnlyScreen();

  @override
  State<_ScoreOnlyScreen> createState() => _ScoreOnlyScreenState();
}

class _ScoreOnlyScreenState extends State<_ScoreOnlyScreen> {
  final PadelBleClient _ble = PadelBleClient();
  StreamSubscription<String>? _cmdSub;
  final ValueNotifier<bool> _refSidebarVisible = ValueNotifier<bool>(false);
  bool _restartDialogOpen = false;

  @override
  void dispose() {
    _cmdSub?.cancel();
    _ble.dispose();
    _refSidebarVisible.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    () async {
      await _ble.init();
      await _ble.startListening();
      _cmdSub = _ble.commands.listen(
        (cmd) => context.read<ScoringBloc>().add(ScoringEvent.bleCommand(cmd)),
      );
      
      // Listener para mostrar diálogo de restart
      _ble.restartArmed.addListener(_onRestartArmedChanged);
    }();
  }
  
  void _onRestartArmedChanged() {
    final armed = _ble.restartArmed.value;
    if (armed && !_restartDialogOpen) {
      _restartDialogOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _RestartDialog(devId: _ble.restartDevId.value),
      ).then((_) => _restartDialogOpen = false);
    } else if (!armed && _restartDialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
      _restartDialogOpen = false;
    }
  }

  void _toggleRefPanel() {
    // Ya no abrimos un bottom sheet, sino que alternamos la visibilidad de la barra lateral
    _refSidebarVisible.value = !_refSidebarVisible.value;
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: { LogicalKeySet(LogicalKeyboardKey.f1): const ActivateIntent() },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) { _toggleRefPanel(); return null; }),
        },
        child: FocusScope(
          skipTraversal: true, // Evitar que el Scaffold capture focus
          child: Scaffold(
            // background now comes from ThemeData.scaffoldBackgroundColor
            body: SafeArea(
              child: Stack(
                children: [
                  // Contenido base (marcador y panel lateral)
                  Row(
                    children: [
                      // Contenido principal (90%)
                      Expanded(
                        flex: 90,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Scoreboard(),
                          ),
                        ),
                      ),
                      
                      // Barra lateral de árbitro (10%)
                      RefereeSidebar(
                        visibleNotifier: _refSidebarVisible,
                      ),
                    ],
                  ),
                  
                  // Overlay de ganador (aparece cuando hay un ganador)
                  const WinnerOverlay(),
                ],
              ),
            ),
            floatingActionButton: Builder(
              builder: (scaffoldCtx) {
                return ValueListenableBuilder<bool>(
                  valueListenable: _refSidebarVisible,
                  builder: (_, isVisible, __) {
                    // Calculamos el padding derecho para los FABs
                    final paddingRight = isVisible 
                        ? MediaQuery.of(context).size.width * 0.1 // 10% del ancho cuando el panel está abierto
                        : 0.0;
                    
                    return Padding(
                      padding: EdgeInsets.only(right: paddingRight),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Botón de panel árbitro - FOCUSABLE para control remoto
                          _FocusableButton(
                            autofocus: true,
                            onPressed: _toggleRefPanel,
                            icon: isVisible ? Icons.chevron_right : Icons.sports,
                            tooltip: isVisible ? 'Ocultar panel árbitro (F1)' : 'Mostrar panel árbitro (F1)',
                            heroTag: 'referee',
                          ),
                          const SizedBox(height: 10),
                          // Botón de configuración - FOCUSABLE para control remoto
                          _FocusableButton(
                            onPressed: () {
                              Navigator.of(scaffoldCtx).push(
                                MaterialPageRoute(
                                  builder: (_) => MatchSettingsScreen(ble: _ble),
                                ),
                              );
                            },
                            icon: Icons.settings,
                            tooltip: 'Configuración',
                            heroTag: 'settings',
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          ),
        ),
      ),
    );
  }
}

/// Widget personalizado para botones focusables sin doble-focus
class _FocusableButton extends StatefulWidget {
  const _FocusableButton({
    required this.onPressed,
    required this.icon,
    required this.tooltip,
    required this.heroTag,
    this.autofocus = false,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String tooltip;
  final String heroTag;
  final bool autofocus;

  @override
  State<_FocusableButton> createState() => _FocusableButtonState();
}

class _FocusableButtonState extends State<_FocusableButton> {
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
    print('${widget.heroTag} focus: $_hasFocus');
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: widget.heroTag,
      tooltip: widget.tooltip,
      onPressed: widget.onPressed,
      autofocus: widget.autofocus,
      focusNode: _focusNode,
      backgroundColor: _hasFocus 
          ? Theme.of(context).colorScheme.primary
          : Colors.grey[800],
      elevation: _hasFocus ? 8 : 2,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      splashColor: Colors.white.withOpacity(0.2),
      child: Icon(
        widget.icon,
        color: Colors.white,
        size: _hasFocus ? 26 : 24,
      ),
    );
  }
}

/// Diálogo simple que muestra feedback cuando se arma restart
class _RestartDialog extends StatelessWidget {
  const _RestartDialog({this.devId});

  final int? devId;

  @override
  Widget build(BuildContext context) {
    final devIdStr = devId != null 
        ? '0x${devId!.toRadixString(16).padLeft(4, '0').toUpperCase()}'
        : 'desconocido';
    
    return Dialog(
      backgroundColor: Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 64),
            const SizedBox(height: 24),
            Text(
              '🔫 REINICIO ARMADO',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Dispositivo: $devIdStr',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Presiona U (botón negro) para confirmar',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Presiona P (punto) para cancelar',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
