import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Puntazo/config/box_pairing_service.dart';
import 'package:Puntazo/features/match_control/hardware_command_handler.dart';
import 'package:Puntazo/features/models/scoring_models.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_event.dart';
import 'audio_stub.dart';

/// Puntos del juego actual para cada equipo.
({int blue, int red}) _points(ScoringBloc bloc) {
  final game = bloc.state.match.currentSet.currentGame;
  return (blue: game.blue, red: game.red);
}

void main() {
  stubAudioPlayers();
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BoxPairingService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('sin nada guardado arranca sin cajas (abre el asistente)', () async {
      final pairing = await BoxPairingService.init();
      expect(pairing.pairings.value, isEmpty);
      expect(pairing.hasPairedBoxes, isFalse);
    });

    test('un emparejamiento antiguo por equipo se lee como lado', () async {
      SharedPreferences.setMockInitialValues({
        'box_team_pairings': '{"0201":1,"0203":2}',
      });
      final pairing = await BoxPairingService.init();
      expect(pairing.sideForBox('0201'), BoxPairingService.left);
      expect(pairing.sideForBox('0203'), BoxPairingService.right);
    });

    test('id no emparejado devuelve null', () async {
      final pairing = await BoxPairingService.init();
      expect(pairing.sideForBox('0209'), isNull);
    });

    test('setPairing/removeBox persisten y actualizan el mapeo', () async {
      final pairing = await BoxPairingService.init();

      await pairing.setPairing('0209', 2);
      expect(pairing.sideForBox('0209'), 2);

      await pairing.removeBox('0209');
      expect(pairing.sideForBox('0209'), isNull);
    });

    test('unassignBox deja la caja SIN EQUIPO en vez de borrarla', () async {
      final pairing = await BoxPairingService.init();
      await pairing.setPairing('0201', 1);

      await pairing.unassignBox('0201');
      expect(pairing.sideForBox('0201'), isNull);
      // A diferencia de removeBox, la caja sigue en la lista.
      expect(pairing.pairings.value.containsKey('0201'), isTrue);
      expect(pairing.pairings.value['0201'], BoxPairingService.unassigned);
    });

    test('una caja SIN EQUIPO se puede reasignar sin comando en vivo',
        () async {
      final pairing = await BoxPairingService.init();
      await pairing.setPairing('0202', 1);

      await pairing.unassignBox('0202');
      expect(pairing.sideForBox('0202'), isNull);

      await pairing.setPairing('0202', 2);
      expect(pairing.sideForBox('0202'), 2);
    });

    test('la persistencia sobrevive a un reinicio del servicio', () async {
      final first = await BoxPairingService.init();
      await first.setPairing('0203', 1); // lado izquierdo

      final reloaded = await BoxPairingService.init();
      expect(reloaded.sideForBox('0203'), 1);
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
      // Montaje habitual: 0201/0202 a la izquierda, 0203/0204 a la derecha.
      for (final id in ['0201', '0202']) {
        await pairing.setPairing(id, BoxPairingService.left);
      }
      for (final id in ['0203', '0204']) {
        await pairing.setPairing(id, BoxPairingService.right);
      }
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

    test('tras el cambio de lado, la caja izquierda puntúa al otro equipo',
        () async {
      bloc.add(const ScoringEvent.swapSides());
      await pumpEventQueue();
      final before = _points(bloc);
      handler.handle('BTN:0201:P'); // caja izquierda
      await pumpEventQueue();
      final after = _points(bloc);

      expect(after.red, greaterThan(before.red));
      expect(after.blue, before.blue);
    });

    test('con cajas configuradas, el asistente pide confirmación primero',
        () async {
      pairing.startSetup();
      expect(pairing.setup.value!.confirming, isTrue);

      // Mientras no se confirma, una pulsación ni puntúa ni se registra.
      final before = _points(bloc);
      handler.handle('BTN:0201:P');
      await pumpEventQueue();
      expect(_points(bloc), before);
      expect(pairing.setup.value!.captured, isEmpty);

      pairing.confirmSetup();
      expect(pairing.setup.value!.side, BoxPairingService.left);
    });

    test('sin cajas configuradas, el asistente empieza directamente',
        () async {
      for (final id in ['0201', '0202', '0203', '0204']) {
        await pairing.removeBox(id);
      }
      pairing.startSetup();
      expect(pairing.setup.value!.confirming, isFalse);
      expect(pairing.setup.value!.side, BoxPairingService.left);
    });

    test('con el asistente abierto la pulsación registra la caja y no puntúa',
        () async {
      pairing
        ..startSetup()
        ..confirmSetup();
      final before = _points(bloc);
      for (final id in ['0204', '0203']) {
        handler.handle('BTN:$id:P');
      }
      handler.handle('BTN:0203:P'); // repetida: avisa y no avanza
      expect(pairing.setup.value!.repeated, '0203');
      for (final id in ['0201', '0202']) {
        handler.handle('BTN:$id:G');
      }
      await pumpEventQueue();

      expect(_points(bloc), before);
      expect(handler.pendingReset.value, isFalse);
      expect(pairing.setup.value!.done, isTrue);
      // Primero se configura la izquierda: 0204/0203 quedan a la izquierda.
      expect(pairing.sideForBox('0204'), BoxPairingService.left);
      expect(pairing.sideForBox('0201'), BoxPairingService.right);
    });

    test('el asistente sustituye el emparejamiento anterior', () async {
      pairing
        ..startSetup()
        ..confirmSetup();
      handler.handle('BTN:0201:P');
      await pairing.nextSetupSide(); // solo una caja a la izquierda
      handler.handle('BTN:0203:P');
      await pairing.nextSetupSide(); // y una a la derecha
      expect(pairing.setup.value!.done, isTrue);
      expect(pairing.sideForBox('0202'), isNull);
      expect(pairing.sideForBox('0204'), isNull);

      final reloaded = await BoxPairingService.init();
      expect(reloaded.pairings.value, {'0201': 1, '0203': 2});
    });

    test('cerrar el asistente a medias no cambia nada', () async {
      pairing
        ..startSetup()
        ..confirmSetup();
      handler.handle('BTN:0203:P');
      pairing.closeSetup();
      expect(pairing.sideForBox('0203'), BoxPairingService.right);
    });

    test('reasignar una caja cambia el equipo al que puntúa', () async {
      await pairing.setPairing('0201', 2); // 0201 pasa al lado derecho
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
