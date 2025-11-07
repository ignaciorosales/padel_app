// lib/main.dart

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:Puntazo/config/app_config.dart';
import 'package:Puntazo/config/app_theme.dart';
import 'package:Puntazo/config/config_loader.dart';
import 'package:Puntazo/config/team_selection_service.dart';
import 'package:Puntazo/features/ble/padel_ble_client.dart';
import 'package:Puntazo/features/ble/ble_full_telemetry_overlay.dart';
import 'package:Puntazo/features/ble/ble_realtime_monitor.dart';
import 'package:Puntazo/features/models/scoring_models.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_event.dart';
import 'package:Puntazo/features/widgets/scoreboard.dart'; // ▲ OPTIMIZADO
import 'package:Puntazo/features/widgets/referee_sidebar.dart';
import 'package:Puntazo/features/widgets/winner_overlay.dart';
import 'package:Puntazo/features/settings/match_settings_screen.dart';

// == BLE CAPS (DART + METHOD CHANNEL) ==========================
class BleCaps {
  final bool? leCodedPhySupported;
  final bool? le2MPhySupported;
  final bool? leExtendedAdvSupported;
  final bool? lePeriodicAdvSupported;
  final bool? offloadedFilteringSupported;
  final bool? offloadedBatchingSupported;

  BleCaps({
    required this.leCodedPhySupported,
    required this.le2MPhySupported,
    required this.leExtendedAdvSupported,
    required this.lePeriodicAdvSupported,
    required this.offloadedFilteringSupported,
    required this.offloadedBatchingSupported,
  });

  bool get supportsLongRange => leCodedPhySupported == true;
  bool get supportsExtendedAdv => leExtendedAdvSupported == true;

  static const _ch = MethodChannel('ble_caps');

  static Future<BleCaps> query() async {
    if (!Platform.isAndroid) {
      return BleCaps(
        leCodedPhySupported: null,
        le2MPhySupported: null,
        leExtendedAdvSupported: null,
        lePeriodicAdvSupported: null,
        offloadedFilteringSupported: null,
        offloadedBatchingSupported: null,
      );
    }
    final m = Map<dynamic, dynamic>.from(await _ch.invokeMethod('queryCaps'));
    bool? b(dynamic v) => v is bool ? v : null;
    return BleCaps(
      leCodedPhySupported: b(m['isLeCodedPhySupported']),
      le2MPhySupported: b(m['isLe2MPhySupported']),
      leExtendedAdvSupported: b(m['isLeExtendedAdvertisingSupported']),
      lePeriodicAdvSupported: b(m['isLePeriodicAdvertisingSupported']),
      offloadedFilteringSupported: b(m['isOffloadedFilteringSupported']),
      offloadedBatchingSupported: b(m['isOffloadedBatchingSupported']),
    );
  }

