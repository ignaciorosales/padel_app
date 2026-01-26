import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:Puntazo/config/config_loader.dart';
import 'package:Puntazo/config/app_config.dart';
import 'package:Puntazo/config/app_theme.dart';
import 'package:Puntazo/config/team_selection_service.dart';
import 'package:Puntazo/features/models/scoring_models.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_event.dart';
import 'package:Puntazo/features/usb_serial/simple_usb_serial_listener.dart';
import 'package:Puntazo/features/usb_serial/usb_diagnostic_widget.dart';
import 'package:Puntazo/features/widgets/scoreboard.dart';
import 'package:Puntazo/features/widgets/winner_overlay.dart';
import 'package:Puntazo/features/widgets/referee_sidebar.dart';
import 'package:Puntazo/features/widgets/control_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  
  // Cargar configuración
  final config = await ConfigLoader.load();
  
  // Inicializar TeamSelectionService de forma asíncrona
  final teamService = await TeamSelectionService.init(config);
  
  runApp(PuntazoApp(config: config, teamService: teamService));
}

class PuntazoApp extends StatelessWidget {
  final AppConfig config;
  final TeamSelectionService teamService;
  
  const PuntazoApp({
    super.key, 
    required this.config,
    required this.teamService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: config),
        RepositoryProvider.value(value: teamService),
      ],
      child: BlocProvider(
        create: (context) {
          final settings = MatchSettings(
            setsToWin: config.rules.setsToWin,
            goldenPoint: config.rules.goldenPoint,
            tieBreakAtGames: config.rules.tiebreakAtSixSix ? 6 : 12,
          );
          
          final startingServer = config.rules.startingServerId == 'team1' 
              ? Team.blue 
              : Team.red;
          
          return ScoringBloc()
            ..add(ScoringEvent.newMatch(
              settings: settings,
              startingServer: startingServer,
            ));
        },
        child: MaterialApp(
          title: 'Puntazo',
          debugShowCheckedModeBanner: false,
          theme: _buildLightTheme(config),
          darkTheme: _buildDarkTheme(config),
          themeMode: ThemeMode.dark,
          home: const MatchScreen(),
        ),
      ),
    );
  }

  ThemeData _buildLightTheme(AppConfig config) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      extensions: [PadelThemeExtension.fromConfig(config)],
    );
  }

  ThemeData _buildDarkTheme(AppConfig config) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      extensions: [PadelThemeExtension.fromConfig(config)],
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
  StreamSubscription<String>? _debugSub;
  StreamSubscription<bool>? _connectionSub;
  
  final ValueNotifier<bool> _sidebarVisible = ValueNotifier(false);
  
  // Diagnóstico USB mejorado
  final ValueNotifier<UsbDiagnosticInfo> _usbDiagnostic = ValueNotifier(
    const UsbDiagnosticInfo(),
  );
  
  // Control de visibilidad del panel de diagnóstico expandido
  final ValueNotifier<bool> _showDiagnosticPanel = ValueNotifier(false);
  
  // Logs para diagnóstico (últimos 10)
  final List<String> _recentLogs = [];
  
  void _updateDiagnostic({
    UsbDiagnosticState? state,
    bool? isConnected,
    int? addBytes,
    int? addCommands,
    int? addErrors,
    String? lastCommand,
    String? lastError,
    String? deviceName,
    bool updateDataTime = false,
  }) {
    final current = _usbDiagnostic.value;
    _usbDiagnostic.value = current.copyWith(
      state: state,
      isConnected: isConnected,
      bytesReceived: addBytes != null ? current.bytesReceived + addBytes : null,
      commandsReceived: addCommands != null ? current.commandsReceived + addCommands : null,
      packetsWithErrors: addErrors != null ? current.packetsWithErrors + addErrors : null,
      lastCommand: lastCommand,
      lastError: lastError,
      deviceName: deviceName,
      lastDataTime: updateDataTime ? DateTime.now() : null,
      recentLogs: List.from(_recentLogs),
    );
  }
  
  void _addLog(String line) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    _recentLogs.add('[$timestamp] $line');
    if (_recentLogs.length > 25) _recentLogs.removeAt(0);
    
    // Actualizar el notifier con los logs recientes
    final current = _usbDiagnostic.value;
    _usbDiagnostic.value = current.copyWith(
      recentLogs: List.from(_recentLogs),
    );
  }

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
    _debugSub?.cancel();
    _connectionSub?.cancel();
    _usbListener?.stop();
    _sidebarVisible.dispose();
    _usbDiagnostic.dispose();
    _showDiagnosticPanel.dispose();
    super.dispose();
  }

  Future<void> _startUsbSerial() async {
    _usbListener = SimpleUsbSerialListener();
    _addLog('Iniciando USB Serial (SIMPLE)...');
    _updateDiagnostic(state: UsbDiagnosticState.noDevice);
    
    // Escuchar estado de conexión
    _connectionSub = _usbListener!.connectionStatus.listen((connected) {
      if (connected) {
        _addLog('✅ USB CONECTADO');
        _updateDiagnostic(
          isConnected: true,
          state: UsbDiagnosticState.connectedNoData,
        );
      } else {
        _addLog('❌ USB DESCONECTADO');
        _updateDiagnostic(
          isConnected: false,
          state: UsbDiagnosticState.noDevice,
        );
      }
    });
    
    // Escuchar comandos USB y enviarlos al BLoC
    _commandSub = _usbListener!.commands.listen((cmd) {
      if (!mounted) return;
      
      debugPrint('🎮 [USB CMD] Received: $cmd');
      
      // Validar que el comando no esté vacío
      if (cmd.isEmpty) {
        _addLog('⚠️ CMD vacío recibido');
        _updateDiagnostic(addErrors: 1, lastError: 'Comando vacío');
        return;
      }
      
      // Validar longitud razonable
      if (cmd.length > 20) {
        final hexRepr = cmd.codeUnits.take(20).map((c) => c.toRadixString(16).padLeft(2, '0')).join(' ');
        _addLog('⚠️ CMD muy largo: ${cmd.length} chars');
        _addLog('   → preview: ${cmd.substring(0, 20)}...');
        _addLog('   → hex: $hexRepr');
        _updateDiagnostic(addErrors: 1, lastError: 'Comando muy largo: ${cmd.length}');
        return;
      }
      
      // Limpiar el comando (trim whitespace, normalize)
      final cleanCmd = cmd.trim().toUpperCase();
      
      _addLog('🎮 CMD: $cleanCmd');
      
      // Actualizar diagnóstico - comando recibido
      _updateDiagnostic(
        state: UsbDiagnosticState.fullyOperational,
        addCommands: 1,
        lastCommand: cleanCmd,
        updateDataTime: true,
      );
      
      final bloc = context.read<ScoringBloc>();
      
      // Mapear comandos USB nativos a eventos del BLoC
      switch (cleanCmd) {
        case 'P_A':
          debugPrint('🎮 [USB CMD] -> pointFor(Team.blue)');
          _addLog('✅ P_A → Punto Azul');
          bloc.add(const ScoringEvent.pointFor(Team.blue));
          break;
        case 'P_B':
          debugPrint('🎮 [USB CMD] -> pointFor(Team.red)');
          _addLog('✅ P_B → Punto Rojo');
          bloc.add(const ScoringEvent.pointFor(Team.red));
          break;
        case 'UNDO_A':
          debugPrint('🎮 [USB CMD] -> undoForTeam(Team.blue)');
          _addLog('✅ UNDO_A → Deshacer Azul');
          bloc.add(const ScoringEvent.undoForTeam(Team.blue));
          break;
        case 'UNDO_B':
          debugPrint('🎮 [USB CMD] -> undoForTeam(Team.red)');
          _addLog('✅ UNDO_B → Deshacer Rojo');
          bloc.add(const ScoringEvent.undoForTeam(Team.red));
          break;
        case 'RESET':
        case 'RESET_GAME':
          debugPrint('🎮 [USB CMD] -> newMatch()');
          _addLog('✅ RESET → Nuevo partido');
          bloc.add(const ScoringEvent.newMatch());
          break;
        case 'PONG':
          // Respuesta a ping, solo log
          _addLog('🏓 PONG recibido');
          break;
        default:
          // Mostrar el comando con su representación para debug
          final hexRepr = cleanCmd.codeUnits.map((c) => c.toRadixString(16).padLeft(2, '0')).join(' ');
          debugPrint('⚠️ Comando USB desconocido: $cleanCmd (hex: $hexRepr)');
          _addLog('⚠️ CMD ignorado: "$cleanCmd"');
          _addLog('   → hex: $hexRepr');
          _addLog('   → válidos: P_A, P_B, UNDO_A, UNDO_B, RESET');
          _updateDiagnostic(addErrors: 1, lastError: 'Comando desconocido: $cleanCmd');
      }
      });
    
    // Escuchar mensajes de debug del listener USB
    _debugSub = _usbListener!.debugMessages.listen((msg) {
      debugPrint('📡 [USB DEBUG] $msg');
      _addLog(msg);
      
      // Actualizar estado basado en mensajes de debug
      final current = _usbDiagnostic.value;
      if (current.isConnected && current.state == UsbDiagnosticState.connectedNoData) {
        // Si estamos conectados y recibimos debug, estamos recibiendo datos
        _updateDiagnostic(
          state: UsbDiagnosticState.connectedReceiving,
          updateDataTime: true,
        );
      }
      
      // Contar bytes si el mensaje indica RX
      if (msg.contains('RX(')) {
        // Extraer longitud del mensaje RX(123): ...
        final rxMatch = RegExp(r'RX\((?:hex,)?(\d+)\)').firstMatch(msg);
        final bytesRead = rxMatch != null ? int.tryParse(rxMatch.group(1) ?? '0') ?? msg.length : msg.length;
        _updateDiagnostic(addBytes: bytesRead, updateDataTime: true);
      }
      
      // Detectar y contar errores
      if (msg.contains('❌') || msg.contains('ERROR') || msg.contains('OVERFLOW')) {
        _updateDiagnostic(
          addErrors: 1, 
          lastError: msg.split('\n').first, // Solo primera línea
        );
      }
      
      // Detectar advertencias (no son errores graves pero se registran)
      if (msg.contains('⚠️') && !msg.contains('CMD DESCONOCIDO')) {
        // Los comandos desconocidos ya se cuentan como error
        debugPrint('⚠️ [USB WARNING] $msg');
      }
      
      // Detectar dispositivo encontrado
      if (msg.contains('dispositivos USB') || msg.contains('Auto-conectando')) {
        if (!current.isConnected) {
          _updateDiagnostic(state: UsbDiagnosticState.deviceFound);
        }
      }
      
      // Capturar nombre del dispositivo
      if (msg.contains('Auto-conectando a')) {
        final deviceName = msg.replaceAll('Auto-conectando a ', '').replaceAll('...', '');
        _updateDiagnostic(deviceName: deviceName);
      }
      
      // Detectar problemas de protocolo
      if (msg.contains('PROTOCOL:') || msg.contains('Sin newline')) {
        debugPrint('🚨 [PROTOCOL ISSUE] $msg');
      }
    });
    
    debugPrint('🚀 [USB] Iniciando SimpleUsbSerialListener...');
    await _usbListener!.start();
    debugPrint('✅ [USB] SimpleUsbSerialListener iniciado');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Scoreboard principal con toda la lógica de puntuación
          const Scoreboard(),
          
          // Panel lateral del árbitro (se desliza desde la derecha)
          RefereeSidebar(visibleNotifier: _sidebarVisible),
          
          // Control bar en la parte inferior (solo visible cuando sidebar está abierto)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ValueListenableBuilder<bool>(
                valueListenable: _sidebarVisible,
                builder: (context, visible, _) {
                  if (!visible) return const SizedBox.shrink();
                  return const ControlBar();
                },
              ),
            ),
          ),
          
          // Overlay de ganador (se muestra automáticamente al terminar el partido)
          const WinnerOverlay(),
          
          // === Diagnóstico USB Serial (esquina superior izquierda) ===
          // Widget compacto por defecto, se expande al tocar
          Positioned(
            left: 12,
            top: 12,
            child: ValueListenableBuilder<bool>(
              valueListenable: _showDiagnosticPanel,
              builder: (context, showPanel, _) {
                return UsbDiagnosticWidget(
                  diagnosticNotifier: _usbDiagnostic,
                  startExpanded: showPanel,
                  onTap: () => _showDiagnosticPanel.value = !showPanel,
                );
              },
            ),
          ),
          
          // Botón flotante para abrir/cerrar el sidebar (siempre visible en la esquina superior derecha)
          Positioned(
            top: 16,
            right: 16,
            child: ValueListenableBuilder<bool>(
              valueListenable: _sidebarVisible,
              builder: (context, visible, _) {
                return FloatingActionButton(
                  heroTag: 'referee_button',
                  onPressed: () => _sidebarVisible.value = !visible,
                  backgroundColor: visible 
                      ? Colors.red.withOpacity(0.9) 
                      : Colors.white.withOpacity(0.9),
                  child: Icon(
                    visible ? Icons.close : Icons.settings,
                    color: visible ? Colors.white : Colors.black87,
                    size: 28,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
