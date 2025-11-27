// lib/main.dart
// ============================================================================
// ⚡ MODO DEBUG: UI MÍNIMA PARA DETECTAR DELAYS
// Este main.dart está ULTRA-SIMPLIFICADO para medir latencia pura
// ============================================================================

import 'dart:async';
// ignore: unused_import
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: unused_import
import 'package:flutter_bloc/flutter_bloc.dart';
// ignore: unused_import
import 'package:wakelock_plus/wakelock_plus.dart';

// ignore: unused_import
import 'package:Puntazo/config/app_config.dart';
// ignore: unused_import
import 'package:Puntazo/config/app_theme.dart';
// ignore: unused_import
import 'package:Puntazo/config/config_loader.dart';
// ignore: unused_import
import 'package:Puntazo/config/team_selection_service.dart';
import 'package:Puntazo/features/ble/padel_ble_client.dart';
// ignore: unused_import
import 'package:Puntazo/features/ble/ble_full_telemetry_overlay.dart';
// ignore: unused_import
import 'package:Puntazo/features/ble/ble_realtime_monitor.dart';
// ignore: unused_import
import 'package:Puntazo/features/models/scoring_models.dart';
// ignore: unused_import
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
// ignore: unused_import
import 'package:Puntazo/features/scoring/bloc/scoring_event.dart';
// ignore: unused_import
import 'package:Puntazo/features/widgets/scoreboard.dart';
// ignore: unused_import
import 'package:Puntazo/features/widgets/referee_sidebar.dart';
// ignore: unused_import
import 'package:Puntazo/features/widgets/winner_overlay.dart';
// ignore: unused_import
import 'package:Puntazo/features/settings/match_settings_screen.dart';

// ============================================================================
// CLASES AUXILIARES NECESARIAS PARA OTRAS PARTES DEL CÓDIGO
// ============================================================================

/// Simple app-wide theme controller
class ThemeController {
  ThemeController(ThemeMode initial) : mode = ValueNotifier<ThemeMode>(initial);

  final ValueNotifier<ThemeMode> mode;

  void set(ThemeMode m) => mode.value = m;

  ThemeMode get current => mode.value;

  void dispose() => mode.dispose();
}

/// BLE capabilities helper (Android)
class BleCaps {
  final bool leCodedPhySupported;
  final bool le2MPhySupported;
  final bool leExtendedAdvSupported;
  final bool lePeriodicAdvSupported;
  final bool offloadedFilteringSupported;
  final bool offloadedBatchingSupported;

  const BleCaps({
    required this.leCodedPhySupported,
    required this.le2MPhySupported,
    required this.leExtendedAdvSupported,
    required this.lePeriodicAdvSupported,
    required this.offloadedFilteringSupported,
    required this.offloadedBatchingSupported,
  });

  static Future<BleCaps> query() async {
    // Stub implementation - real implementation would use platform channels
    return const BleCaps(
      leCodedPhySupported: false,
      le2MPhySupported: false,
      leExtendedAdvSupported: false,
      lePeriodicAdvSupported: false,
      offloadedFilteringSupported: false,
      offloadedBatchingSupported: false,
    );
  }

  bool get supportsLongRange => leCodedPhySupported;
  bool get supportsExtendedAdv => leExtendedAdvSupported;

  @override
  String toString() => 'BleCaps(LE Coded: $leCodedPhySupported, Extended Adv: $leExtendedAdvSupported)';
}

/// ============================================================================
/// ⚡ MAIN EN MODO DEBUG - UI MÍNIMA
/// ============================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // ▼ CAMBIAR AQUÍ PARA VOLVER A UI COMPLETA:
  runApp(const MinimalDebugApp()); // ← UI mínima
  
  // Para volver a la UI completa, descomentar esto y comentar lo de arriba:
  // final config = await ConfigLoader.load();
  // final teamSelection = await TeamSelectionService.init(config);
  // runApp(PadelApp(config: config, teamSelection: teamSelection));
}
/// ============================================================================
/// CLASES AUXILIARES (necesarias para otras partes del código)
/// ============================================================================

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

/// ============================================================================
/// ⚡ MINIMAL DEBUG APP - UI ULTRA-SIMPLE PARA DETECTAR DELAYS
/// ============================================================================

