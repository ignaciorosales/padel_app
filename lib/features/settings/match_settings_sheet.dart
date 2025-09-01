// lib/features/settings/match_settings_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text_min/features/ble/padel_ble_client.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_bloc.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_event.dart';
import 'package:speech_to_text_min/features/scoring/bloc/scoring_state.dart';

Future<void> showMatchSettingsSheet(BuildContext context, PadelBleClient ble) async {
  await ble.refreshPaired();
  ble.cancelDiscovery();

  return showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return WillPopScope(
        onWillPop: () async { ble.cancelDiscovery(); return true; },
        child: BlocBuilder<ScoringBloc, ScoringState>(
          builder: (_, state) {
            final settings = state.match.settings;
            final selectedGames = settings.tieBreakAtGames;
            final golden = settings.goldenPoint;

            void setTbGames(int games) =>
                context.read<ScoringBloc>().add(ScoringEvent.toggleTieBreakGames(games));
            void setGolden(bool v) =>
                context.read<ScoringBloc>().add(ScoringEvent.toggleGoldenPoint(v));

            return Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 8,
                bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Configuración del partido',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Mandos (BLE)', style: Theme.of(ctx).textTheme.titleMedium),
                    ),
                    const SizedBox(height: 8),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Pareados', style: Theme.of(ctx).textTheme.titleSmall),
                    ),
                    const SizedBox(height: 6),
                    StreamBuilder<List<PairedRemote>>(
                      stream: ble.pairedDevices,
                      initialData: ble.pairedSnapshot,
                      builder: (_, snap) {
                        final paired = snap.data ?? const <PairedRemote>[];
                        if (paired.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.centerLeft,
                            child: const Text('No hay mandos pareados'),
                          );
                        }
                        return Column(
                          children: paired.map((p) {
                            final hex = p.devId.toRadixString(16).padLeft(4, '0').toUpperCase();
                            final isBlue = p.team == 'blue';
                            return ListTile(
                              dense: true,
                              title: Text('Remote 0x$hex'),
                              subtitle: Text('Equipo: ${isBlue ? 'Azul' : 'Rojo'}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SegmentedButton<String>(
                                    segments: const [
                                      ButtonSegment(value: 'blue', label: Text('Azul')),
                                      ButtonSegment(value: 'red', label: Text('Rojo')),
                                    ],
                                    selected: {p.team},
                                    onSelectionChanged: (s) async {
                                      final t = s.first;
                                      await ble.pairAs(p.devId, t);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'Quitar emparejado',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      await ble.unpair(p.devId);
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),

                    ValueListenableBuilder<bool>(
                      valueListenable: ble.discoveryArmed,
                      builder: (_, armed, __) {
                        return Row(
                          children: [
                            if (!armed)
                              FilledButton.icon(
                                onPressed: () {
                                  ble.armDiscovery(window: const Duration(seconds: 20));
                                },
                                icon: const Icon(Icons.radar),
                                label: const Text('Escanear'),
                              )
                            else
                              OutlinedButton.icon(
                                onPressed: () { ble.cancelDiscovery(); },
                                icon: const Icon(Icons.stop),
                                label: const Text('Detener'),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    SizedBox(
                      height: 220,
                      child: StreamBuilder<List<DiscoveredRemote>>(
                        stream: ble.discoveredRemotes,
                        initialData: ble.discoveredSnapshot,
                        builder: (_, snapshot) {
                          final items = snapshot.data ?? const <DiscoveredRemote>[];
                          if (items.isEmpty) {
                            return const Center(child: Text('No hay eventos aún (pulsa Escanear)'));
                          }
                          return ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final r = items[i];
                              final hex = r.devId.toRadixString(16).padLeft(4, '0').toUpperCase();
                              final already = ble.isPaired(r.devId);
                              return ListTile(
                                dense: true,
                                title: Text('Remote 0x$hex'),
                                subtitle: Text('RSSI ${r.rssi} dBm'),
                                trailing: already
                                    ? const Text('Ya pareado')
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextButton(
                                            onPressed: () async { await ble.pairAs(r.devId, 'blue'); },
                                            child: const Text('Azul'),
                                          ),
                                          const SizedBox(width: 6),
                                          TextButton(
                                            onPressed: () async { await ble.pairAs(r.devId, 'red'); },
                                            child: const Text('Rojo'),
                                          ),
                                        ],
                                      ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () { ble.cancelDiscovery(); Navigator.of(ctx).maybePop(); },
                          child: const Text('Cerrar'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setTbGames(6);
                            setGolden(false);
                          },
                          child: const Text('Restablecer reglas'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
