import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_bloc.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_state.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_event.dart';

Future<void> showMatchSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return BlocBuilder<ScoringBloc, ScoringState>(
        builder: (_, state) {
          final settings = state.match.settings;
          final selectedGames = settings.tieBreakAtGames;
          final golden = settings.goldenPoint;

          void setTbGames(int games) =>
              context.read<ScoringBloc>().add(
                    ScoringEvent.toggleTieBreakGames(games),
                  );

          void setGolden(bool v) =>
              context.read<ScoringBloc>().add(
                    ScoringEvent.toggleGoldenPoint(v),
                  );

          return Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 8,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Configuración del partido',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Tie-break cuando llegan a:',
                      style: Theme.of(ctx).textTheme.titleMedium),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('6 juegos (clásico)'),
                      selected: selectedGames == 6,
                      onSelected: (_) => setTbGames(6),
                    ),
                    ChoiceChip(
                      label: const Text('12 juegos (super set)'),
                      selected: selectedGames == 12,
                      onSelected: (_) => setTbGames(12),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Punto de oro'),
                  subtitle: const Text('En deuce, el siguiente punto decide el juego'),
                  value: golden,
                  onChanged: setGolden,
                ),

                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).maybePop(),
                      child: const Text('Cerrar'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setTbGames(6);
                        setGolden(false);
                      },
                      child: const Text('Restablecer'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
