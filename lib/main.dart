// lib/main.dart
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
import 'package:speech_to_text_min/features/settings/match_settings_sheet.dart' as settings;

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

class PadelApp extends StatelessWidget {
  final AppConfig config;
  const PadelApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: config,
      child: BlocProvider(
        create: (_) {
          final bloc = ScoringBloc();
          final cfg = config;
          final starting =
              (cfg.rules.startingServerId == 'team2') ? Team.red : Team.blue;

          bloc.add(
            ScoringEvent.newMatch(
              startingServer: starting,
              settings: MatchSettings(
                goldenPoint: cfg.rules.goldenPoint,
                tieBreakAtGames: cfg.rules.tiebreakAtSixSix ? 6 : 12,
                tieBreakTarget: cfg.rules.tiebreakTarget,
                setsToWin: cfg.rules.setsToWin,
              ),
            ),
          );
          return bloc;
        },
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: _ScoreOnlyScreen(),
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

  @override
  void initState() {
    super.initState();
    () async {
      await _ble.init();            // Carga pareados persistidos
      await _ble.startListening();  // Empieza a oír advertising continuamente

      // Reenvía comandos BLE al Bloc (incluye 'a','b','u','g' y 'cmd:toggle-server')
      _cmdSub = _ble.commands.listen(
        (cmd) => context.read<ScoringBloc>().add(ScoringEvent.bleCommand(cmd)),
      );

      // Escucha la ventana de selección de servidor (reinicio con botón)
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
      barrierDismissible: false, // Solo el control remoto termina el flujo
      builder: (_) => const _ServerSelectDialog(),
    );
  }

  @override
  void dispose() {
    _ble.serverSelectActive.removeListener(_onServerSelectChanged);
    _cmdSub?.cancel();
    _ble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Scoreboard(),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'settings',
        onPressed: () => settings.showMatchSettingsSheet(context, _ble),
        child: const Icon(Icons.settings),
      ),
    );
  }
}

class _ServerSelectDialog extends StatelessWidget {
  const _ServerSelectDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF12161C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: BlocBuilder<ScoringBloc, ScoringState>(
          builder: (_, state) {
            final server = state.match.server; // Team.blue | Team.red
            final blueOn = server == Team.blue;
            final servingText = blueOn ? 'AZUL' : 'ROJO';

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Reiniciar juego',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  'Sirve primero: $servingText',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: blueOn ? const Color(0xFF66A3FF) : const Color(0xFFFF5757),
                  ),
                ),
                const SizedBox(height: 14),
                const _InstructionRow(text: '• Presiona P para cambiar entre equipos'),
                const _InstructionRow(text: '• Presiona G para confirmar'),
                const _InstructionRow(text: '• Presiona U para cancelar'),
                const SizedBox(height: 4),
                const Divider(height: 20, color: Colors.white24),
                Text(
                  'Usa el mismo mando que inició el reinicio.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(.7)),
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
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70),
        textAlign: TextAlign.left,
      ),
    );
  }
}
