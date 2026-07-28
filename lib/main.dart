import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:Puntazo/config/config_loader.dart';
import 'package:Puntazo/config/app_config.dart';
import 'package:Puntazo/config/app_theme.dart';
import 'package:Puntazo/config/box_pairing_service.dart';
import 'package:Puntazo/config/debug_settings_cubit.dart';
import 'package:Puntazo/config/scoreboard_font_cubit.dart';
import 'package:Puntazo/config/team_selection_service.dart';
import 'package:Puntazo/config/theme_cubit.dart';
import 'package:Puntazo/features/match_control/hardware_command_handler.dart';
import 'package:Puntazo/features/models/scoring_models.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_event.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_state.dart';
import 'package:Puntazo/features/usb_serial/simple_usb_serial_listener.dart';
import 'package:Puntazo/features/usb_serial/usb_connection_cubit.dart';
import 'package:Puntazo/features/widgets/scoreboard.dart';
import 'package:Puntazo/features/widgets/testing_overlay.dart';
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
  final debugSettingsCubit = await DebugSettingsCubit.init();
  final scoreboardFontCubit = await ScoreboardFontCubit.init();
  final boxPairingService = await BoxPairingService.init();

  runApp(
    PuntazoApp(
      config: config,
      teamService: teamService,
      themeCubit: themeCubit,
      debugSettingsCubit: debugSettingsCubit,
      scoreboardFontCubit: scoreboardFontCubit,
      boxPairingService: boxPairingService,
    ),
  );
}

class PuntazoApp extends StatefulWidget {
  final AppConfig config;
  final TeamSelectionService teamService;
  final ThemeCubit themeCubit;
  final DebugSettingsCubit debugSettingsCubit;
  final ScoreboardFontCubit scoreboardFontCubit;
  final BoxPairingService boxPairingService;

