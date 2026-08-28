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

    test('unassignBox deja la caja SIN EQUIPO en vez de borrarla', () async {
      final pairing = await BoxPairingService.init();

      await pairing.unassignBox('0201');
      expect(pairing.teamForBox('0201'), isNull);
      // A diferencia de removeBox, la caja sigue en la lista.
      expect(pairing.pairings.value.containsKey('0201'), isTrue);
      expect(pairing.pairings.value['0201'], BoxPairingService.unassigned);
    });

    test('una caja SIN EQUIPO se puede reasignar sin comando en vivo',
        () async {
      final pairing = await BoxPairingService.init();

      await pairing.unassignBox('0202');
      expect(pairing.teamForBox('0202'), isNull);

      await pairing.setPairing('0202', 2);
      expect(pairing.teamForBox('0202'), Team.red);
    });

    test('la persistencia sobrevive a un reinicio del servicio', () async {
      final first = await BoxPairingService.init();
      await first.setPairing('0203', 1); // reasignar a Equipo 1

      final reloaded = await BoxPairingService.init();
      expect(reloaded.teamForBox('0203'), Team.blue);
    });

    test('reportUnpairedBox marca la caja desconocida como pendiente',
        () async {
      final pairing = await BoxPairingService.init();
      expect(pairing.unpairedBoxes.value, isEmpty);

      pairing.reportUnpairedBox('0209');
      expect(pairing.unpairedBoxes.value, contains('0209'));

      // Emparejarla la retira de "pendiente".
      await pairing.setPairing('0209', 1);
      expect(pairing.unpairedBoxes.value, isNot(contains('0209')));
    });

    test('varias cajas sin emparejar se acumulan, ninguna tapa a otra',
        () async {
      final pairing = await BoxPairingService.init();

      pairing.reportUnpairedBox('0209');
      pairing.reportUnpairedBox('020a');
      expect(pairing.unpairedBoxes.value, containsAll(['0209', '020a']));

      // Emparejar una no afecta a la otra.
      await pairing.setPairing('0209', 1);
      expect(pairing.unpairedBoxes.value, ['020a']);

      pairing.clearUnpairedBox('020a');
      expect(pairing.unpairedBoxes.value, isEmpty);
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
      expect(pairing.unpairedBoxes.value, contains('0209'));
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
