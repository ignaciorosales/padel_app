import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Puntazo/features/usb_serial/hardware_health.dart';

/// Contrato entre el firmware del maestro y el parser de la app.
///
/// El resto de tests usan líneas que escribí a mano, así que comparten la
/// misma fuente de error que el `printf` del firmware: si me equivoco en el
/// formato, el test pasa igual y el fallo aparece en la pista.
///
/// Este test cierra ese hueco leyendo `firmware/maestro/maestro.ino`,
/// extrayendo los `printf` REALES y renderizándolos para dárselos al parser.
/// Si alguien cambia un campo en el firmware sin tocar la app (o al revés),
/// esto se rompe aquí en vez de en la instalación.
void main() {
  final ino = File('../firmware/maestro/maestro.ino');

  setUpAll(() {
    expect(
      ino.existsSync(),
      isTrue,
      reason: 'Los tests deben ejecutarse desde app/ para alcanzar '
          'firmware/maestro/maestro.ino',
    );
  });

  /// Extrae el primer literal de cadena del firmware que empiece por [prefix].
  String formatFor(String prefix) {
    final src = ino.readAsStringSync();
    final match = RegExp('"(${RegExp.escape(prefix)}[^"]*)"').firstMatch(src);
    expect(
      match,
      isNotNull,
      reason: 'No se encontró en el firmware un printf que empiece por '
          '"$prefix". ¿Se renombró la línea de telemetría?',
    );
    return match!.group(1)!;
  }

  /// Sustituye los especificadores de C por los valores dados, en orden.
  ///
  /// Cubre solo lo que usa el firmware: `%04X`, `%u`, `%lu`, `%ld`, `%d`, `%c`.
  String render(String format, List<Object> args) {
    var i = 0;
    final out = format.replaceAllMapped(
      RegExp(r'%(0\d+)?l*([dxXuc])'),
      (m) {
        expect(i, lessThan(args.length),
            reason: 'El formato tiene más especificadores que valores dados');
        final arg = args[i++];
        final conv = m.group(2)!;
        if (conv == 'c') return arg.toString();
        if (conv == 'X') return (arg as int).toRadixString(16).toUpperCase().padLeft(4, '0');
        if (conv == 'x') return (arg as int).toRadixString(16).padLeft(4, '0');
        return arg.toString();
      },
    );
    expect(i, args.length,
        reason: 'Sobran valores: el formato consumió $i de ${args.length}');
    // El firmware termina la línea con \n; el listener ya la entrega sin él.
    return out.replaceAll(r'\n', '').trim();
  }

  test('el printf [PS] del firmware lo parsea la app campo por campo', () {
    // Orden de los argumentos en emitStatus():
    //   slaveList[i], online, replies, timeouts, crcErrors, commands,
    //   lastRttMs, age
    final line = render(formatFor('[PS]'), [0x0201, 1, 412, 3, 2, 7, 18, 31]);

    final m = HardwareHealthMonitor();
    addTearDown(m.dispose);
    m.setUsbConnected(true, deviceName: 'ESP32-C3');
    m.ingestLine(line);

    expect(m.boxes, hasLength(1),
        reason: 'La línea generada desde el firmware no produjo ninguna caja:\n$line');
    final box = m.boxes.single;
    expect(box.id, '0201', reason: 'dev=%04X debe llegar como hex de 4 dígitos');
    expect(box.online, isTrue);
    expect(box.replies, 412);
    expect(box.timeouts, 3);
    expect(box.crcErrors, 2);
    expect(box.commands, 7);
    expect(box.lastRttMs, 18);
    expect(box.ageMs, 31);
  });

  test('el printf [PS] con age=-1 se interpreta como "nunca respondió"', () {
    final line = render(formatFor('[PS]'), [0x0204, 0, 0, 90, 0, 0, 0, -1]);

    final m = HardwareHealthMonitor();
    addTearDown(m.dispose);
    m.setUsbConnected(true);
    m.ingestLine(line);

    expect(m.boxes.single.neverSeen, isTrue);
    expect(m.boxes.single.online, isFalse);
  });

  test('el printf [MS] del firmware lo parsea la app campo por campo', () {
    // Orden en emitStatus():
    //   FW_VERSION, now, cycleToReport, onlineCount, slaveCount, polls,
    //   rxBytes, frames, crcErrors, wrongId, RS485_BAUD, USB_BAUD
    final line = render(formatFor('[MS]'),
        [2, 125340, 82, 3, 4, 2010, 9001, 1200, 5, 0, 9600, 115200]);

    final m = HardwareHealthMonitor();
    addTearDown(m.dispose);
    m.setUsbConnected(true);
    m.ingestLine(line);

    expect(m.master, isNotNull,
        reason: 'La línea [MS] generada desde el firmware no se parseó:\n$line');
    final master = m.master!;
    expect(master.fwVersion, 2);
    expect(master.uptimeMs, 125340);
    expect(master.cycleMs, 82);
    expect(master.onlineCount, 3);
    expect(master.slaveCount, 4);
    expect(master.polls, 2010);
    expect(master.rxBytes, 9001);
    expect(master.frames, 1200);
    expect(master.crcErrors, 5);
    expect(master.wrongId, 0);
    expect(master.rs485Baud, 9600);
    expect(master.usbBaud, 115200);
    expect(m.hasTelemetry, isTrue);
  });

  test('el printf BTN del firmware pasa el regex de validación del listener', () {
    // Es la única línea que puntúa, así que su formato es el más crítico.
    // Este regex es el mismo que usa SimpleUsbSerialListener._handleLine.
    final validator = RegExp(r'^BTN:[0-9A-F]{1,4}:[PUG]$');

    for (final caso in [
      [0x0201, 'P'],
      [0x0202, 'U'],
      [0x0203, 'G'],
      [0x0204, 'P'],
    ]) {
      final line = render(formatFor('BTN:'), [caso[0], caso[1]]);
      expect(
        validator.hasMatch(line.toUpperCase()),
        isTrue,
        reason: 'El firmware emite "$line" pero el listener lo descartaría, '
            'así que esa pulsación no puntuaría nunca',
      );
    }
  });

  test('el comando BTN generado por el firmware resuelve la caja correcta', () {
    final line = render(formatFor('BTN:'), [0x0203, 'U']);

    final m = HardwareHealthMonitor();
    addTearDown(m.dispose);
    m.setUsbConnected(true);
    m.ingestCommand(line.toUpperCase());

    expect(m.buttonsSeenFor('0203'), {'U'},
        reason: 'El ID del comando debe casar con el de las líneas [PS], que '
            'es como la app empareja caja con equipo');
  });

  test('los eventos [EVT] del firmware cambian el estado de la caja', () {
    final src = ino.readAsStringSync();
    // El firmware emite dos variantes; deben distinguirse pese a que
    // "offline" y "online" se parecen.
    expect(src, contains('[EVT] dev=%04X online'));
    expect(src, contains('[EVT] dev=%04X offline'));

    final m = HardwareHealthMonitor();
    addTearDown(m.dispose);
    m.setUsbConnected(true);
    m.ingestLine(render(formatFor('[PS]'), [0x0202, 1, 10, 0, 0, 0, 17, 4]));
    expect(m.boxes.single.online, isTrue);

    m.ingestLine('[EVT] dev=0202 offline');
    expect(m.boxes.single.online, isFalse,
        reason: '"offline" no debe interpretarse como "online"');

    m.ingestLine('[EVT] dev=0202 online');
    expect(m.boxes.single.online, isTrue);
  });

  test('la app exige la versión de firmware que el maestro declara', () {
    final src = ino.readAsStringSync();
    final match =
        RegExp(r'FW_VERSION\s*=\s*(\d+)').firstMatch(src);
    expect(match, isNotNull, reason: 'El firmware debe declarar FW_VERSION');

    final fw = int.parse(match!.group(1)!);
    expect(
      fw,
      greaterThanOrEqualTo(kMinTelemetryFirmware),
      reason: 'El firmware ($fw) es anterior al mínimo que pide la app '
          '($kMinTelemetryFirmware): la app avisaría de "firmware antiguo" '
          'contra su propio firmware actual',
    );
  });

  test('las cajas por defecto de la app son las que polea el maestro', () {
    final src = ino.readAsStringSync();
    final match =
        RegExp(r'slaveList\[\]\s*=\s*\{([^}]*)\}').firstMatch(src);
    expect(match, isNotNull, reason: 'No se encontró slaveList en el firmware');

    final idsFirmware = RegExp(r'0x([0-9A-Fa-f]+)')
        .allMatches(match!.group(1)!)
        .map((m) => m.group(1)!.toLowerCase().padLeft(4, '0'))
        .toList();

    expect(
      idsFirmware,
      kDefaultBoxIds,
      reason: 'El maestro polea $idsFirmware pero la app muestra por defecto '
          '$kDefaultBoxIds. Una caja quedaría fuera del diagnóstico.',
    );
  });
}
