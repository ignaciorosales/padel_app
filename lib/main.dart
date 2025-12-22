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
import 'package:Puntazo/features/usb_serial/native_usb_serial_listener.dart';
import 'package:Puntazo/features/widgets/scoreboard.dart';
import 'package:Puntazo/features/widgets/winner_overlay.dart';
import 'package:Puntazo/features/widgets/referee_sidebar.dart';
import 'package:Puntazo/features/widgets/control_bar.dart';
import 'package:Puntazo/features/usb_serial/usb_serial_test_page.dart';

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
  NativeUsbSerialListener? _usbListener;
  StreamSubscription<String>? _commandSub;
  StreamSubscription<String>? _debugSub;
  StreamSubscription<bool>? _connectionSub;
  
  final ValueNotifier<bool> _sidebarVisible = ValueNotifier(false);
  
  // Log overlay para debug en TV box (sin acceso fácil a logcat)
  final ValueNotifier<List<String>> _usbLog = ValueNotifier<List<String>>([]);
  final ValueNotifier<bool> _usbConnected = ValueNotifier<bool>(false);
  
  void _pushUsbLog(String line) {
    final list = List<String>.from(_usbLog.value);
    list.add('${DateTime.now().toString().substring(11, 19)} $line');
    if (list.length > 50) list.removeRange(0, list.length - 50);
    _usbLog.value = list;
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
    _usbLog.dispose();
    _usbConnected.dispose();
    super.dispose();
  }

  Future<void> _startUsbSerial() async {
    _usbListener = NativeUsbSerialListener();
    _pushUsbLog('Creando NativeUsbSerialListener...');
    
    // Escuchar estado de conexión
    _connectionSub = _usbListener!.connectionStatus.listen((connected) {
      _usbConnected.value = connected;
      _pushUsbLog(connected ? '✅ USB CONECTADO' : '❌ USB DESCONECTADO');
    });
    
    // Escuchar comandos USB y enviarlos al BLoC
    _commandSub = _usbListener!.commands.listen((cmd) {
      if (!mounted) return;
      
      debugPrint('🎮 [USB CMD] Received: $cmd');
      _pushUsbLog('🎮 CMD: $cmd');
      
      final bloc = context.read<ScoringBloc>();
      
      // Mapear comandos USB nativos a eventos del BLoC
      switch (cmd) {
        case 'P_A':
          debugPrint('🎮 [USB CMD] -> pointFor(Team.blue)');
          bloc.add(const ScoringEvent.pointFor(Team.blue));
          break;
        case 'P_B':
          debugPrint('🎮 [USB CMD] -> pointFor(Team.red)');
          bloc.add(const ScoringEvent.pointFor(Team.red));
          break;
        case 'UNDO_A':
          debugPrint('🎮 [USB CMD] -> undoForTeam(Team.blue)');
          bloc.add(const ScoringEvent.undoForTeam(Team.blue));
          break;
        case 'UNDO_B':
          debugPrint('🎮 [USB CMD] -> undoForTeam(Team.red)');
          bloc.add(const ScoringEvent.undoForTeam(Team.red));
          break;
        case 'RESET':
        case 'RESET_GAME':
          debugPrint('🎮 [USB CMD] -> newMatch()');
          bloc.add(const ScoringEvent.newMatch());
          break;
        default:
          debugPrint('⚠️ Comando USB desconocido: $cmd');
          _pushUsbLog('⚠️ CMD desconocido: $cmd');
      }
    });
    
    // Escuchar mensajes de debug del listener nativo
    _debugSub = _usbListener!.debugMessages.listen((msg) {
      debugPrint('📡 [USB DEBUG] $msg');
      _pushUsbLog(msg);
    });
    
    debugPrint('🚀 [USB] Iniciando NativeUsbSerialListener...');
    _pushUsbLog('Llamando start()...');
    await _usbListener!.start();
    debugPrint('✅ [USB] NativeUsbSerialListener iniciado');
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
          
          // === DEBUG: Overlay de logs USB Serial (esquina superior izquierda) ===
          Positioned(
            left: 12,
            top: 12,
            child: ValueListenableBuilder<List<String>>(
              valueListenable: _usbLog,
              builder: (context, lines, _) {
                if (lines.isEmpty) return const SizedBox.shrink();
                final tail = lines.length > 15 ? lines.sublist(lines.length - 15) : lines;
                return Container(
                  width: 500,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.80),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          ValueListenableBuilder<bool>(
                            valueListenable: _usbConnected,
                            builder: (context, connected, _) {
                              return Icon(
                                Icons.usb,
                                color: connected ? Colors.green : Colors.red,
                                size: 16,
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '🔌 USB Serial Debug Log',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tail.join('\n'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
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
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Botón USB Test
                    FloatingActionButton.small(
                      heroTag: 'usb_test_button',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const UsbSerialTestPage()),
                        );
                      },
                      backgroundColor: Colors.orange.withOpacity(0.9),
                      child: const Icon(Icons.usb, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    // Botón Settings
                    FloatingActionButton(
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
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
