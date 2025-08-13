import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text_min/features/widgets/control_bar.dart';
import 'package:speech_to_text_min/features/widgets/scoreboard.dart';
import 'package:speech_to_text_min/voice/speech_mic_panel.dart';
import 'config/app_config.dart';
import 'config/config_loader.dart';
import 'features/models/scoring_models.dart';
import 'features/scoring/bloc/scoring_bloc.dart';
import 'features/scoring/bloc/scoring_event.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await ConfigLoader.load();
  runApp(PadelApp(config: config));
}

class PadelApp extends StatelessWidget {
  final AppConfig config;
  const PadelApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: config, // available via context.read<AppConfig>()
      child: BlocProvider(
        create: (_) {
          final bloc = ScoringBloc();

          final cfg = config; // AppConfig
          final starting = (cfg.rules.startingServerId == 'team2') ? Team.red : Team.blue;

          bloc.add(
            ScoringEvent.newMatch(
              startingServer: starting,
              settings: MatchSettings(
                goldenPoint: cfg.rules.goldenPoint,
                tieBreakAtSixSix: cfg.rules.tiebreakAtSixSix,
                tieBreakTarget: cfg.rules.tiebreakTarget,
                setsToWin: cfg.rules.setsToWin,
              ),
            ),
          );
          return bloc;
        },
        child: MaterialApp(
          title: 'Padel',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorSchemeSeed: config.seedColor, useMaterial3: true),
          home: const HomePage(),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Padel')),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, c) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              // ⛔️ Do NOT make this Column const (children aren’t const)
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  Scoreboard(),
                  SizedBox(height: 12),
                  ControlBar(),
                  SizedBox(height: 12),
                  SpeechMicPanel(),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