class MinimalDebugApp extends StatelessWidget {
  const MinimalDebugApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const MinimalDebugScreen(),
    );
  }
}

class MinimalDebugScreen extends StatefulWidget {
  const MinimalDebugScreen({super.key});

  @override
  State<MinimalDebugScreen> createState() => _MinimalDebugScreenState();
}

class _MinimalDebugScreenState extends State<MinimalDebugScreen> {
  final PadelBleClient _ble = PadelBleClient();
  StreamSubscription<String>? _cmdSub;
  StreamSubscription<BleFrame>? _rawSub;
  bool _bleReady = false; // ⚡ Flag para saber si BLE está inicializado
  
  // Para cada comando: nombre y su latencia individual (microsegundos)
  final List<MapEntry<String, int>> _commandsWithLatency = [];
  final Map<int, int> _rawArrivalTimes = {}; // ⚡ Clave = seq (int), no "cmd:seq"
  int _maxLatencyUs = 0;
  
  // Contador de secuencia para comandos de test
  int _testSeqCounter = 1;
  
  final ScrollController _processedScrollCtrl = ScrollController();
  
  // ⚡ NUEVO: Campo de comando manual
  final TextEditingController _manualCtrl = TextEditingController();

  @override
  void dispose() {
    _cmdSub?.cancel();
    _rawSub?.cancel();
    _processedScrollCtrl.dispose();
    _manualCtrl.dispose();
    _ble.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    
    () async {
      try {
        await _ble.init();
        await _ble.startListening();
        
        // ⚡ Capturar timestamp de llegada para cálculo E2E
        _rawSub = _ble.rawFrames.listen((frame) {
          // ⚡ FIX: Usar seq como clave (independiente del mapeo p→a/b)
          if (kDebugMode) print('[DEBUG RAW] seq=${frame.seq} timestampUs=${frame.timestampUs}');
          _rawArrivalTimes[frame.seq] = frame.timestampUs;
          if (kDebugMode) print('[DEBUG RAW] Stored in map. Map size: ${_rawArrivalTimes.length}');
        });
        
        // ⚡ PROCESADO: Comandos listos para actualizar UI
        _cmdSub = _ble.commands.listen((cmd) {
          if (kDebugMode) print('[DEBUG LISTENER] Received command: $cmd');
          
          // ⚡ TIMESTAMP FINAL: Capturar AQUÍ cuando llega a la UI (fin del pipeline)
          final int finalTimestamp = DateTime.now().microsecondsSinceEpoch;
          
          // Extraer displayCmd (formato puede ser "cmd:seq@timestamp" o "cmd:seq")
          String displayCmd;
          if (cmd.contains('@')) {
            final parts = cmd.split('@');
            displayCmd = parts[0];
          } else {
            displayCmd = cmd;
          }
          
          // ⚡ FIX: Extraer seq del comando y buscar por seq (no por "cmd:seq")
          int latencyUs = 0;
          if (displayCmd.contains(':')) {
            final seq = int.tryParse(displayCmd.split(':')[1]);
            if (kDebugMode) print('[DEBUG LATENCY] Extracted seq: $seq from displayCmd: $displayCmd');
            if (seq != null) {
              final rawTime = _rawArrivalTimes[seq];
              if (kDebugMode) print('[DEBUG LATENCY] Lookup seq=$seq → rawTime=$rawTime, finalTimestamp=$finalTimestamp');
              if (rawTime != null) {
                latencyUs = finalTimestamp - rawTime; // T_final - T_inicial
                if (kDebugMode) print('[DEBUG LATENCY] Calculated latencyUs: $latencyUs (${latencyUs/1000}ms)');
                _rawArrivalTimes.remove(seq);
              } else {
                if (kDebugMode) print('[DEBUG LATENCY] No rawTime found for seq=$seq. Map contents: $_rawArrivalTimes');
              }
            }
          }
          
          setState(() {
            _commandsWithLatency.add(MapEntry(displayCmd, latencyUs));
            if (latencyUs > _maxLatencyUs) _maxLatencyUs = latencyUs;
            
            // Auto-scroll
            Future.microtask(() {
              if (_processedScrollCtrl.hasClients) {
                _processedScrollCtrl.animateTo(
                  _processedScrollCtrl.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
                );
              }
            });
          });
        });
        
        // ⚡ Marcar como listo DESPUÉS de suscribir listeners
        setState(() {
          _bleReady = true;
        });
        if (kDebugMode) print('[DEBUG] BLE listeners ready');
      } catch (e) {
        if (kDebugMode) print('[ERROR] BLE init failed: $e');
      }
    }();
  }
  
