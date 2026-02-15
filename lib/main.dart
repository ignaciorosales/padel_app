import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:Puntazo/config/config_loader.dart';
import 'package:Puntazo/config/app_config.dart';
import 'package:Puntazo/config/app_theme.dart';
import 'package:Puntazo/config/team_selection_service.dart';
import 'package:Puntazo/config/theme_cubit.dart';
import 'package:Puntazo/features/models/scoring_models.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_event.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_state.dart';
import 'package:Puntazo/features/usb_serial/simple_usb_serial_listener.dart';
import 'package:Puntazo/features/usb_serial/usb_connection_cubit.dart';
import 'package:Puntazo/features/widgets/scoreboard.dart';
import 'package:Puntazo/features/widgets/winner_overlay.dart';
import 'package:Puntazo/features/widgets/settings_screen.dart';
import 'package:Puntazo/l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Load configuration
  final config = await ConfigLoader.load();

  // Initialize services
  final teamService = await TeamSelectionService.init(config);
  final themeCubit = await ThemeCubit.init();

  runApp(
    PuntazoApp(
      config: config,
      teamService: teamService,
      themeCubit: themeCubit,
    ),
  );
}

class PuntazoApp extends StatefulWidget {
  final AppConfig config;
  final TeamSelectionService teamService;
  final ThemeCubit themeCubit;

  const PuntazoApp({
    super.key,
    required this.config,
    required this.teamService,
    required this.themeCubit,
  });

  @override
  State<PuntazoApp> createState() => _PuntazoAppState();
}

class _PuntazoAppState extends State<PuntazoApp> {
  @override
  void initState() {
    super.initState();
    widget.teamService.team1Selection.addListener(_onTeamChanged);
    widget.teamService.team2Selection.addListener(_onTeamChanged);
  }

  @override
  void dispose() {
    widget.teamService.team1Selection.removeListener(_onTeamChanged);
    widget.teamService.team2Selection.removeListener(_onTeamChanged);
    super.dispose();
  }

