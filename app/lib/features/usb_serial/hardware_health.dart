import 'dart:async';

import 'package:flutter/foundation.dart';

/// Gravedad de un problema detectado en la cadena esclavos → maestro → app.
enum IssueLevel {
  /// El sistema NO puede funcionar así.
  critical,

  /// Funciona, pero hay algo mal que acabará dando problemas.
  warning,

  /// Solo informativo / falta un paso de configuración.
  info,
}

/// Un problema concreto con su explicación y qué hacer para arreglarlo.
///
/// La gracia de esta clase es [action]: durante una instalación en pista no
/// sirve de nada saber que "algo falla", hace falta saber qué tocar.
class HealthIssue {
  const HealthIssue({
    required this.level,
    required this.title,
    required this.detail,
    this.action,
  });

  final IssueLevel level;
  final String title;
  final String detail;
  final String? action;
}

/// Etapa de la conexión USB con el maestro.
///
/// Las tres primeras fallan de forma idéntica desde fuera ("no llega nada"),
/// y distinguirlas es justo lo que ahorra tiempo al instalar.
enum UsbStage {
  /// No se ve ningún dispositivo USB.
  noDevice,

  /// Se ve el dispositivo pero no se pudo abrir el puerto (casi siempre el
  /// permiso USB de Android sin aceptar).
  deviceNotOpened,

  /// Puerto abierto pero el maestro no dice nada.
  openNoData,

  /// Llegan líneas, pero ninguna es telemetría (firmware antiguo).
  dataNoTelemetry,

  /// Todo correcto.
  operational,
}

/// Estado de una caja de botones, tal y como lo reporta el maestro.
@immutable
class BoxHealth {
  const BoxHealth({
    required this.id,
    this.online = false,
    this.replies = 0,
    this.timeouts = 0,
    this.crcErrors = 0,
    this.commands = 0,
    this.lastRttMs = 0,
    this.ageMs = -1,
  });

  /// ID de la caja en hex de 4 dígitos, minúsculas (`0201`).
  final String id;

  /// El maestro ha recibido respuesta suya recientemente.
  final bool online;

  /// Respuestas válidas acumuladas desde que arrancó el maestro.
  final int replies;

  /// Polls a los que no contestó.
  final int timeouts;

  /// Tramas suyas descartadas por CRC incorrecto (bus con ruido).
  final int crcErrors;

  /// Pulsaciones reales (p/u/g) reenviadas a la app.
  final int commands;

  /// Ida y vuelta de la última respuesta, en ms.
  final int lastRttMs;

  /// Milisegundos desde la última respuesta válida. `-1` = nunca respondió.
  final int ageMs;

  /// Nunca ha contestado desde que el maestro arrancó.
  bool get neverSeen => ageMs < 0;

  /// Proporción de polls perdidos (0..1). Útil para detectar un bus que
  /// funciona "a ratos", que es peor de diagnosticar que uno muerto del todo.
  double get lossRatio {
    final total = replies + timeouts;
    if (total == 0) return 0;
    return timeouts / total;
  }
}

/// Estado del propio maestro.
@immutable
class MasterHealth {
  const MasterHealth({
    required this.fwVersion,
    required this.uptimeMs,
    required this.cycleMs,
    required this.onlineCount,
    required this.slaveCount,
    required this.polls,
    required this.rxBytes,
    required this.frames,
    required this.crcErrors,
    required this.wrongId,
    required this.rs485Baud,
    required this.usbBaud,
  });

  final int fwVersion;
  final int uptimeMs;

  /// Duración de la última vuelta de poleo a las 4 cajas, en ms. Sube mucho
  /// cuando alguna caja no responde.
  final int cycleMs;

  final int onlineCount;
  final int slaveCount;
  final int polls;
  final int rxBytes;
  final int frames;

  /// Tramas descartadas por CRC (agregado de todas las cajas).
  final int crcErrors;

  /// Tramas cuyo ID no era el esperado. Si esto sube, hay dos cajas con el
  /// mismo `DEV_ID` o una caja con un ID que el maestro no polea.
  final int wrongId;

  final int rs485Baud;
  final int usbBaud;
}