  // ⚡ NUEVO: Limpiar logs y resetear métricas
  void _clearLogs() {
    _commandsWithLatency.clear();
    _rawArrivalTimes.clear();
    _maxLatencyUs = 0;
    _testSeqCounter = 1; // Resetear contador
  }
  
  // ⚡ TEST BLE: Enviar un comando que pasa por todo el pipeline BLE (_onDevice)
  void _sendBluetoothCommand() {
    if (!_bleReady) {
      if (kDebugMode) print('[DEBUG] BLE not ready yet, ignoring...');
      return;
    }
    // Incrementar secuencia para evitar dedup
    final seq = _testSeqCounter++;
    if (kDebugMode) print('[DEBUG] Sending test command: a:$seq');
    _ble.emitBluetoothCommand('a:$seq');
  }
  
  // ⚡ NUEVO: Enviar comando manual (simula BLE completo)
  void _sendManualCommand() {
    if (!_bleReady) {
      if (kDebugMode) print('[DEBUG] BLE not ready yet, ignoring...');
      return;
    }
    final text = _manualCtrl.text.trim();
    if (text.isEmpty) return;
    if (!text.contains(':')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Formato: "c:nnn" (ej: "a:5")'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    _ble.emitBluetoothCommand(text);
    _manualCtrl.clear();
  }
  


  @override
  Widget build(BuildContext context) {
    final double maxLatencyMs = _maxLatencyUs / 1000.0;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Header compacto
            const Text(
              '🔬 DEBUG BLE - Latencia de Procesamiento',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            
            // ⚡ CONTROLES: Test BLE + Limpiar + Manual
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _sendBluetoothCommand,
                  icon: const Icon(Icons.bluetooth, size: 16),
                  label: const Text('Test BLE', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: () => setState(_clearLogs),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Limpiar', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _manualCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Manual (ej: a:5)',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sendManualCommand(),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: _sendManualCommand,
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Enviar', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // ⚡ MÉTRICA: Latencia máxima observada
            _MetricChip(
              label: 'Latencia máxima',
              valueMs: maxLatencyMs,
            ),
            
            const SizedBox(height: 12),
            
            // Lista de comandos con su latencia individual
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '⚡ COMANDOS (con latencia individual)',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          Text(
                            '${_commandsWithLatency.length}',
                            style: const TextStyle(fontSize: 13, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    // Lista scrollable
                    Expanded(
                      child: ListView.builder(
                        controller: _processedScrollCtrl,
                        padding: const EdgeInsets.all(6),
                        itemCount: _commandsWithLatency.length,
                        itemBuilder: (_, i) {
                          final entry = _commandsWithLatency[i];
                          final cmd = entry.key;
                          final latencyUs = entry.value;
                          final latencyMs = latencyUs / 1000.0;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.green.withOpacity(0.3), width: 0.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${i + 1}. $cmd',
                                  style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${latencyMs.toStringAsFixed(2)}ms',
                                  style: TextStyle(
                                    color: latencyUs > 10000 ? Colors.red : latencyUs > 5000 ? Colors.yellow : Colors.green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ⚡ Widget para mostrar métricas de latencia
class _MetricChip extends StatelessWidget {
  final String label;
  final double valueMs;

  const _MetricChip({required this.label, required this.valueMs});

  @override
  Widget build(BuildContext context) {
    final bool high = valueMs > 100.0;
    final bool medium = valueMs > 50.0 && valueMs <= 100.0;
    final Color color = high ? Colors.red : medium ? Colors.yellow : Colors.green;
    return Chip(
      backgroundColor: color.withOpacity(0.2),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      label: Text(
        '$label: ${valueMs.toStringAsFixed(1)}ms',
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}
