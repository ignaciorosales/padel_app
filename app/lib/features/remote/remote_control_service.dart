import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Puntazo/config/team_selection_service.dart';
import 'package:Puntazo/features/match_control/hardware_command_handler.dart';
import 'package:Puntazo/features/models/scoring_models.dart';
import 'package:Puntazo/features/scoring/bloc/scoring_event.dart';

/// Control del marcador desde un celular en la misma red que la tele.
///
/// La tele levanta un servidor HTTP en la red local: sirve la página del
/// árbitro en `/` y una API JSON en `/api/v1/`. No necesita internet, sólo
/// que el celular y la tele se vean (WiFi del club o hotspot del celular).
///
/// Contrato de la API v1 (otras apps futuras hablarán con ella, así que
/// añadir campos está bien; cambiar o quitar los existentes obliga a `v2`):
///
/// | Método | Ruta              | Cuerpo / respuesta                         |
/// |--------|-------------------|--------------------------------------------|
/// | GET    | `/api/v1/info`    | `{app, api}` — sin PIN, para descubrir      |
/// | POST   | `/api/v1/login`   | `{pin}` → `{token}`; 401 / 429 si falla     |
/// | GET    | `/api/v1/estado`  | el marcador ([estado])                      |
/// | POST   | `/api/v1/comando` | `{id, accion, equipo?, jugadores?}` → estado |
///
/// Todo lo que no es `info` ni `login` pide `Authorization: Bearer <token>`.
/// `equipo` es 1 o 2 (la pareja, no el lado: los lados cambian). `id` es
/// único por pulsación; si un reintento repite uno ya visto, se ignora, para
/// que un corte de WiFi no anote un punto dos veces.
class RemoteControlService {
  RemoteControlService._(this._prefs, {this.port = defaultPort})
      : enabled = ValueNotifier(_prefs.getBool(_keyEnabled) ?? false);

  static const int defaultPort = 8080;
  static const int apiVersion = 1;
  static const String _keyEnabled = 'remote_enabled';
  static const String _keyPin = 'remote_pin';

  /// Intentos de PIN fallidos seguidos antes de bloquear esa IP.
  static const int maxFailures = 5;
  static const Duration lockout = Duration(minutes: 1);

  /// Un celular cuenta como conectado si habló hace menos de esto. La página
  /// pregunta el estado cada segundo.
  static const Duration _connectedWindow = Duration(seconds: 10);

  static Future<RemoteControlService> init({int port = defaultPort}) async {
    final prefs = await SharedPreferences.getInstance();
    return RemoteControlService._(prefs, port: port);
  }

  final SharedPreferences _prefs;
  final int port;

  /// Si el club tiene activado el control desde el celular.
  final ValueNotifier<bool> enabled;

  /// `http://<ip>:<puerto>` mientras el servidor escucha; null si no.
  final ValueNotifier<String?> address = ValueNotifier(null);

  /// Celulares que han hablado en los últimos segundos.
  final ValueNotifier<int> connectedPhones = ValueNotifier(0);

  /// Último error al arrancar (puerto ocupado, sin red...).
  final ValueNotifier<String?> error = ValueNotifier(null);

  HardwareCommandHandler? _handler;
  TeamSelectionService? _teams;
  HttpServer? _server;
  Timer? _ticker;
  String? _page;

  final Map<String, DateTime> _tokens = {};
  final Map<String, int> _failures = {};
  final Map<String, DateTime> _lockedUntil = {};
  final LinkedHashSet<String> _seenIds = LinkedHashSet();

  String? get _pin => _prefs.getString(_keyPin);
  bool get hasPin => (_pin ?? '').isNotEmpty;

  /// Puerto real en el que escucha (útil con `port: 0` en tests).
  int? get boundPort => _server?.port;

