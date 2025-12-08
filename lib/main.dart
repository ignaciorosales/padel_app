import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:Puntazo/config/config_loader.dart';
import 'package:Puntazo/config/app_config.dart';
import 'package:Puntazo/config/app_theme.dart';
import 'package:Puntazo/config/team_selection_service.dart';
import 'package:Puntazo/features/models/scoring_models.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_event.dart';
import 'package:Puntazo/features/ble/native_ble_listener.dart';
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
  NativeBLEListener? _bleListener;
  StreamSubscription<String>? _commandSub;
  StreamSubscription<String>? _debugSub;
  
  final ValueNotifier<bool> _sidebarVisible = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _requestPermissionsAndStartBLE();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _commandSub?.cancel();
    _debugSub?.cancel();
    _bleListener?.stop();
    _sidebarVisible.dispose();
    super.dispose();
  }

  Future<void> _requestPermissionsAndStartBLE() async {
    final permissions = [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ];

    final statuses = await permissions.request();
    
    if (statuses.values.every((status) => status.isGranted)) {
      await _startBLE();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Permisos BLE denegados')),
        );
      }
    }
  }

  Future<void> _startBLE() async {
    _bleListener = NativeBLEListener();
    
    // Escuchar comandos BLE y enviarlos al BLoC
    _commandSub = _bleListener!.commands.listen((cmd) {
      if (!mounted) return;
      
      final bloc = context.read<ScoringBloc>();
      
      // Mapear comandos BLE nativos a eventos del BLoC
      switch (cmd) {
        case 'P_A':
          bloc.add(const ScoringEvent.pointFor(Team.blue));
          break;
        case 'P_B':
          bloc.add(const ScoringEvent.pointFor(Team.red));
          break;
        case 'UNDO_A':
          bloc.add(const ScoringEvent.undoForTeam(Team.blue));
          break;
        case 'UNDO_B':
          bloc.add(const ScoringEvent.undoForTeam(Team.red));
          break;
        case 'RESET_GAME':
          bloc.add(const ScoringEvent.newMatch());
          break;
        default:
          debugPrint('⚠️ Comando BLE desconocido: $cmd');
      }
    });
    
    // Escuchar mensajes de debug del listener nativo
    _debugSub = _bleListener!.debugMessages.listen((msg) {
      debugPrint('[BLE] $msg');
    });
    
    await _bleListener!.start();
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
