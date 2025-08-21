import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text_min/config/app_config.dart';
import 'package:speech_to_text_min/features/models/scoring_models.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_bloc.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_event.dart';

class ControlBar extends StatelessWidget {
  const ControlBar({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ScoringBloc>();
    final cfg = context.read<AppConfig>();
    final t1 = cfg.teams.isNotEmpty ? cfg.teams[0].displayName : 'Equipo 1';
    final t2 = cfg.teams.length > 1 ? cfg.teams[1].displayName : 'Equipo 2';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: () => bloc.add(const ScoringEvent.pointFor(Team.blue)), // team1
          icon: const Icon(Icons.add),
          label: Text('Punto $t1'),
        ),
        FilledButton.icon(
          onPressed: () => bloc.add(const ScoringEvent.pointFor(Team.red)), // team2
          icon: const Icon(Icons.add),
          label: Text('Punto $t2'),
        ),
        OutlinedButton.icon(
          onPressed: () => bloc.add(const ScoringEvent.undo()),
          icon: const Icon(Icons.undo),
          label: const Text('Deshacer'),
        ),
        OutlinedButton.icon(
          onPressed: () => bloc.add(const ScoringEvent.redo()),
          icon: const Icon(Icons.redo),
          label: const Text('Rehacer'),
        ),
        // Reglas (opcionales en UI)
        // OutlinedButton.icon(
        //   onPressed: () => bloc.add(const ScoringEvent.toggleTieBreakAtSixSix(true)),
        //   icon: const Icon(Icons.rule),
        //   label: const Text('TB 6–6 ON'),
        // ),
        // OutlinedButton.icon(
        //   onPressed: () => bloc.add(const ScoringEvent.toggleTieBreakAtSixSix(false)),
        //   icon: const Icon(Icons.rule_folder),
        //   label: const Text('TB 6–6 OFF'),
        // ),
        OutlinedButton.icon(
          onPressed: () => bloc.add(const ScoringEvent.toggleGoldenPoint(true)),
          icon: const Icon(Icons.star),
          label: const Text('Oro ON'),
        ),
        OutlinedButton.icon(
          onPressed: () => bloc.add(const ScoringEvent.toggleGoldenPoint(false)),
          icon: const Icon(Icons.star_border),
          label: const Text('Oro OFF'),
        ),
        OutlinedButton.icon(
          onPressed: () => bloc.add(const ScoringEvent.announceScore()),
          icon: const Icon(Icons.campaign),
          label: const Text('Anunciar'),
        ),
        TextButton(
          onPressed: () => bloc.add(const ScoringEvent.newMatch()),
          child: const Text('Nuevo partido'),
        ),
      ],
    );
  }
}