  void _onTeamChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: widget.config),
        RepositoryProvider.value(value: widget.teamService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: widget.themeCubit),
          BlocProvider(create: (_) => UsbConnectionCubit()),
          BlocProvider(
            create: (context) {
              final settings = MatchSettings(
                setsToWin: widget.config.rules.setsToWin,
                goldenPoint: widget.config.rules.goldenPoint,
                tieBreakAtGames: widget.config.rules.tiebreakAtSixSix ? 6 : 12,
              );

              final startingServer =
                  widget.config.rules.startingServerId == 'team1'
                      ? Team.blue
                      : Team.red;

              return ScoringBloc()..add(
                ScoringEvent.newMatch(
                  settings: settings,
                  startingServer: startingServer,
                ),
              );
            },
          ),
        ],
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            return MaterialApp(
              title: 'Puntazo',
              debugShowCheckedModeBanner: false,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('es'),
              theme: _buildLightTheme(widget.config, widget.teamService),
              darkTheme: _buildDarkTheme(widget.config, widget.teamService),
              themeMode: themeMode,
              home: const MatchScreen(),
            );
          },
        ),
      ),
    );
  }

  ThemeData _buildLightTheme(
    AppConfig config,
    TeamSelectionService teamService,
  ) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      extensions: [
        PadelThemeExtension.fromConfig(config, teamService: teamService),
      ],
    );
  }

  ThemeData _buildDarkTheme(
    AppConfig config,
    TeamSelectionService teamService,
  ) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      extensions: [
        PadelThemeExtension.fromConfig(config, teamService: teamService),
      ],
    );
  }
}

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  SimpleUsbSerialListener? _usbListener;
  StreamSubscription<String>? _commandSub;
  StreamSubscription<bool>? _connectionSub;
  
  // ▼ TESTING: Deshabilitado temporalmente
  // bool _showTestingOverlay = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _startUsbSerial();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _commandSub?.cancel();
    _connectionSub?.cancel();
    _usbListener?.stop();
    super.dispose();
  }

  Future<void> _startUsbSerial() async {
    _usbListener = SimpleUsbSerialListener();

    // Usamos BLoC para el estado de conexión USB
    _connectionSub = _usbListener!.connectionStatus.listen((connected) {
      if (mounted) {
        context.read<UsbConnectionCubit>().setConnected(connected);
      }
    });

    // Comandos USB → BLoC events
    _commandSub = _usbListener!.commands.listen((cmd) {
      if (!mounted) return;

      final cleanCmd = cmd.trim().toUpperCase();
      if (cleanCmd.isEmpty) return;

      final bloc = context.read<ScoringBloc>();
      final isSwapped = bloc.state.isSwapped;
      
      // Determinar qué equipo está en cada lado físico
      // P_A = Botonera IZQUIERDA física
      // P_B = Botonera DERECHA física
      final leftTeam = isSwapped ? Team.red : Team.blue;
      final rightTeam = isSwapped ? Team.blue : Team.red;

      switch (cleanCmd) {
        case 'P_A':
          bloc.add(ScoringEvent.pointFor(leftTeam));
        case 'P_B':
          bloc.add(ScoringEvent.pointFor(rightTeam));
        case 'UNDO_A':
          bloc.add(ScoringEvent.undoForTeam(leftTeam));
        case 'UNDO_B':
          bloc.add(ScoringEvent.undoForTeam(rightTeam));
        case 'RESET':
        case 'RESET_GAME':
          bloc.add(const ScoringEvent.resetSwap()); // Resetear swap al iniciar nuevo partido
          bloc.add(const ScoringEvent.newMatch());
        case 'PONG':
          break;
      }
    });

    await _usbListener!.start();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ScoringBloc, ScoringState>(
      listenWhen: (previous, current) {
        // Detectar cambio de set (avance, no retroceso por undo)
        return current.match.currentSetIndex > previous.match.currentSetIndex;
      },
      listener: (context, state) {
        // Cuando avanza el set, intercambiar equipos de lado
        context.read<ScoringBloc>().add(const ScoringEvent.swapSides());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Marcador principal
            const Scoreboard(),

            // Overlay de ganador
            const WinnerOverlay(),

          // Indicador USB (solo cuando NO hay conexión)
          Positioned(
            left: 12,
            top: 12,
            child: BlocBuilder<UsbConnectionCubit, UsbConnectionState>(
              builder: (context, state) {
                if (state.isConnected) return const SizedBox.shrink();

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.usb_off, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Sin USB',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Botón de configuración → abre pantalla completa
          Positioned(
            bottom: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => SettingsScreen.open(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF42A5F5), // Blue focus color
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF42A5F5).withOpacity(0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.settings,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          
          // ▼ TESTING: Deshabilitado temporalmente
          // Positioned(
          //   bottom: 16,
          //   left: 16,
          //   child: Material(
          //     color: Colors.transparent,
          //     child: InkWell(
          //       onTap: () => setState(() => _showTestingOverlay = !_showTestingOverlay),
          //       borderRadius: BorderRadius.circular(12),
          //       child: Container(
          //         padding: const EdgeInsets.all(10),
          //         decoration: BoxDecoration(
          //           color: _showTestingOverlay 
          //               ? Colors.orange.withOpacity(0.8)
          //               : Colors.white.withOpacity(0.15),
          //           borderRadius: BorderRadius.circular(12),
          //           border: Border.all(
          //             color: _showTestingOverlay ? Colors.orange : Colors.grey,
          //             width: 2,
          //           ),
          //         ),
          //         child: Icon(
          //           Icons.bug_report,
          //           color: _showTestingOverlay ? Colors.white : Colors.white70,
          //           size: 20,
          //         ),
          //       ),
          //     ),
          //   ),
          // ),
          
          // ▼ TESTING: Overlay deshabilitado temporalmente
          // if (_showTestingOverlay)
          //   Positioned(
          //     bottom: 70,
          //     left: 16,
          //     child: BlocBuilder<ScoringBloc, ScoringState>(
          //       builder: (context, scoringState) {
          //         final teamService = RepositoryProvider.of<TeamSelectionService>(context);
          //         final isSwapped = scoringState.isSwapped;
          //         final leftTeam = isSwapped ? Team.red : Team.blue;
          //         final rightTeam = isSwapped ? Team.blue : Team.red;
          //         final leftColor = isSwapped ? teamService.getColor2() : teamService.getColor1();
          //         final rightColor = isSwapped ? teamService.getColor1() : teamService.getColor2();
          //         final leftName = isSwapped 
          //             ? (teamService.getTeam2()?.displayName ?? 'Equipo 2')
          //             : (teamService.getTeam1()?.displayName ?? 'Equipo 1');
          //         final rightName = isSwapped 
          //             ? (teamService.getTeam1()?.displayName ?? 'Equipo 1')
          //             : (teamService.getTeam2()?.displayName ?? 'Equipo 2');
          //         final match = scoringState.match;
          //         final currentSet = match.currentSet;
          //         final setIndex = match.currentSetIndex;
          //         return Container(
          //           // ... contenido del overlay
          //         );
          //       },
          //     ),
          //   ),
        ],
        ),
      ),
    );
  }
}

// ▼ TESTING: Widget deshabilitado temporalmente
// class _TestingButton extends StatelessWidget {
//   final String label;
//   final Color color;
//   final VoidCallback onTap;
//
//   const _TestingButton({
//     required this.label,
//     required this.color,
//     required this.onTap,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Material(
//       color: color,
//       borderRadius: BorderRadius.circular(12),
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(12),
//         child: Container(
//           width: 60,
//           height: 50,
//           alignment: Alignment.center,
//           child: Text(
//             label,
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
