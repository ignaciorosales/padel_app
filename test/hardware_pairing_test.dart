import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Puntazo/config/box_pairing_service.dart';
import 'package:Puntazo/features/match_control/hardware_command_handler.dart';
import 'package:Puntazo/features/models/scoring_models.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_event.dart';

/// Puntos del juego actual para cada equipo.
({int blue, int red}) _points(ScoringBloc bloc) {
  final game = bloc.state.match.currentSet.currentGame;
  return (blue: game.blue, red: game.red);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BoxPairingService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('empareja las 4 cajas por defecto', () async {
      final pairing = await BoxPairingService.init();
      expect(pairing.teamForBox('0201'), Team.blue); // Equipo 1
      expect(pairing.teamForBox('0202'), Team.blue);
      expect(pairing.teamForBox('0203'), Team.red); // Equipo 2
      expect(pairing.teamForBox('0204'), Team.red);
    });

    test('id no emparejado devuelve null', () async {
      final pairing = await BoxPairingService.init();
      expect(pairing.teamForBox('0209'), isNull);
    });

    test('setPairing/removeBox persisten y actualizan el mapeo', () async {
      final pairing = await BoxPairingService.init();

      await pairing.setPairing('0209', 2);
      expect(pairing.teamForBox('0209'), Team.red);

      await pairing.removeBox('0209');
      expect(pairing.teamForBox('0209'), isNull);
    });

    test('la persistencia sobrevive a un reinicio del servicio', () async {
      final first = await BoxPairingService.init();
      await first.setPairing('0203', 1); // reasignar a Equipo 1

      final reloaded = await BoxPairingService.init();
      expect(reloaded.teamForBox('0203'), Team.blue);
    });

    test('reportUnpairedBox marca la última caja desconocida', () async {
      final pairing = await BoxPairingService.init();
      expect(pairing.lastUnpairedBox.value, isNull);

      pairing.reportUnpairedBox('0209');
      expect(pairing.lastUnpairedBox.value, '0209');

      // Emparejarla la retira de "pendiente".
      await pairing.setPairing('0209', 1);
      expect(pairing.lastUnpairedBox.value, isNull);
    });
  });

  group('HardwareCommandHandler (protocolo BTN)', () {
    late ScoringBloc bloc;
    late BoxPairingService pairing;
    late HardwareCommandHandler handler;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      bloc = ScoringBloc()..add(const ScoringEvent.newMatch());
      pairing = await BoxPairingService.init();
      handler = HardwareCommandHandler(bloc: bloc, pairing: pairing);
      await pumpEventQueue();
    });

    tearDown(() async {
      handler.dispose();
      await bloc.close();
    });

    test('BTN:0201:P suma punto al Equipo 1 (azul)', () async {
      final before = _points(bloc);
      handler.handle('BTN:0201:P');
      await pumpEventQueue();
      final after = _points(bloc);

      expect(after.blue, greaterThan(before.blue));
      expect(after.red, before.red);
    });

    test('BTN:0203:P suma punto al Equipo 2 (rojo)', () async {
      final before = _points(bloc);
      handler.handle('BTN:0203:P');
      await pumpEventQueue();
      final after = _points(bloc);

      expect(after.red, greaterThan(before.red));
      expect(after.blue, before.blue);
    });

    test('una caja sin emparejar no puntúa y queda marcada como pendiente',
        () async {
      final before = _points(bloc);
      handler.handle('BTN:0209:P');
      await pumpEventQueue();
      final after = _points(bloc);

      expect(after, before); // sin cambios en el marcador
      expect(pairing.lastUnpairedBox.value, '0209');
    });

    test('reasignar una caja cambia el equipo al que puntúa', () async {
      await pairing.setPairing('0201', 2); // 0201 pasa a Equipo 2
      final before = _points(bloc);
      handler.handle('BTN:0201:P');
      await pumpEventQueue();
      final after = _points(bloc);

      expect(after.red, greaterThan(before.red));
      expect(after.blue, before.blue);
    });

    test('BTN:xxxx:G entra en modo reinicio pendiente y un PUNTO lo confirma',
        () async {
      expect(handler.pendingReset.value, isFalse);

      handler.handle('BTN:0201:G'); // solicitar reinicio
      await pumpEventQueue();
      expect(handler.pendingReset.value, isTrue);

      // Sumar puntos primero para comprobar que el reinicio limpia el marcador.
      handler.handle('BTN:0201:P'); // este PUNTO confirma el reinicio
      await pumpEventQueue();
      expect(handler.pendingReset.value, isFalse);

      final after = _points(bloc);
      expect(after.blue, 0);
      expect(after.red, 0);
    });

    test('BTN:xxxx:U deshace el último punto de ese equipo', () async {
      handler.handle('BTN:0201:P');
      await pumpEventQueue();
      final scored = _points(bloc);
      expect(scored.blue, greaterThan(0));

      handler.handle('BTN:0201:U');
      await pumpEventQueue();
      final undone = _points(bloc);
      expect(undone.blue, lessThan(scored.blue));
    });
  });
}
