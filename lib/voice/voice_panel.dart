import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text_min/commands/command.dart';
import 'package:speech_to_text_min/commands/parser_es.dart';
import 'package:speech_to_text_min/config/app_config.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_bloc.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_event.dart';

class VoicePanel extends StatefulWidget {
  const VoicePanel({super.key});

  @override
  State<VoicePanel> createState() => _VoicePanelState();
}

class _VoicePanelState extends State<VoicePanel> {
  final _controller = TextEditingController();
  String _last = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _dispatchAll(context, text);
    setState(() => _last = text);
    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  void _dispatchAll(BuildContext context, String text) {
    final bloc = context.read<ScoringBloc>();

    // Get dynamic config (teams, synonyms, etc.). Fallback to defaults if not provided.
    AppConfig cfg;
    try {
      cfg = context.read<AppConfig>();
    } catch (_) {
      cfg = const AppConfig();
    }

    // ✅ Use instance parser (not static)
    final parser = DynamicEsParser(cfg);
    final List<Command> cmds = parser.parse(text);
    if (cmds.isEmpty) return;

    for (final c in cmds) {
      c.map(
        pointFor: (v) => bloc.add(ScoringEvent.pointFor(v.team)),
        removePoint: (v) => bloc.add(ScoringEvent.removePoint(v.team)),
        newMatch: (_) => bloc.add(const ScoringEvent.newMatch()),
        newSet: (_) => bloc.add(const ScoringEvent.newSet()),
        newGame: (_) => bloc.add(const ScoringEvent.newGame()),
        forceGameFor: (v) => bloc.add(ScoringEvent.forceGameFor(v.team)),
        forceSetFor: (v) => bloc.add(ScoringEvent.forceSetFor(v.team)),
        setExplicitGamePoints: (v) => bloc.add(
          ScoringEvent.setExplicitGamePoints(blue: v.blue, red: v.red),
        ),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.keyboard),
            title: const Text('Comandos por texto'),
            subtitle: Text(
              _last.isEmpty
                  ? 'Ej: "punto para Equipo A", "deshacer", "nuevo partido"'
                  : 'Último: $_last',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: 'Escribe un comando…',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _send,
              icon: const Icon(Icons.send),
              label: const Text('Enviar'),
            ),
          ],
        ),
      ],
    );
  }
}
