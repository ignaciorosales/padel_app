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
import 'package:Puntazo/features/usb_serial/diagnostics_screen.dart';
import 'package:Puntazo/features/usb_serial/hardware_health.dart';
import 'package:Puntazo/features/usb_serial/simple_usb_serial_listener.dart';
import 'package:Puntazo/features/usb_serial/usb_connection_cubit.dart';
import 'package:Puntazo/features/usb_serial/usb_diagnostic_widget.dart';
import 'package:Puntazo/features/widgets/box_setup_wizard.dart';
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
  StreamSubscription<String>? _debugSub;

  /// Capa de lógica de app que traduce comandos (hardware o testing) a eventos.
  late final HardwareCommandHandler _commandHandler;

  /// Estado del panel de diagnóstico USB (ver Ajustes > mostrar botón debug).
  /// Se alimenta de los streams de [SimpleUsbSerialListener] para que en una
  /// instalación real se pueda ver EN PANTALLA en qué etapa falla la
  /// comunicación (sin dispositivo / detectado / conectado sin datos /
  /// recibiendo pero mal formateado / operativo) en lugar de tener que
  /// adivinarlo a ciegas.
  final ValueNotifier<UsbDiagnosticInfo> _usbDiagnostic =
      ValueNotifier(const UsbDiagnosticInfo());

  /// Salud del hardware: consume la telemetría por caja que envía el maestro
  /// (`[PS]`/`[MS]`) y la convierte en un diagnóstico accionable. Alimenta la
  /// pantalla de Diagnóstico, pensada para la instalación en pista.
  late final HardwareHealthMonitor _health;

  StreamSubscription<int>? _deviceCountSub;

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
    _health = HardwareHealthMonitor(
      onSend: (line) async => _usbListener?.send(line),
    )..addListener(_onHealthChanged);
    // Al terminar el asistente, el maestro olvida las cajas no pulsadas.
    context.read<BoxPairingService>().onSetupSaved =
        (line) => _usbListener?.send(line);
    _startUsbSerial();
  }

  /// Ya se miró si había que abrir el asistente de cajas en esta sesión.
  bool _setupChecked = false;

  /// Se llama al menos cada segundo mientras hay USB (watchdog del monitor).
  void _onHealthChanged() {
    // Primera vez que el maestro habla: sin cajas emparejadas, abrir el
    // asistente. Solo una vez por arranque, para no reabrirlo si se cancela.
    if (!_setupChecked && _health.masterAlive) {
      _setupChecked = true;
      final pairing = context.read<BoxPairingService>();
      if (!pairing.hasPairedBoxes) pairing.startSetup();
    }

    // Puerto abierto pero el maestro lleva 10 s sin decir nada (normalmente
    // habla cada 2 s): soltar el puerto y dejar que el reintento lo reabra.
    // Al desconectar se olvida la última línea, así que no se repite en
    // bucle si después de reabrir sigue sin llegar nada.
    final silence = _health.sinceLastLine;
    if (_health.usbConnected && silence != null && silence.inSeconds >= 10) {
      _usbListener?.reconnect();
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _commandSub?.cancel();
    _connectionSub?.cancel();
    _debugSub?.cancel();
    _deviceCountSub?.cancel();
    _usbListener?.stop();
    _commandHandler.dispose();
    _usbDiagnostic.dispose();
    _health.dispose();
    super.dispose();
  }

  void _appendDiagnosticLog(String log) {
    final logs = List<String>.of(_usbDiagnostic.value.recentLogs)..add(log);
    if (logs.length > 50) logs.removeRange(0, logs.length - 50);
    _usbDiagnostic.value = _usbDiagnostic.value.copyWith(recentLogs: logs);
  }

  Future<void> _startUsbSerial() async {
    _usbListener = SimpleUsbSerialListener();

    // Estado de conexión USB → Cubit + diagnóstico
    _connectionSub = _usbListener!.connectionStatus.listen((connected) {
      if (mounted) {
        context.read<UsbConnectionCubit>().setConnected(connected);
      }
      _usbDiagnostic.value = _usbDiagnostic.value.copyWith(
        isConnected: connected,
        deviceName: connected ? _usbListener!.deviceName : null,
        state:
            connected
                ? UsbDiagnosticState.connectedNoData
                : UsbDiagnosticState.noDevice,
      );
      _health.setUsbConnected(connected, deviceName: _usbListener!.deviceName);
      _health.setUsbError(_usbListener!.lastError);
    });

    // Cuántos dispositivos USB ve Android: distingue "no hay nada enchufado"
    // de "está enchufado pero el puerto no abre" (permiso sin aceptar).
    _deviceCountSub = _usbListener!.deviceCount.listen(_health.setUsbDevicesFound);

    // Logs internos del listener (dispositivos encontrados, TX/RX, errores)
    _debugSub = _usbListener!.debugMessages.listen((msg) {
      _appendDiagnosticLog(msg);
      _health.ingestLine(msg);

      if (msg.startsWith('ESP32:')) {
        // Línea cruda del ESP32 (debug, no necesariamente un comando válido).
        final current = _usbDiagnostic.value;
        _usbDiagnostic.value = current.copyWith(
          state:
              current.state == UsbDiagnosticState.fullyOperational
                  ? current.state
                  : UsbDiagnosticState.connectedReceiving,
          bytesReceived: current.bytesReceived + msg.length,
          lastDataTime: DateTime.now(),
        );
      } else if (msg.contains('dispositivos USB encontrados') &&
          !msg.startsWith('0 ') &&
          _usbDiagnostic.value.state == UsbDiagnosticState.noDevice) {
        _usbDiagnostic.value = _usbDiagnostic.value.copyWith(
          state: UsbDiagnosticState.deviceFound,
        );
      } else if (msg.startsWith('No se pudo conectar')) {
        _usbDiagnostic.value = _usbDiagnostic.value.copyWith(
          state: UsbDiagnosticState.noDevice,
          lastError: msg,
        );
      }
    });

    // Comandos del hardware → misma capa de lógica que usa el overlay de testing
    _commandSub = _usbListener!.commands.listen((cmd) {
      _health.ingestCommand(cmd);

      // Con el modo prueba activo (pantalla de Diagnóstico) las pulsaciones
      // se registran para verificar la botonera pero NO puntúan: si no,
      // comprobar los botones durante la instalación destrozaría el marcador.
      if (!_health.buttonTestMode) {
        _commandHandler.handle(cmd);
      }

      _usbDiagnostic.value = _usbDiagnostic.value.copyWith(
        state: UsbDiagnosticState.fullyOperational,
        commandsReceived: _usbDiagnostic.value.commandsReceived + 1,
        lastCommand: cmd,
        lastDataTime: DateTime.now(),
      );
    });

    await _usbListener!.start();
  }

  @override
  Widget build(BuildContext context) {
    // Visibilidad del botón de depuración (configurable en Ajustes).
    final showDebugButton = context.watch<DebugSettingsCubit>().state;

    return BlocListener<ScoringBloc, ScoringState>(
      // Al cerrar un set los jugadores cambian de lado; al deshacer el punto
      // que lo cerró, vuelven al suyo.
      listenWhen: ScoringBloc.needsSideSwap,
      listener: (context, state) {
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

          // Panel de diagnóstico USB: mismo gate que el overlay de testing
          // (Ajustes > mostrar botón debug) para no ensuciar la pantalla en
          // uso normal, pero visible durante una instalación/prueba para ver
          // en qué etapa falla la comunicación con el maestro.
          if (showDebugButton)
            Positioned(
              left: 12,
              top: 12,
              child: UsbDiagnosticWidget(diagnosticNotifier: _usbDiagnostic),
            ),

          // Acceso directo al diagnóstico del hardware. Siempre visible: es
          // la pantalla que hace falta durante una instalación, justo cuando
          // el modo debug todavía no está activado.
          Positioned(
            bottom: 16,
            right: 74,
            child: _HealthBadge(
              health: _health,
              onTap: () => DiagnosticsScreen.open(context, _health),
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

          // Avisos que impiden jugar: grandes y permanentes mientras duren.
          ListenableBuilder(
            listenable: Listenable.merge([
              _health,
              context.read<BoxPairingService>().pairings,
              context.read<BoxPairingService>().unpairedBoxes,
              context.read<BoxPairingService>().setup,
            ]),
            builder: (context, _) {
              final pairing = context.read<BoxPairingService>();
              return Positioned(
                top: 24,
                left: 48,
                right: 48,
                child: Column(
                  children: [
                    // Android vuelve a mostrar su diálogo en cada reintento
                    // (cada 3 s), así que el aviso explica qué pulsar en él.
                    if (_health.usbPermissionMissing)
                      const _BlockingBanner(
                        icon: Icons.usb_off,
                        title: 'Las cajas NO funcionan: falta el permiso USB',
                        body: 'Cuando aparezca el aviso de Android, marca «Usar '
                            'de forma predeterminada» y pulsa ACEPTAR. Si no '
                            'aparece, desenchufa el cable USB del maestro y '
                            'vuelve a enchufarlo.',
                      ),
                    // Sin cajas emparejadas ninguna pulsación puntúa.
                    if (!pairing.hasPairedBoxes && pairing.setup.value == null)
                      _BlockingBanner(
                        icon: Icons.sports_esports,
                        title: 'Las cajas NO puntúan: no están configuradas',
                        body: 'Hay que decir en qué lado de la pista está cada '
                            'caja. Se hace una sola vez y lleva un minuto.',
                        action: FilledButton(
                          onPressed: pairing.startSetup,
                          child: const Text('Configurar cajas'),
                        ),
                      ),
                    // Se ha pulsado una caja que no está emparejada: una
                    // caja nueva, una cambiada, o todas tras reflashear (el
                    // ID de fábrica no es el que se emparejó).
                    if (pairing.hasPairedBoxes &&
                        pairing.unpairedBoxes.value.isNotEmpty &&
                        pairing.setup.value == null)
                      _BlockingBanner(
                        icon: Icons.add_circle_outline,
                        title: 'Hay cajas sin configurar',
                        body: 'Sus puntos no cuentan hasta configurarlas: '
                            '${pairing.unpairedBoxes.value.map((id) => id.toUpperCase()).join(', ')}.',
                        action: FilledButton(
                          onPressed: pairing.startSetup,
                          child: const Text('Configurar cajas'),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // Asistente de cajas: por encima del marcador, mientras esté abierto.
          ValueListenableBuilder(
            valueListenable: context.read<BoxPairingService>().setup,
            builder: (context, setup, _) => setup == null
                ? const SizedBox.shrink()
                : BoxSetupWizard(
                    pairing: context.read<BoxPairingService>(),
                    health: _health,
                  ),
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

/// Indicador permanente del estado del hardware, abajo a la derecha.
///
/// Su color resume la cadena completa de un vistazo, sin abrir nada: rojo si
/// el maestro no está o no responde, ámbar si falta alguna caja, verde si
/// todo contesta. Al pulsarlo abre el diagnóstico detallado.
class _HealthBadge extends StatelessWidget {
  const _HealthBadge({required this.health, required this.onTap});

  final HardwareHealthMonitor health;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: health,
      builder: (context, _) {
        final master = health.master;
        final Color color;
        if (!health.usbConnected || !health.masterAlive) {
          color = const Color(0xFFE74C3C);
        } else if (master == null || master.onlineCount < master.slaveCount) {
          color = const Color(0xFFF39C12);
        } else {
          color = const Color(0xFF2ECC71);
        }

        // Texto visible desde la pista: qué falta. Solo cuenta las cajas con
        // equipo asignado; una caja sin emparejar no afecta al partido.
        final pairings = context.read<BoxPairingService>().pairings.value;
        final down = health.boxes
            .where((b) =>
                !b.online &&
                (pairings[b.id] ?? BoxPairingService.unassigned) !=
                    BoxPairingService.unassigned)
            .map((b) => b.id.toUpperCase())
            .toList();
        final String? label = health.usbPermissionMissing
            ? 'Falta permiso USB'
            : !health.usbConnected
                ? 'Maestro desconectado'
                : !health.masterAlive
                    ? 'Maestro sin responder'
                    : down.isEmpty
                        ? null
                        : down.length == 1
                            ? 'Caja ${down.first} desconectada'
                            : 'Cajas ${down.join(', ')} desconectadas';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (label != null) ...[
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(Icons.settings_input_antenna, color: color, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Aviso rojo de algo que impide jugar (falta el permiso USB, cajas sin
/// configurar). No se puede cerrar: desaparece solo cuando se arregla.
class _BlockingBanner extends StatelessWidget {
  const _BlockingBanner({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFFC0392B),
        borderRadius: BorderRadius.circular(16),
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 48),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
              if (action != null) ...[const SizedBox(width: 20), action!],
            ],
          ),
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