/// Versión mínima del firmware del maestro que emite telemetría `[PS]`/`[MS]`.
const int kMinTelemetryFirmware = 2;

/// IDs por defecto de las 4 cajas, usados solo hasta que el maestro reporta
/// los suyos.
const List<String> kDefaultBoxIds = ['0201', '0202', '0203', '0204'];

/// Recoge la telemetría del maestro y la convierte en un diagnóstico
/// accionable.
///
/// El maestro ya sabía qué caja respondía, pero solo publicaba contadores
/// globales; esta clase consume las líneas nuevas `[PS]` (por caja) y `[MS]`
/// (del maestro) y mantiene el estado vivo, incluyendo un watchdog para
/// detectar que el maestro se ha quedado mudo.
class HardwareHealthMonitor extends ChangeNotifier {
  HardwareHealthMonitor({this.onSend}) {
    _watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      // Solo repinta si algo que depende del tiempo ha cambiado de estado.
      final alive = masterAlive;
      if (alive != _lastAliveNotified) {
        _lastAliveNotified = alive;
        notifyListeners();
      } else if (_boxes.isNotEmpty || _usbConnected) {
        notifyListeners();
      }
    });
  }

  /// Envía una línea al maestro (p. ej. `STATUS`). Lo inyecta quien construye
  /// el monitor, para no acoplarlo al transporte USB.
  final Future<void> Function(String line)? onSend;

  Timer? _watchdog;
  bool _lastAliveNotified = false;

  // ---- Estado USB ---------------------------------------------------------
  bool _usbConnected = false;
  String? _usbDeviceName;
  int _usbDevicesFound = 0;
  String? _usbError;

  bool get usbConnected => _usbConnected;
  String? get usbDeviceName => _usbDeviceName;
  int get usbDevicesFound => _usbDevicesFound;
  String? get usbError => _usbError;

  // ---- Estado del maestro -------------------------------------------------
  MasterHealth? _master;
  DateTime? _lastMasterLine;
  DateTime? _lastTelemetryLine;
  DateTime? _lastAnyLine;

  MasterHealth? get master => _master;
  DateTime? get lastTelemetryLine => _lastTelemetryLine;

  /// Cuánto hace que llegó cualquier línea del maestro.
  Duration? get sinceLastLine =>
      _lastAnyLine == null ? null : DateTime.now().difference(_lastAnyLine!);

  /// El maestro ha hablado en los últimos 6 s. El firmware emite telemetría
  /// cada 2 s, así que 6 s son tres envíos perdidos.
  bool get masterAlive {
    if (!_usbConnected || _lastAnyLine == null) return false;
    return DateTime.now().difference(_lastAnyLine!).inSeconds < 6;
  }

  /// El firmware del maestro emite las líneas de telemetría nuevas.
  bool get hasTelemetry => _lastTelemetryLine != null;

  // ---- Estado de las cajas ------------------------------------------------
  final Map<String, BoxHealth> _boxes = {};
  final Map<String, Set<String>> _buttonsSeen = {};

  /// Cajas conocidas, ordenadas por ID.
  List<BoxHealth> get boxes {
    final list = _boxes.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    return list;
  }

  /// Botones (`P`, `U`, `G`) vistos por caja desde el último reinicio de la
  /// prueba. Sirve para comprobar en la instalación que las 3 teclas de cada
  /// caja llegan realmente a la app.
  Set<String> buttonsSeenFor(String boxId) =>
      _buttonsSeen[_norm(boxId)] ?? const {};

  /// Cuando está activo, los comandos del hardware NO puntúan: solo se
  /// registran para la prueba de botones.
  bool buttonTestMode = false;

  void setButtonTestMode(bool value) {
    if (buttonTestMode == value) return;
    buttonTestMode = value;
    notifyListeners();
  }

  void resetButtonTest() {
    _buttonsSeen.clear();
    notifyListeners();
  }

  // ---- Log crudo ----------------------------------------------------------
  final List<String> _logs = [];
  static const int _maxLogs = 300;

  List<String> get logs => List.unmodifiable(_logs);

  // ---- Entradas -----------------------------------------------------------

  void setUsbConnected(bool connected, {String? deviceName}) {
    _usbConnected = connected;
    _usbDeviceName = connected ? deviceName : null;
    if (!connected) {
      // Al perder el puerto, lo que sabíamos de las cajas ya no vale.
      _master = null;
      _boxes.clear();
      _lastMasterLine = null;
      _lastTelemetryLine = null;
      _lastAnyLine = null;
    }
    notifyListeners();
  }

  void setUsbDevicesFound(int count) {
    _usbDevicesFound = count;
    notifyListeners();
  }

  void setUsbError(String? error) {
    _usbError = error;
    notifyListeners();
  }

  /// Procesa una línea de depuración del maestro.
  ///
  /// Acepta tanto la línea cruda (`[PS] dev=...`) como la envuelta por el
  /// listener (`ESP32: [PS] dev=...`).
  void ingestLine(String raw) {
    var line = raw.trim();
    if (line.isEmpty) return;

    _pushLog(line);

    const prefix = 'ESP32:';
    if (line.startsWith(prefix)) {
      line = line.substring(prefix.length).trim();
    }
    if (!line.startsWith('[')) {
      notifyListeners();
      return;
    }

    _lastAnyLine = DateTime.now();

    if (line.startsWith('[PS]')) {
      _ingestBoxStatus(line);
    } else if (line.startsWith('[MS]')) {
      _ingestMasterStatus(line);
    } else if (line.startsWith('[EVT]')) {
      _ingestEvent(line);
    }
    notifyListeners();
  }

  /// Registra un comando recibido del hardware (`BTN:0201:P`).
  void ingestCommand(String cmd) {
    _lastAnyLine = DateTime.now();
    final parts = cmd.split(':');
    if (parts.length != 3 || parts[0].toUpperCase() != 'BTN') {
      notifyListeners();
      return;
    }
    final id = _norm(parts[1]);
    final letter = parts[2].toUpperCase();
    (_buttonsSeen[id] ??= <String>{}).add(letter);
    notifyListeners();
  }

  // ---- Parsing ------------------------------------------------------------

  /// `[PS] dev=0201 on=1 rep=412 to=0 crc=0 cmd=7 rtt=18 age=31`
  void _ingestBoxStatus(String line) {
    final kv = _parseKeyValues(line);
    final dev = kv['dev'];
    if (dev == null) return;
    final id = _norm(dev);
    _boxes[id] = BoxHealth(
      id: id,
      online: (_asInt(kv['on']) ?? 0) == 1,
      replies: _asInt(kv['rep']) ?? 0,
      timeouts: _asInt(kv['to']) ?? 0,
      crcErrors: _asInt(kv['crc']) ?? 0,
      commands: _asInt(kv['cmd']) ?? 0,
      lastRttMs: _asInt(kv['rtt']) ?? 0,
      ageMs: _asInt(kv['age']) ?? -1,
    );
    _lastTelemetryLine = DateTime.now();
  }

  /// `[MS] fw=2 up=125340 cyc=34 on=4/4 polls=2010 rxb=... rs485=9600 usb=115200`
  void _ingestMasterStatus(String line) {
    final kv = _parseKeyValues(line);
    final on = kv['on'] ?? '';
    final slash = on.indexOf('/');
    final onlineCount = slash > 0 ? (int.tryParse(on.substring(0, slash)) ?? 0) : 0;
    final slaveCount = slash > 0 ? (int.tryParse(on.substring(slash + 1)) ?? 0) : 0;

    _master = MasterHealth(
      fwVersion: _asInt(kv['fw']) ?? 0,
      uptimeMs: _asInt(kv['up']) ?? 0,
      cycleMs: _asInt(kv['cyc']) ?? 0,
      onlineCount: onlineCount,
      slaveCount: slaveCount,
      polls: _asInt(kv['polls']) ?? 0,
      rxBytes: _asInt(kv['rxb']) ?? 0,
      frames: _asInt(kv['frm']) ?? 0,
      crcErrors: _asInt(kv['crc']) ?? 0,
      wrongId: _asInt(kv['wid']) ?? 0,
      rs485Baud: _asInt(kv['rs485']) ?? 0,
      usbBaud: _asInt(kv['usb']) ?? 0,
    );
    _lastMasterLine = DateTime.now();
    _lastTelemetryLine = _lastMasterLine;
  }

  /// `[EVT] dev=0201 online` / `[EVT] dev=0201 offline`
  void _ingestEvent(String line) {
    final kv = _parseKeyValues(line);
    final dev = kv['dev'];
    if (dev == null) return;
    final id = _norm(dev);
    final existing = _boxes[id];
    final online = line.contains('offline') ? false : line.contains('online');
    _boxes[id] = BoxHealth(
      id: id,
      online: online,
      replies: existing?.replies ?? 0,
      timeouts: existing?.timeouts ?? 0,
      crcErrors: existing?.crcErrors ?? 0,
      commands: existing?.commands ?? 0,
      lastRttMs: existing?.lastRttMs ?? 0,
      ageMs: existing?.ageMs ?? -1,
    );
  }

  /// Extrae los pares `clave=valor` separados por espacios de una línea.
  static Map<String, String> _parseKeyValues(String line) {
    final out = <String, String>{};
    for (final token in line.split(RegExp(r'\s+'))) {
      final eq = token.indexOf('=');
      if (eq <= 0) continue;
      out[token.substring(0, eq)] = token.substring(eq + 1);
    }
    return out;
  }

  static int? _asInt(String? v) => v == null ? null : int.tryParse(v);

  static String _norm(String id) => id.trim().toLowerCase();

  void _pushLog(String line) {
    _logs.add(line);
    if (_logs.length > _maxLogs) {
      _logs.removeRange(0, _logs.length - _maxLogs);
    }
  }

  // ---- Diagnóstico --------------------------------------------------------

  /// Etapa actual de la conexión, de "no hay nada" a "todo bien".
  UsbStage get stage {
    if (!_usbConnected) {
      return _usbDevicesFound > 0 ? UsbStage.deviceNotOpened : UsbStage.noDevice;
    }
    if (_lastAnyLine == null) return UsbStage.openNoData;
    if (!hasTelemetry) return UsbStage.dataNoTelemetry;
    return UsbStage.operational;
  }

  /// Pide al maestro un informe inmediato en vez de esperar al periódico.
  Future<void> requestStatus() async {
    await onSend?.call('STATUS');
  }

  /// Lista de problemas detectados, del más grave al menos.
  ///
  /// [pairedBoxIds] son las cajas que tienen equipo asignado en Ajustes; se
  /// usa para avisar de una caja que funciona pero no puntuaría.
  List<HealthIssue> issues({Set<String> pairedBoxIds = const {}}) {
    final out = <HealthIssue>[];

    // --- Cadena USB ---
    switch (stage) {
      case UsbStage.noDevice:
        out.add(const HealthIssue(
          level: IssueLevel.critical,
          title: 'No se detecta el maestro por USB',
          detail: 'Android no ve ningún dispositivo serie conectado.',
          action: 'Revisa el cable USB y el adaptador OTG. Prueba otro puerto '
              'del box y comprueba que el maestro tiene alimentación.',
        ));
      case UsbStage.deviceNotOpened:
        out.add(HealthIssue(
          level: IssueLevel.critical,
          title: 'Dispositivo USB detectado pero no se puede abrir',
          detail: 'Se ven $_usbDevicesFound dispositivo(s), pero el puerto no '
              'abre. Casi siempre es el permiso USB de Android sin aceptar.'
              '${_usbError == null ? '' : '\n$_usbError'}',
          action: 'Acepta el diálogo de permiso USB y marca "usar por defecto '
              'para este dispositivo". Si no aparece, desenchufa y vuelve a '
              'enchufar el maestro.',
        ));
      case UsbStage.openNoData:
        out.add(const HealthIssue(
          level: IssueLevel.critical,
          title: 'Puerto abierto pero el maestro no envía nada',
          detail: 'La conexión USB está establecida y no llega ni una línea.',
          action: 'El maestro puede estar sin firmware, colgado o a otra '
              'velocidad. Reinicia el maestro; si sigue mudo, reflashéalo.',
        ));
      case UsbStage.dataNoTelemetry:
        out.add(const HealthIssue(
          level: IssueLevel.warning,
          title: 'Firmware del maestro antiguo',
          detail: 'Llegan líneas del maestro, pero ninguna de telemetría '
              '([PS]/[MS]). Sin ellas no se puede saber el estado de cada caja.',
          action: 'Reflashea el maestro con firmware/maestro/maestro.ino '
              '(versión $kMinTelemetryFirmware o superior).',
        ));
      case UsbStage.operational:
        break;
    }

    // Maestro mudo tras haber hablado: el cable sigue puesto pero se colgó.
    if (_usbConnected && _lastAnyLine != null && !masterAlive) {
      final secs = DateTime.now().difference(_lastAnyLine!).inSeconds;
      out.add(HealthIssue(
        level: IssueLevel.critical,
        title: 'El maestro ha dejado de responder',
        detail: 'Última línea recibida hace ${secs}s. El firmware envía '
            'telemetría cada 2s, así que se ha colgado o ha perdido corriente.',
        action: 'Reinicia el maestro. Si se repite, revisa la alimentación: '
            'una caída de tensión al pulsar reinicia el ESP32.',
      ));
    }

    // --- Estado del bus RS-485 ---
    final known = _boxes.isEmpty
        ? kDefaultBoxIds.map((id) => BoxHealth(id: id)).toList()
        : boxes;
    final offline = known.where((b) => !b.online).toList();

    if (hasTelemetry && offline.length == known.length && known.isNotEmpty) {
      // Ninguna responde: es el bus, no las cajas.
      out.add(HealthIssue(
        level: IssueLevel.critical,
        title: 'Ninguna caja responde',
        detail: 'El maestro funciona pero las ${known.length} cajas están '
            'mudas. Que fallen todas a la vez apunta al bus, no a las cajas.',
        action: 'Comprueba A/B del RS-485 (cruzados es el fallo más común), '
            'la masa común entre maestro y cajas, y que las cajas tengan '
            'corriente. Revisa también la resistencia de terminación de 120Ω.',
      ));
    } else if (hasTelemetry) {
      for (final box in offline) {
        out.add(HealthIssue(
          level: IssueLevel.critical,
          title: 'Caja ${box.id.toUpperCase()} no responde',
          detail: box.neverSeen
              ? 'No ha contestado ni una vez desde que arrancó el maestro.'
              : 'Dejó de contestar. Timeouts: ${box.timeouts}.',
          action: box.neverSeen
              ? 'Comprueba que esa caja tiene corriente, que su DEV_ID es '
                  '0x${box.id.toUpperCase()} y que sus cables A/B llegan al bus.'
              : 'Revisa su conexión al bus y su alimentación.',
        ));
      }
    }

    // DEV_ID duplicado. No se detecta por "ID inesperado": el esclavo solo
    // contesta si el ID coincide y además devuelve el que le llegó, así que
    // la trama nunca trae un ID raro. Lo que pasa de verdad es que las dos
    // cajas con el mismo ID contestan A LA VEZ, se pisan en el bus (CRC malo)
    // y el ID que quedó sin asignar no contesta nunca. Ese par de síntomas
    // juntos es la firma del problema.
    final noisy = known.where((b) => b.crcErrors > 0).toList();
    final never = known.where((b) => b.neverSeen).toList();
    if (hasTelemetry &&
        noisy.isNotEmpty &&
        never.isNotEmpty &&
        never.length < known.length) {
      final dup = noisy.first.id.toUpperCase();
      final missing = never.first.id.toUpperCase();
      out.add(HealthIssue(
        level: IssueLevel.warning,
        title: 'Posible DEV_ID duplicado',
        detail: 'La caja $dup acumula errores de CRC y $missing no ha '
            'respondido nunca. Dos cajas flasheadas con el mismo DEV_ID '
            'contestan a la vez y se pisan en el bus, dejando mudo el ID que '
            'nadie tiene.',
        action: 'Revisa el #define DEV_ID de las 4 cajas: probablemente una '
            'lleva $dup cuando debería llevar $missing.',
      ));
    }

    // Cajas con ruido en el bus.
    for (final box in known) {
      if (box.crcErrors > 0) {
        out.add(HealthIssue(
          level: IssueLevel.warning,
          title: 'Ruido en el bus con la caja ${box.id.toUpperCase()}',
          detail: '${box.crcErrors} trama(s) descartadas por CRC incorrecto.',
          action: 'Cable demasiado largo, sin par trenzado o sin terminación: '
              'añade 120Ω en los extremos y aléjalo de la corriente de 220V. '
              'Si además hay una caja que no responde nunca, sospecha de dos '
              'cajas con el mismo DEV_ID contestando a la vez.',
        ));
      }
      if (box.online && box.lossRatio > 0.1) {
        out.add(HealthIssue(
          level: IssueLevel.warning,
          title: 'Caja ${box.id.toUpperCase()} responde de forma intermitente',
          detail: 'Pierde el ${(box.lossRatio * 100).toStringAsFixed(0)}% de '
              'los polls (${box.timeouts} de ${box.replies + box.timeouts}).',
          action: 'Un enlace intermitente es peor que uno muerto: revisa '
              'conectores flojos y la calidad del cable.',
        ));
      }
    }

    final m = _master;
    if (m != null && m.wrongId > 0) {
      // Con el firmware correcto esto es prácticamente imposible: el esclavo
      // devuelve el mismo ID que se le pidió. Si aparece, es una trama
      // corrupta que aun así ha pasado el CRC, o un dispositivo ajeno
      // hablando en el bus.
      out.add(HealthIssue(
        level: IssueLevel.warning,
        title: 'Respuestas con ID inesperado',
        detail: '${m.wrongId} trama(s) con un ID distinto del que se pidió. '
            'Con el firmware correcto esto no debería pasar nunca.',
        action: 'Indica corrupción seria en el bus o un dispositivo ajeno '
            'conectado al RS-485. Revisa el cableado y que no haya nada más '
            'compartiendo el par.',
      ));
    }

    if (m != null && m.cycleMs > 120) {
      out.add(HealthIssue(
        level: IssueLevel.info,
        title: 'Ciclo de poleo lento (${m.cycleMs} ms)',
        detail: 'Cada caja ausente cuesta un timeout completo, así que los '
            'botones responden más lento de lo normal.',
        action: 'Se corrige solo al recuperar las cajas que faltan.',
      ));
    }

    // --- Configuración de la app ---
    for (final box in known) {
      if (box.online && !pairedBoxIds.contains(box.id)) {
        out.add(HealthIssue(
          level: IssueLevel.info,
          title: 'Caja ${box.id.toUpperCase()} sin equipo asignado',
          detail: 'Responde correctamente, pero sus pulsaciones no puntúan '
              'porque no está emparejada con ningún equipo.',
          action: 'Asígnala en Ajustes ▸ Mandos.',
        ));
      }
    }

    // --- Prueba de botones ---
    if (buttonTestMode) {
      for (final box in known.where((b) => b.online)) {
        final seen = buttonsSeenFor(box.id);
        final missing = ['P', 'U', 'G'].where((k) => !seen.contains(k));
        if (missing.isNotEmpty) {
          out.add(HealthIssue(
            level: IssueLevel.info,
            title: 'Caja ${box.id.toUpperCase()}: faltan botones por probar',
            detail: 'Sin pulsar todavía: ${missing.join(', ')}.',
            action: 'Pulsa cada botón de esa caja para verificar el cableado '
                'interno.',
          ));
        }
      }
    }

    out.sort((a, b) => a.level.index.compareTo(b.level.index));
    return out;
  }

  /// Resumen de una línea para la cabecera de la pantalla.
  String get summary {
    if (!_usbConnected) return 'Maestro desconectado';
    if (!masterAlive) return 'Maestro sin responder';
    final m = _master;
    if (m == null) return 'Conectado, esperando telemetría';
    return '${m.onlineCount} de ${m.slaveCount} cajas conectadas';
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _watchdog = null;
    super.dispose();
  }
}
