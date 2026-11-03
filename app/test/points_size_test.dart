import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Puntazo/features/models/scoring_models.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_event.dart';
import 'package:Puntazo/features/widgets/scoreboard.dart';
import 'package:Puntazo/l10n/app_localizations.dart';
import 'audio_stub.dart';

/// Con la letra en Gigante, cada puntaje se achicaba por su cuenta si no cabía:
/// "0" y "15" se veían mucho más grandes que "30".
void main() {
  stubAudioPlayers();

  setUpAll(() async {
    final font = FontLoader('Digital7')
      ..addFont(rootBundle.load('assets/fonts/digital-7.ttf'));
    await font.load();
  });

  testWidgets('todos los puntajes se ven del mismo tamaño', (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final bloc = ScoringBloc()
      ..add(const ScoringEvent.newMatch(
        settings: MatchSettings(
          goldenPoint: false,
          tieBreakAtGames: 6,
          tieBreakTarget: 7,
          setsToWin: 2,
        ),
      ));
    addTearDown(bloc.close);

    await tester.pumpWidget(BlocProvider.value(
      value: bloc,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 744,
            child: CurrentGamePointsRow(
              // Altura de una pantalla de celular con el preset Gigante.
              pointsSize: 328 * 0.52 * 1.3,
              textColor: Colors.white,
            ),
          ),
        ),
      ),
    ));

    Future<void> point(Team team) async {
      bloc.add(ScoringEvent.pointFor(team));
      await tester.pump();
      await tester.pump();
    }

    // Los games también muestran "0": el puntaje es el más alto de los dos.
    double heightOf(String label) => find
        .text(label)
        .evaluate()
        .map((e) => tester.getRect(find.byElementPredicate((x) => x == e)).height)
        .reduce((a, b) => a > b ? a : b);

    await tester.pump();
    final heights = <String, double>{'0': heightOf('0')};
    await point(Team.blue);
    heights['15'] = heightOf('15');
    await point(Team.blue);
    heights['30'] = heightOf('30');
    await point(Team.blue);
    heights['40'] = heightOf('40');
    await point(Team.red);
    await point(Team.red);
    await point(Team.red);
    await point(Team.blue);
    heights['AD'] = heightOf('AD');

    for (final entry in heights.entries) {
      expect(entry.value, closeTo(heights['0']!, 0.5),
          reason: '"${entry.key}" no mide lo mismo que "0": $heights');
    }
  });
}