  /// Lo engancha al marcador. Hasta entonces no hay nada que controlar.
  Future<void> attach({
    required HardwareCommandHandler handler,
    required TeamSelectionService teams,
  }) async {
    _handler = handler;
    _teams = teams;
    if (enabled.value && hasPin) await start();
  }

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    await _prefs.setBool(_keyEnabled, value);
    if (value && hasPin) {
      await start();
    } else {
      await stop();
    }
  }

  /// Comprueba el PIN del club (para abrir sus ajustes en la tele).
  bool checkPin(String pin) => hasPin && pin == _pin;

  /// Cambia el PIN. Si ya había uno, hay que saber el actual. Cambiarlo echa
  /// a todos los celulares conectados: tienen que volver a escribirlo.
  Future<bool> setPin(String newPin, {String? current}) async {
    if (!isValidPin(newPin)) return false;
    if (hasPin && current != _pin) return false;
    await _prefs.setString(_keyPin, newPin);
    _tokens.clear();
    connectedPhones.value = 0;
    if (enabled.value) await start();
    return true;
  }

  static bool isValidPin(String pin) => RegExp(r'^\d{4,8}$').hasMatch(pin);

  Future<void> start() async {
    if (_server != null || _handler == null) return;
    try {
      final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _server = server;
      error.value = null;
      server.listen(_onRequest, onError: (_) {});
      address.value = 'http://${await _localIp()}:${server.port}';
      _ticker = Timer.periodic(const Duration(seconds: 2), (_) => _countPhones());
    } catch (e) {
      error.value = 'No se pudo abrir el puerto $port: $e';
    }
  }

  Future<void> stop() async {
    _ticker?.cancel();
    _ticker = null;
    await _server?.close(force: true);
    _server = null;
    address.value = null;
    connectedPhones.value = 0;
  }

  Future<void> dispose() async {
    await stop();
    enabled.dispose();
    address.dispose();
    connectedPhones.dispose();
    error.dispose();
  }

  // --------------------------------------------------------------- peticiones

  Future<void> _onRequest(HttpRequest req) async {
    final res = req.response;
    try {
      final path = req.uri.path;
      if (req.method == 'GET' && (path == '/' || path == '/index.html')) {
        _page ??= await rootBundle.loadString('assets/remote/arbitro.html');
        res.headers.contentType = ContentType.html;
        res.write(_page);
      } else if (req.method == 'GET' && path == '/api/v1/info') {
        _json(res, 200, {'app': 'puntazo', 'api': apiVersion});
      } else if (req.method == 'POST' && path == '/api/v1/login') {
        await _login(req);
      } else if (path == '/api/v1/estado' || path == '/api/v1/comando') {
        if (!_authorized(req)) {
          _json(res, 401, {'error': 'PIN requerido'});
        } else if (req.method == 'GET' && path == '/api/v1/estado') {
          _json(res, 200, estado());
        } else if (req.method == 'POST' && path == '/api/v1/comando') {
          await _command(req);
        } else {
          _json(res, 405, {'error': 'método no permitido'});
        }
      } else {
        _json(res, 404, {'error': 'no existe'});
      }
    } catch (_) {
      _json(res, 400, {'error': 'petición inválida'});
    }
    await res.close();
  }

  Future<void> _login(HttpRequest req) async {
    final ip = req.connectionInfo?.remoteAddress.address ?? '?';
    final now = DateTime.now();
    final locked = _lockedUntil[ip];
    if (locked != null && now.isBefore(locked)) {
      _json(req.response, 429, {
        'error': 'Demasiados intentos',
        'segundos': locked.difference(now).inSeconds + 1,
      });
      return;
    }
    final body = await _body(req);
    if (checkPin('${body['pin'] ?? ''}')) {
      _failures.remove(ip);
      _lockedUntil.remove(ip);
      final token = _newToken();
      _tokens[token] = now;
      _json(req.response, 200, {'token': token});
      return;
    }
    final fails = (_failures[ip] ?? 0) + 1;
    _failures[ip] = fails;
    if (fails >= maxFailures) {
      _failures.remove(ip);
      _lockedUntil[ip] = now.add(lockout);
    }
    _json(req.response, 401, {'error': 'PIN incorrecto'});
  }

  Future<void> _command(HttpRequest req) async {
    final body = await _body(req);
    final id = '${body['id'] ?? ''}';
    if (id.isNotEmpty && !_seenIds.add(id)) {
      // Reintento de una pulsación que ya llegó: no se aplica dos veces.
      _json(req.response, 200, estado());
      return;
    }
    if (_seenIds.length > 200) _seenIds.remove(_seenIds.first);

    final handler = _handler!;
    final bloc = handler.bloc;
    final team = switch (body['equipo']) {
      1 => Team.blue,
      2 => Team.red,
      _ => null,
    };
    final accion = body['accion'];
    // Un comando del celular gana a un reinicio que esperaba confirmación
    // en las cajas.
    if (accion != 'nuevo_partido') handler.cancelReset();

    switch (accion) {
      case 'punto' when team != null:
        bloc.add(ScoringEvent.pointFor(team));
      case 'quitar' when team != null:
        bloc.add(ScoringEvent.undoForTeam(team));
      case 'lado':
        bloc.add(const ScoringEvent.swapSides());
      case 'nombres':
        final jugadores = body['jugadores'] as List;
        for (var i = 0; i < 2; i++) {
          await _teams!.setPlayers(
            i + 1,
            [for (final n in jugadores[i] as List) '$n'],
          );
        }
      case 'nuevo_partido':
        handler.performReset();
      default:
        _json(req.response, 400, {'error': 'acción desconocida'});
        return;
    }
    // El bloc procesa el evento en microtareas; tras un turno del bucle ya
    // ha emitido y el estado que se devuelve incluye el comando.
    await Future<void>.delayed(Duration.zero);
    _json(req.response, 200, estado());
  }

  /// El marcador tal como lo necesita quien lo controla desde fuera.
  @visibleForTesting
  Map<String, dynamic> estado() {
    final state = _handler!.bloc.state;
    final teams = _teams!;
    final m = state.match;
    final set = m.currentSet;
    final game = set.currentGame;

    Map<String, dynamic> equipo(int i) {
      final isBlue = i == 1;
      final def = isBlue ? teams.getTeam1() : teams.getTeam2();
      final us = isBlue ? game.blue : game.red;
      final them = isBlue ? game.red : game.blue;
      return {
        'equipo': i,
        'nombre': teams.nameFor(i),
        'color': def?.colorHex ?? (isBlue ? '#009900' : '#171717'),
        'colorNombre': def?.displayName ?? 'Equipo $i',
        'jugadores': teams.playersOf(i).value,
        'puntos': pointLabel(us, them, game.isTieBreak),
        'juegos': isBlue ? set.blueGames : set.redGames,
        'saca': m.servingTeam == (isBlue ? Team.blue : Team.red),
      };
    }

    return {
      'api': apiVersion,
      'equipos': [equipo(1), equipo(2)],
      // Qué pareja se ve a la izquierda de la tele ahora mismo.
      'izquierda': state.isSwapped ? 2 : 1,
      'setsAnteriores': [
        for (final s in m.sets.take(m.currentSetIndex)) [s.blueGames, s.redGames],
      ],
      'tieBreak': game.isTieBreak,
      'terminado': state.matchCompleted,
      'ganador': switch (state.matchWinner) {
        Team.blue => 1,
        Team.red => 2,
        null => null,
      },
    };
  }

  // ---------------------------------------------------------------- utilidades

  bool _authorized(HttpRequest req) {
    final auth = req.headers.value(HttpHeaders.authorizationHeader) ?? '';
    final token = auth.startsWith('Bearer ') ? auth.substring(7) : '';
    if (!_tokens.containsKey(token)) return false;
    _tokens[token] = DateTime.now();
    return true;
  }

  void _countPhones() {
    final since = DateTime.now().subtract(_connectedWindow);
    connectedPhones.value = _tokens.values.where((t) => t.isAfter(since)).length;
  }

  static Future<Map<String, dynamic>> _body(HttpRequest req) async {
    // Cuatro nombres y un id: nada legítimo pasa de unos cientos de bytes.
    if ((req.contentLength) > 4096) throw const FormatException('demasiado grande');
    final text = await utf8.decoder.bind(req).join();
    return text.isEmpty ? {} : jsonDecode(text) as Map<String, dynamic>;
  }

  static void _json(HttpResponse res, int status, Object body) {
    res.statusCode = status;
    res.headers.contentType = ContentType.json;
    res.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    res.write(jsonEncode(body));
  }

  static String _newToken() {
    final rnd = Random.secure();
    return [for (var i = 0; i < 16; i++) rnd.nextInt(256).toRadixString(16).padLeft(2, '0')]
        .join();
  }

  /// La IP de la tele en la red local, para el QR.
  static Future<String> _localIp() async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    final addresses = [
      for (final i in interfaces)
        for (final a in i.addresses)
          if (!a.isLoopback) a.address,
    ];
    // 192.168 primero: las 172.x suelen ser adaptadores virtuales (WSL,
    // Hyper-V, Docker) a los que el celular no llega.
    for (final prefix in const ['192.168.', '10.', '172.']) {
      for (final a in addresses) {
        if (a.startsWith(prefix)) return a;
      }
    }
    return addresses.isEmpty ? '127.0.0.1' : addresses.first;
  }
}
