import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_bloc.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_event.dart';
import '../../config/app_config.dart';
import '../commands/parser_es.dart';

void processFinalVoiceText(BuildContext context, String text) {
  AppConfig cfg;
  try {
    cfg = context.read<AppConfig>();
  } catch (_) {
    cfg = const AppConfig();
  }

  final bloc = context.read<ScoringBloc>();

  final parser = DynamicEsParser(cfg);
  final cmds = parser.parse(text);

  if (cmds.isEmpty) {
    return;
  }

  for (final c in cmds) {
    c.map(
      pointFor: (v) => bloc.add(ScoringEvent.pointFor(v.team)),
      removePoint: (v) => bloc.add(ScoringEvent.removePoint(v.team)),
      newMatch: (_) => bloc.add(const ScoringEvent.newMatch()),
      newSet: (_) => bloc.add(const ScoringEvent.newSet()),
      newGame: (_) => bloc.add(const ScoringEvent.newGame()),
      forceGameFor: (v) => bloc.add(ScoringEvent.forceGameFor(v.team)),
      forceSetFor: (v) => bloc.add(ScoringEvent.forceSetFor(v.team)),
      setExplicitGamePoints: (v) =>
          bloc.add(ScoringEvent.setExplicitGamePoints(blue: v.blue, red: v.red)),
      // toggleTieBreakAtSixSix: (v) =>
      //     bloc.add(ScoringEvent.toggleTieBreakAtSixSix(v.enabled)),
      toggleGoldenPoint: (v) =>
          bloc.add(ScoringEvent.toggleGoldenPoint(v.enabled)),
      announceScore: (_) => bloc.add(const ScoringEvent.announceScore()),
      undo: (_) => bloc.add(const ScoringEvent.undo()),
      redo: (_) => bloc.add(const ScoringEvent.redo()),
    );
  }
}
