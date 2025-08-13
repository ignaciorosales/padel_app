import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text_min/config/app_config.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_bloc.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_state.dart';
import '../models/scoring_models.dart';

class Scoreboard extends StatelessWidget {
  const Scoreboard({super.key});

  String _ptLabel(int v, bool tie) => tie ? '$v' : (v==0?'0':v==1?'15':v==2?'30':v==3?'40':'AD');

  @override
  Widget build(BuildContext context) {
    final cfg = context.read<AppConfig>();
    return BlocBuilder<ScoringBloc, ScoringState>(
      builder: (context, state) {
        final m = state.match;
        final set = m.currentSet;
        final tie = set.currentGame.isTieBreak;

        final team1 = cfg.teams.isNotEmpty ? cfg.teams[0] : null;
        final team2 = cfg.teams.length>1 ? cfg.teams[1] : null;

        return Column(
          children: [
            Card(
              child: ListTile(
                leading: Icon(m.server==Team.blue ? Icons.sports_tennis : Icons.circle_outlined),
                tileColor: team1 != null ? cfg.colorFor(team1.id).withOpacity(0.06) : null,
                title: Text(m.blueName, style: const TextStyle(fontSize: 18)),
                subtitle: Text('Juegos: ${set.blueGames}'),
                trailing: Text(_ptLabel(set.currentGame.blue, tie),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 6),
            Card(
              child: ListTile(
                leading: Icon(m.server==Team.red ? Icons.sports_tennis : Icons.circle_outlined),
                tileColor: team2 != null ? cfg.colorFor(team2.id).withOpacity(0.06) : null,
                title: Text(m.redName, style: const TextStyle(fontSize: 18)),
                subtitle: Text('Juegos: ${set.redGames}'),
                trailing: Text(_ptLabel(set.currentGame.red, tie),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );
      },
    );
  }
}
