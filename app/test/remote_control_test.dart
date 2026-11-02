import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Puntazo/config/app_config.dart';
import 'package:Puntazo/config/box_pairing_service.dart';
import 'package:Puntazo/config/team_selection_service.dart';
import 'package:Puntazo/features/match_control/hardware_command_handler.dart';
import 'package:Puntazo/features/remote/remote_control_service.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_bloc.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_event.dart';
import 'audio_stub.dart';

/// Habla con el servidor de verdad, por HTTP, como lo haría el celular.
class _Phone {
  _Phone(this.port);
  final int port;
  final _client = HttpClient();
  String? token;

  Future<(int, Map<String, dynamic>)> call(String method, String path,
      [Map<String, dynamic>? body]) async {
    final req = await _client.open(method, '127.0.0.1', port, '/api/v1$path');
    if (token != null) req.headers.set('Authorization', 'Bearer $token');
    if (body != null) req.write(jsonEncode(body));
    final res = await req.close();
    final text = await utf8.decoder.bind(res).join();
    return (res.statusCode, jsonDecode(text) as Map<String, dynamic>);
  }

  Future<int> login(String pin) async {
    final (status, data) = await call('POST', '/login', {'pin': pin});
    if (status == 200) token = data['token'] as String;
    return status;
  }

  Future<Map<String, dynamic>> send(Map<String, dynamic> cmd) async =>
      (await call('POST', '/comando', cmd)).$2;
}

void main() {
  stubAudioPlayers();
  // El binding de test sustituye HttpClient por uno que siempre da 400.
  HttpOverrides.global = null;

  late ScoringBloc bloc;
  late RemoteControlService remote;
  late TeamSelectionService teams;
  late _Phone phone;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'remote_pin': '4821', 'remote_enabled': true});
    bloc = ScoringBloc()..add(const ScoringEvent.newMatch());
    teams = await TeamSelectionService.init(const AppConfig(availableTeams: [
      TeamDef(id: 'verde', displayName: 'Verde', colorHex: '#009900'),
      TeamDef(id: 'negro', displayName: 'Negro', colorHex: '#171717'),
    ]));
    remote = await RemoteControlService.init(port: 0);
    await remote.attach(
      handler: HardwareCommandHandler(bloc: bloc, pairing: await BoxPairingService.init()),
      teams: teams,
    );
    phone = _Phone(remote.boundPort!);
  });

  tearDown(() async {
    await remote.stop();
    await bloc.close();
  });

  String points(Map<String, dynamic> estado, int team) =>
      (estado['equipos'] as List)[team - 1]['puntos'] as String;

  test('sin PIN no se puede ni mirar el marcador', () async {
    expect((await phone.call('GET', '/estado')).$1, 401);
    expect((await phone.call('POST', '/comando', {'accion': 'punto', 'equipo': 1})).$1, 401);
    expect((await phone.call('GET', '/info')).$1, 200);

    // La página del árbitro se sirve sin PIN: el PIN se pide dentro.
    final req = await HttpClient().get('127.0.0.1', phone.port, '/');
    final res = await req.close();
    expect(res.statusCode, 200);
    expect(await utf8.decoder.bind(res).join(), contains('Puntazo · Árbitro'));
  });

  test('5 PIN incorrectos bloquean, aunque luego llegue el bueno', () async {
    for (var i = 0; i < RemoteControlService.maxFailures; i++) {
      expect(await phone.login('0000'), 401);
    }
    expect(await phone.login('4821'), 429);
  });

  test('un punto repetido por un reintento se anota una sola vez', () async {
    expect(await phone.login('4821'), 200);
    final cmd = {'id': 'abc', 'accion': 'punto', 'equipo': 1};
    expect(points(await phone.send(cmd), 1), '15');
    expect(points(await phone.send(cmd), 1), '15');
    expect(points(await phone.send({...cmd, 'id': 'def'}), 1), '30');

    final estado = await phone.send({'id': 'ghi', 'accion': 'quitar', 'equipo': 1});
    expect(points(estado, 1), '15');
  });

  test('el punto va a la pareja, no al lado, aunque cambien de lado', () async {
    await phone.login('4821');
    final estado = await phone.send({'id': '1', 'accion': 'lado'});
    expect(estado['izquierda'], 2);
    expect(points(await phone.send({'id': '2', 'accion': 'punto', 'equipo': 1}), 1), '15');
    expect(points(await phone.send({'id': '3', 'accion': 'punto', 'equipo': 1}), 2), '0');
  });

  test('los nombres llegan al marcador; sin nombres se ve el color', () async {
    await phone.login('4821');
    final estado = await phone.send({
      'id': '1',
      'accion': 'nombres',
      'jugadores': [
        ['Ana', ' Luis '],
        ['', ''],
      ],
    });
    expect((estado['equipos'] as List)[0]['nombre'], 'Ana / Luis');
    expect((estado['equipos'] as List)[1]['nombre'], 'Negro');
    expect(teams.nameFor(1), 'Ana / Luis');
  });

  test('cambiar el PIN echa a los celulares conectados', () async {
    await phone.login('4821');
    expect(await remote.setPin('1111', current: '0000'), isFalse);
    expect(await remote.setPin('1111', current: '4821'), isTrue);
    expect((await phone.call('GET', '/estado')).$1, 401);
    expect(await phone.login('1111'), 200);
  });
}