  @override
  String toString() =>
      'LE Coded: $leCodedPhySupported | LE 2M: $le2MPhySupported | '
      'Extended Adv: $leExtendedAdvSupported | Periodic Adv: $lePeriodicAdvSupported | '
      'Offloaded Filtering: $offloadedFilteringSupported | Offloaded Batching: $offloadedBatchingSupported';
}
// ==============================================================

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
  
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    final config = await ConfigLoader.load();
    final teamSelection = await TeamSelectionService.init(config);
    runApp(PadelApp(config: config, teamSelection: teamSelection));
  } catch (e, st) {
    // ▲ CRASH SAFETY: Si falla la carga inicial, mostrar error en pantalla
    print('[❌ FATAL] Error during app initialization: $e');
    print('[❌ FATAL] Stack trace: $st');
    
    // Intentar mostrar un error visual (MaterialApp mínimo)
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 24),
                  const Text(
                    'Error al inicializar la aplicación',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    e.toString(),
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Por favor, reinicia la aplicación.',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
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
          final starting =
              (cfg.rules.startingServerId == 'team2') ? Team.red : Team.blue;

          bloc.add(
            ScoringEvent.newMatch(
              startingServer: starting,
              settings: MatchSettings(
                goldenPoint: cfg.rules.goldenPoint,
                // 6 para TB en 6-6, 1 para Super TB en 3er set
                tieBreakAtGames: cfg.rules.tiebreakAtSixSix ? 6 : 1,
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

class _ScoreOnlyScreenState extends State<_ScoreOnlyScreen> with WidgetsBindingObserver {
  final PadelBleClient _ble = PadelBleClient();
  StreamSubscription<String>? _cmdSub;
  final ValueNotifier<bool> _refSidebarVisible = ValueNotifier<bool>(false);
  bool _restartDialogOpen = false;
  BleCaps? _caps; // capacidades BLE del dispositivo (Android)

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ble.restartArmed.removeListener(_onRestartArmedChanged);
    _cmdSub?.cancel();
    _refSidebarVisible.dispose();
    
    // ▲ WAKELOCK: Liberar wakelock al salir
    WakelockPlus.disable();
    
    // Async dispose: usar unawaited o Future.microtask
    Future.microtask(() => _ble.dispose());
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // ▲ WAKELOCK: Mantener CPU despierta durante el partido (evita throttling extremo)
    WakelockPlus.enable();
    
    () async {
      try {
        await _ble.init();
        await _ble.startListening();
        await _checkBleCaps(); // consulta capacidades

        _cmdSub = _ble.commands.listen(
          (cmd) => context.read<ScoringBloc>().add(ScoringEvent.bleCommand(cmd)),
        );

        // Listener para mostrar diálogo de restart
        _ble.restartArmed.addListener(_onRestartArmedChanged);
      } catch (e, st) {
        // ▲ CRASH SAFETY: Si falla la inicialización de BLE, loguear pero continuar
        if (kDebugMode) {
          debugPrint('[APP] ⚠️ Error during BLE init: $e');
          debugPrint('[APP] Stack trace: $st');
          debugPrint('[APP] App will continue without BLE...');
        }
        // Mostrar snackbar al usuario
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Error al inicializar BLE. Revisa permisos.'),
              duration: Duration(seconds: 5),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // ▲ LIFECYCLE: Reiniciar scan cuando la app vuelve a primer plano
      //   Algunos TV boxes suspenden callbacks BLE en background
      if (kDebugMode) debugPrint('[APP] 🔄 Resumed, kicking BLE scan...');
      // Usar el método seguro que evita carreras
      _ble.safeRestartScan();
    }
  }

  Future<void> _checkBleCaps() async {
    try {
      final caps = await BleCaps.query();
      _caps = caps;
      // DEBUG LOGS
      // ignore: avoid_print
      print('[BLE CAPS] $caps');

      // Feedback visual rápido (solo si el widget sigue montado)
      if (!mounted) return;
      final lr = (caps.supportsLongRange)
          ? 'SÍ'
          : (caps.leCodedPhySupported == false ? 'NO' : 'DESCONOCIDO');
      final ext = (caps.supportsExtendedAdv)
          ? 'SÍ'
          : (caps.leExtendedAdvSupported == false ? 'NO' : 'DESCONOCIDO');
      final msg = 'LE Coded PHY: $lr   |   Extended Adv: $ext';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('[BLE CAPS] error: $e\n$st');
    }
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
    _refSidebarVisible.value = !_refSidebarVisible.value;
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.f1): const ActivateIntent()
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
            _toggleRefPanel();
            return null;
          }),
        },
        child: FocusScope(
          skipTraversal: true, // Evitar que el Scaffold capture focus
          child: Stack(
            children: [
              // Scaffold principal (contenido de la app)
              Scaffold(
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
                                child:                 const Scoreboard(), // ▲ Versión optimizada con BlocSelector
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
                            ? MediaQuery.of(context).size.width *
                                0.1 // 10% del ancho cuando el panel está abierto
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
                                icon:
                                    isVisible ? Icons.chevron_right : Icons.sports,
                                tooltip: isVisible
                                    ? 'Ocultar panel árbitro (F1)'
                                    : 'Mostrar panel árbitro (F1)',
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
                floatingActionButtonLocation:
                    FloatingActionButtonLocation.endFloat,
              ),
              
              // Monitor BLE en tiempo real (overlay de producción)
              BleRealtimeMonitor(bleClient: _ble),
              
              // ▼ SOLO PARA TESTING/DESARROLLO (comentar en producción)
              // BleFullTelemetryOverlay(bleClient: _ble, child: const SizedBox.shrink()),
            ], // Cierra children del Stack
          ), // Cierra Stack (child de FocusScope)
        ), // Cierra FocusScope (child de Actions)
      ), // Cierra Actions (child de Shortcuts)
    ); // Cierra Shortcuts (return del build)
  } // Cierra build method
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
    // DEBUG focus
    // ignore: avoid_print
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
            const Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 64),
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
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Colors.white70),
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
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