  const PuntazoApp({
    super.key,
    required this.config,
    required this.teamService,
    required this.themeCubit,
    required this.debugSettingsCubit,
    required this.scoreboardFontCubit,
    required this.boxPairingService,
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
        RepositoryProvider.value(value: widget.boxPairingService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: widget.themeCubit),
          BlocProvider.value(value: widget.debugSettingsCubit),
          BlocProvider.value(value: widget.scoreboardFontCubit),
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

  /// Capa de lógica de app que traduce comandos (hardware o testing) a eventos.
  late final HardwareCommandHandler _commandHandler;

  // Overlay para testing manual de puntos
  bool _showTestingOverlay = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _commandHandler = HardwareCommandHandler(
      bloc: context.read<ScoringBloc>(),
      pairing: context.read<BoxPairingService>(),
    );
    _startUsbSerial();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _commandSub?.cancel();
    _connectionSub?.cancel();
    _usbListener?.stop();
    _commandHandler.dispose();
    super.dispose();
  }

  Future<void> _startUsbSerial() async {
    _usbListener = SimpleUsbSerialListener();

    // Estado de conexión USB → Cubit
    _connectionSub = _usbListener!.connectionStatus.listen((connected) {
      if (mounted) {
        context.read<UsbConnectionCubit>().setConnected(connected);
      }
    });

    // Comandos del hardware → misma capa de lógica que usa el overlay de testing
    _commandSub = _usbListener!.commands.listen(_commandHandler.handle);

    await _usbListener!.start();
  }

  @override
  Widget build(BuildContext context) {
    // Visibilidad del botón de depuración (configurable en Ajustes).
    final showDebugButton = context.watch<DebugSettingsCubit>().state;

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
          // Positioned(
          //   left: 12,
          //   top: 12,
          //   child: BlocBuilder<UsbConnectionCubit, UsbConnectionState>(
          //     builder: (context, state) {
          //       if (state.isConnected) return const SizedBox.shrink();

          //       return Container(
          //         padding: const EdgeInsets.symmetric(
          //           horizontal: 10,
          //           vertical: 6,
          //         ),
          //         decoration: BoxDecoration(
          //           color: Colors.red.withOpacity(0.85),
          //           borderRadius: BorderRadius.circular(16),
          //           boxShadow: [
          //             BoxShadow(
          //               color: Colors.black.withOpacity(0.3),
          //               blurRadius: 4,
          //               offset: const Offset(0, 2),
          //             ),
          //           ],
          //         ),
          //         child: const Row(
          //           mainAxisSize: MainAxisSize.min,
          //           children: [
          //             Icon(Icons.usb_off, color: Colors.white, size: 18),
          //             SizedBox(width: 6),
          //             Text(
          //               'Sin USB',
          //               style: TextStyle(
          //                 color: Colors.white,
          //                 fontSize: 12,
          //                 fontWeight: FontWeight.w600,
          //               ),
          //             ),
          //           ],
          //         ),
          //       );
          //     },
          //   ),
          // ),

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
          
          // Botón para mostrar/ocultar overlay de testing (depuración).
          // Se puede ocultar por completo desde Ajustes.
          if (showDebugButton)
            Positioned(
            bottom: 16,
            left: 16,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _showTestingOverlay = !_showTestingOverlay),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _showTestingOverlay 
                        ? Colors.orange.withValues(alpha: 0.8)
                        : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _showTestingOverlay ? Colors.orange : Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.bug_report,
                    color: _showTestingOverlay ? Colors.white : Colors.white70,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          
          // Overlay de testing: simula la botonera física usando la MISMA
          // capa de lógica (HardwareCommandHandler) que el hardware real.
          if (showDebugButton && _showTestingOverlay)
            Positioned(
              bottom: 70,
              left: 16,
              child: TestingOverlay(commandHandler: _commandHandler),
            ),

          // Overlay de confirmación de reinicio (por encima de todo).
          // Se muestra cuando el hardware envía RESET y espera que el árbitro
          // confirme con un botón/sensor de PUNTO (verde) o cancele con
          // cualquier otro botón (blanco/rojo).
          ValueListenableBuilder<bool>(
            valueListenable: _commandHandler.pendingReset,
            builder: (context, pending, _) {
              if (!pending) return const SizedBox.shrink();
              return _ResetConfirmOverlay(
                onConfirm: _commandHandler.performReset,
                onCancel: _commandHandler.cancelReset,
              );
            },
          ),
        ],
        ),
      ),
    );
  }
}

/// Instrucciones a pantalla completa para confirmar (o cancelar) el reinicio
/// del partido desde el hardware.
///
/// El árbitro pulsa el botón/sensor VERDE (comando de PUNTO) para reiniciar,
/// o cualquier botón BLANCO/ROJO para cancelar. Los botones táctiles son un
/// respaldo para pantallas con toque.
class _ResetConfirmOverlay extends StatelessWidget {
  const _ResetConfirmOverlay({
    required this.onConfirm,
    required this.onCancel,
  });

  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.amber,
              size: 72,
            ),
            const SizedBox(height: 16),
            const Text(
              '¿REINICIAR PARTIDO?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            const _ResetInstructionRow(
              color: Color(0xFF2ECC71),
              icon: Icons.check_circle,
              text: 'Botón/sensor VERDE (PUNTO) para REINICIAR',
            ),
            const SizedBox(height: 16),
            const _ResetInstructionRow(
              color: Color(0xFFE74C3C),
              icon: Icons.cancel,
              text: 'Botón BLANCO o ROJO para CANCELAR',
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ResetActionButton(
                  label: 'REINICIAR',
                  icon: Icons.check,
                  color: const Color(0xFF2ECC71),
                  onTap: onConfirm,
                ),
                const SizedBox(width: 24),
                _ResetActionButton(
                  label: 'CANCELAR',
                  icon: Icons.close,
                  color: const Color(0xFFE74C3C),
                  onTap: onCancel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResetInstructionRow extends StatelessWidget {
  const _ResetInstructionRow({
    required this.color,
    required this.icon,
    required this.text,
  });

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ResetActionButton extends StatelessWidget {
  const _ResetActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

