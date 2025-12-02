import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:Puntazo/config/app_config.dart';
import 'package:Puntazo/config/app_theme.dart';
import 'package:Puntazo/config/config_loader.dart';
import 'package:Puntazo/config/team_selection_service.dart';
import 'package:Puntazo/features/serial/padel_serial_client_android.dart';
import 'package:Puntazo/features/models/scoring_models.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_event.dart';
import 'package:Puntazo/features/widgets/referee_sidebar.dart';
import 'package:Puntazo/features/widgets/winner_overlay.dart';
import 'package:Puntazo/features/widgets/scoreboard.dart';
import 'package:Puntazo/features/settings/match_settings_screen.dart';

/// Controlador de tema de la aplicación
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
  void initState() {
    super.initState();
    _themeCtrl = ThemeController(ThemeMode.dark);
    widget.teamSelection.team1Selection.addListener(_onTeamColorsChanged);
    widget.teamSelection.team2Selection.addListener(_onTeamColorsChanged);
  }

  @override
  void dispose() {
    widget.teamSelection.team1Selection.removeListener(_onTeamColorsChanged);
    widget.teamSelection.team2Selection.removeListener(_onTeamColorsChanged);
    _themeCtrl.dispose();
    widget.teamSelection.dispose();
    super.dispose();
  }

  void _onTeamColorsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  ThemeData _buildTheme(Brightness brightness) {
    final color1 = widget.teamSelection.getColor1();
    final color2 = widget.teamSelection.getColor2();
    
    return brightness == Brightness.light
        ? PadelTheme.lightTheme(team1Color: color1, team2Color: color2)
        : PadelTheme.darkTheme(team1Color: color1, team2Color: color2);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeCtrl.mode,
      builder: (context, mode, _) {
        return MultiRepositoryProvider(
          providers: [
            RepositoryProvider<AppConfig>.value(value: widget.config),
            RepositoryProvider<TeamSelectionService>.value(value: widget.teamSelection),
            RepositoryProvider<ThemeController>.value(value: _themeCtrl),
          ],
          child: MaterialApp(
            title: 'Puntazo',
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(Brightness.light),
            darkTheme: _buildTheme(Brightness.dark),
            themeMode: mode,
            home: _ScoreOnlyScreen(
              config: widget.config,
              teamSelection: widget.teamSelection,
              themeController: _themeCtrl,
            ),
          ),
        );
      },
    );
  }
}

class _ScoreOnlyScreen extends StatefulWidget {
  const _ScoreOnlyScreen({
    required this.config,
    required this.teamSelection,
    required this.themeController,
  });

  final AppConfig config;
  final TeamSelectionService teamSelection;
  final ThemeController themeController;

  @override
  State<_ScoreOnlyScreen> createState() => _ScoreOnlyScreenState();
}

class _ScoreOnlyScreenState extends State<_ScoreOnlyScreen> with WidgetsBindingObserver {
  late final PadelSerialClientAndroid _serial;
  late final ScoringBloc _bloc;
  StreamSubscription<String>? _cmdSub;
  final ValueNotifier<bool> _refSidebarVisible = ValueNotifier<bool>(false);
  bool _restartDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    
    // Crear bloc
    _bloc = ScoringBloc();
    final cfg = widget.config;
    final starting = (cfg.rules.startingServerId == 'team2') ? Team.red : Team.blue;
    _bloc.add(
      ScoringEvent.newMatch(
        startingServer: starting,
        settings: MatchSettings(
          goldenPoint: cfg.rules.goldenPoint,
          tieBreakAtGames: cfg.rules.tiebreakAtSixSix ? 6 : 1,
          tieBreakTarget: 7,
          setsToWin: cfg.rules.setsToWin,
        ),
      ),
    );
    
    // Inicializar cliente serial para Android
    _serial = PadelSerialClientAndroid();
    _serial.init();
    
    // Suscribirse a comandos serial
    _cmdSub = _serial.commands.listen((cmd) {
      if (!mounted) return;
      
      // Formato: "cmd:devId:seq" (ej: "a:1:42", "b:2:43")
      final parts = cmd.split(':');
      if (parts.isEmpty) return;
      
      final cmdChar = parts[0];
      final devId = parts.length > 1 ? parts[1] : '?';
      final seq = parts.length > 2 ? parts[2] : '?';
      
      if (cmdChar == 'g') {
        // Restart
        _showRestartConfirmation();
      } else if (cmdChar == 'u') {
        // Undo
        _bloc.add(const UndoEvent());
      } else if (cmdChar == 'a') {
        // Botón A → Equipo Blue (lado izquierdo)
        _bloc.add(const PointForEvent(Team.blue));
        if (kDebugMode) {
          print('[MAIN] Punto para BLUE (botón A, dev:$devId, seq:$seq)');
        }
      } else if (cmdChar == 'b') {
        // Botón B → Equipo Red (lado derecho)
        _bloc.add(const PointForEvent(Team.red));
        if (kDebugMode) {
          print('[MAIN] Punto para RED (botón B, dev:$devId, seq:$seq)');
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _cmdSub?.cancel();
    _serial.dispose();
    _bloc.close();
    _refSidebarVisible.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _serial.init();
    }
  }

  void _showRestartConfirmation() {
    if (_restartDialogOpen) return;
    _restartDialogOpen = true;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Reiniciar Partido'),
        content: const Text('¿Desea reiniciar el partido actual?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _restartDialogOpen = false;
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              _bloc.add(const ScoringEvent.newMatch());
              Navigator.of(ctx).pop();
              _restartDialogOpen = false;
            },
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    ).then((_) {
      _restartDialogOpen = false;
    });
  }

  void _toggleRefPanel() => _refSidebarVisible.value = !_refSidebarVisible.value;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Builder(
        builder: (scaffoldContext) {
          return Scaffold(
              body: Stack(
                children: [
                  const Scoreboard(),
                  RefereeSidebar(visibleNotifier: _refSidebarVisible),
                  const WinnerOverlay(),
                ],
              ),
              floatingActionButton: ValueListenableBuilder<bool>(
                valueListenable: _refSidebarVisible,
                builder: (_, isVisible, __) {
                  // Calcular padding para evitar que los FABs queden detrás del sidebar
                  final paddingRight = isVisible
                      ? MediaQuery.of(context).size.width * 0.1
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
                          tooltip: isVisible
                              ? 'Ocultar panel árbitro'
                              : 'Mostrar panel árbitro',
                          heroTag: 'referee',
                        ),
                        const SizedBox(height: 10),
                        // Botón de configuración - FOCUSABLE para control remoto
                        _FocusableButton(
                          onPressed: () {
                            Navigator.of(scaffoldContext).push(
                              MaterialPageRoute(
                                builder: (_) => BlocProvider.value(
                                  value: _bloc,
                                  child: const MatchSettingsScreen(),
                                ),
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
              ),
              floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            );
        },
      ),
    );
  }
}

/// Widget personalizado para botones focusables (Android TV Box con control remoto)
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
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: widget.heroTag,
      tooltip: widget.tooltip,
      onPressed: widget.onPressed,
      autofocus: widget.autofocus,
      focusNode: _focusNode,
      backgroundColor:
          _hasFocus ? Theme.of(context).colorScheme.primary : Colors.grey[800],
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
