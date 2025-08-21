import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text_min/features/settings/match_settings_sheet.dart';

import 'config/app_config.dart';
import 'config/config_loader.dart';

import 'features/models/scoring_models.dart';
import 'features/scoring/bloc/scoring_bloc.dart';
import 'features/scoring/bloc/scoring_event.dart';

import 'features/widgets/scoreboard.dart';
import 'features/ble/padel_ble_client.dart';

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
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0EA5E9),
              brightness: Brightness.dark,
            ),
          ),
          home: const _ScoreOnlyScreen(),
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

  @override
  void initState() {
    super.initState();
    _ble.startListening();
    _cmdSub = _ble.commands.listen(
      (cmd) => context.read<ScoringBloc>().add(ScoringEvent.bleCommand(cmd)),
    );
  }

  @override
  void dispose() {
    _cmdSub?.cancel();
    _ble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      body: SafeArea(
        child: Stack(
          children: [
            // Scoreboard centered
            const Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Scoreboard(),
              ),
            ),

            // Small settings button (top-right, unobtrusive)
            Positioned(
              top: 12,
              right: 12,
              child: FloatingActionButton.small(
                heroTag: 'settings',
                backgroundColor: Colors.white10,
                elevation: 0,
                shape: const CircleBorder(),
                tooltip: 'Ajustes',
                onPressed: () => showMatchSettingsSheet(context),
                child: const Icon(Icons.settings, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
