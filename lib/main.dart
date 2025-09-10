import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:speech_to_text_min/config/app_config.dart';
import 'package:speech_to_text_min/config/config_loader.dart';
import 'package:speech_to_text_min/features/ble/padel_ble_client.dart';
import 'package:speech_to_text_min/features/models/scoring_models.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_bloc.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_event.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_state.dart';
import 'package:speech_to_text_min/features/widgets/scoreboard.dart';
import 'package:speech_to_text_min/features/widgets/referee_sidebar.dart';
import 'package:speech_to_text_min/features/widgets/winner_overlay.dart';
import 'package:speech_to_text_min/features/settings/match_settings_sheet.dart' as settings;

/// Simple app-wide theme controller
class ThemeController {
  final ValueNotifier<ThemeMode> mode;
  ThemeController(ThemeMode initial) : mode = ValueNotifier<ThemeMode>(initial);
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
  runApp(PadelApp(config: config));
}

class PadelApp extends StatefulWidget {
  final AppConfig config;
  const PadelApp({super.key, required this.config});

  @override
  State<PadelApp> createState() => _PadelAppState();
}

class _PadelAppState extends State<PadelApp> {
  late final ThemeController _themeCtrl;

  @override
  void initState() {
    super.initState();
    // Start however you prefer (Dark by default). You could persist this.
    _themeCtrl = ThemeController(ThemeMode.dark);
  }

  @override
  void dispose() {
    _themeCtrl.dispose();
    super.dispose();
  }

  // --------- THEME DEFINITIONS (Material 3) ---------

  ThemeData _lightTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2A7BFF), // your Azul accent
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.background,
      dividerColor: scheme.outlineVariant,
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        modalElevation: 12,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      ),
    );
  }

  ThemeData _darkTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2A7BFF),
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.background,
      dividerColor: scheme.outlineVariant,
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        modalElevation: 12,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AppConfig>.value(value: widget.config),
        RepositoryProvider<ThemeController>.value(value: _themeCtrl),
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
  bool _serverDialogOpen = false;
  final ValueNotifier<bool> _refSidebarVisible = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    () async {
      await _ble.init();
      await _ble.startListening();
      _cmdSub = _ble.commands.listen(
        (cmd) => context.read<ScoringBloc>().add(ScoringEvent.bleCommand(cmd)),
      );
      _ble.serverSelectActive.addListener(_onServerSelectChanged);
    }();
  }

  void _onServerSelectChanged() {
    final active = _ble.serverSelectActive.value;
    if (active && !_serverDialogOpen && mounted) {
      _serverDialogOpen = true;
      _showServerSelectDialog();
    } else if (!active && _serverDialogOpen && mounted) {
      _serverDialogOpen = false;
      final nav = Navigator.of(context, rootNavigator: true);
      if (nav.canPop()) nav.pop();
    }
  }

  Future<void> _showServerSelectDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ServerSelectDialog(),
    );
  }

  @override
  void dispose() {
    _ble.serverSelectActive.removeListener(_onServerSelectChanged);
    _cmdSub?.cancel();
    _ble.dispose();
    _refSidebarVisible.dispose();
    super.dispose();
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
        child: Focus(
          autofocus: true,
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
                          FloatingActionButton.small(
                            heroTag: 'referee',
                            tooltip: isVisible ? 'Ocultar panel árbitro (F1)' : 'Mostrar panel árbitro (F1)',
                            onPressed: _toggleRefPanel,
                            child: Icon(isVisible ? Icons.chevron_right : Icons.sports),
                          ),
                          const SizedBox(height: 10),
                          FloatingActionButton.small(
                            heroTag: 'settings',
                            onPressed: () => settings.showMatchSettingsSheet(scaffoldCtx, _ble),
                            child: const Icon(Icons.settings),
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

class _ServerSelectDialog extends StatelessWidget {
  const _ServerSelectDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: BlocBuilder<ScoringBloc, ScoringState>(
          builder: (_, state) {
            final server = state.match.server;
            final blueOn = server == Team.blue;
            final servingText = blueOn ? 'AZUL' : 'ROJO';
            final blueColor = const Color(0xFF66A3FF);
            final redColor  = const Color(0xFFFF5757);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Reiniciar juego',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  'Sirve primero: $servingText',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: blueOn ? blueColor : redColor,
                  ),
                ),
                const SizedBox(height: 14),
                const _InstructionRow(text: '• Presiona P para cambiar entre equipos'),
                const _InstructionRow(text: '• Presiona G para confirmar'),
                const _InstructionRow(text: '• Presiona U para cancelar'),
                const SizedBox(height: 4),
                Divider(height: 20, color: Theme.of(context).dividerColor),
                Text(
                  'Usa el mismo mando que inició el reinicio.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(.7),
                      ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InstructionRow extends StatelessWidget {
  final String text;
  const _InstructionRow({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(text),
    );
  }
}
