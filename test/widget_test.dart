import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:Puntazo/features/models/scoring_models.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_event.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_state.dart';

class _Harness extends StatelessWidget {
  const _Harness({super.key});

  String _labelFor(int v) {
    if (v == 0) return '0';
    if (v == 1) return '15';
    if (v == 2) return '30';
    if (v == 3) return '40';
    return 'AD';
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = ScoringBloc();
        // Initialize known rules; don't use const newMatch if payload isn't const.
        bloc.add(
          ScoringEvent.newMatch(
            settings: const MatchSettings(
              goldenPoint: true,
              tieBreakAtGames: 6,
              tieBreakTarget: 7,
              setsToWin: 2,
            ),
          ),
        );
        return bloc;
      },
      child: MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                BlocBuilder<ScoringBloc, ScoringState>(
                  builder: (context, state) {
                    final gp = state.match.currentSet.currentGame.blue;
                    return Text('BLUE:${_labelFor(gp)}');
                  },
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  key: const Key('btnPointTeam1'),
                  onPressed: () {
                    context
                        .read<ScoringBloc>()
                        .add(const ScoringEvent.pointFor(Team.blue));
                  },
                  child: const Text('Punto Equipo 1'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('Blue team increments to 15 with button', (tester) async {
    await tester.pumpWidget(const _Harness());

    // Pump once to process the newMatch event & first build.
    await tester.pump();

    expect(find.text('BLUE:0'), findsOneWidget);

    await tester.tap(find.byKey(const Key('btnPointTeam1')));
    await tester.pump(); // process bloc event

    expect(find.text('BLUE:15'), findsOneWidget);
  });
}
