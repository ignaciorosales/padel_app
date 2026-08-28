import 'package:flutter_test/flutter_test.dart';

import 'package:Puntazo/features/usb_serial/hardware_health.dart';

/// Crea un monitor ya "conectado" y lo destruye al acabar el test (si no, el
/// Timer periódico del watchdog deja el test colgado).
HardwareHealthMonitor _monitor({bool connected = true}) {
  final m = HardwareHealthMonitor();
  addTearDown(m.dispose);
  if (connected) m.setUsbConnected(true, deviceName: 'ESP32-C3');
  return m;
}

void main() {
  group('parsing de telemetría', () {
    test('[PS] rellena el estado de una caja', () {
      final m = _monitor();
      m.ingestLine('[PS] dev=0201 on=1 rep=412 to=3 crc=2 cmd=7 rtt=18 age=31');

      final box = m.boxes.single;
      expect(box.id, '0201');
      expect(box.online, isTrue);
      expect(box.replies, 412);
      expect(box.timeouts, 3);
      expect(box.crcErrors, 2);
      expect(box.commands, 7);
      expect(box.lastRttMs, 18);
      expect(box.ageMs, 31);
      expect(box.neverSeen, isFalse);
    });

    test('age=-1 significa que la caja nunca ha respondido', () {
      final m = _monitor();
      m.ingestLine('[PS] dev=0204 on=0 rep=0 to=90 crc=0 cmd=0 rtt=0 age=-1');
      expect(m.boxes.single.neverSeen, isTrue);
      expect(m.boxes.single.online, isFalse);
    });

    test('acepta la línea envuelta por el listener con prefijo ESP32:', () {
      final m = _monitor();
      m.ingestLine('ESP32: [PS] dev=0202 on=1 rep=10 to=0 crc=0 cmd=1 rtt=20 age=5');
      expect(m.boxes.single.id, '0202');
      expect(m.boxes.single.replies, 10);
    });

    test('[MS] rellena el estado del maestro', () {
      final m = _monitor();
      m.ingestLine(
        '[MS] fw=2 up=125340 cyc=34 on=3/4 polls=2010 rxb=9001 frm=1200 '
        'crc=5 wid=1 rs485=9600 usb=115200',
      );

      final master = m.master!;
      expect(master.fwVersion, 2);
      expect(master.uptimeMs, 125340);
      expect(master.cycleMs, 34);
      expect(master.onlineCount, 3);
      expect(master.slaveCount, 4);
      expect(master.crcErrors, 5);
      expect(master.wrongId, 1);
      expect(master.rs485Baud, 9600);
      expect(master.usbBaud, 115200);
      expect(m.hasTelemetry, isTrue);
    });

    test('[EVT] offline marca la caja sin perder sus contadores', () {
      final m = _monitor();
      m.ingestLine('[PS] dev=0203 on=1 rep=50 to=0 crc=0 cmd=2 rtt=17 age=10');
      m.ingestLine('[EVT] dev=0203 offline');

      final box = m.boxes.single;
      expect(box.online, isFalse);
      expect(box.replies, 50, reason: 'los contadores no deben resetearse');
    });

    test('una línea que no es telemetría no marca hasTelemetry', () {
      final m = _monitor();
      m.ingestLine('[INFO] PadelMaster RS485 -> USB');
      expect(m.hasTelemetry, isFalse);
      expect(m.stage, UsbStage.dataNoTelemetry);
    });

    test('lossRatio detecta un enlace intermitente', () {
      final m = _monitor();
      m.ingestLine('[PS] dev=0201 on=1 rep=80 to=20 crc=0 cmd=0 rtt=19 age=4');
      expect(m.boxes.single.lossRatio, closeTo(0.2, 0.001));
    });
  });

  group('etapas de la conexión USB', () {
    test('sin dispositivo', () {
      final m = _monitor(connected: false);
      expect(m.stage, UsbStage.noDevice);
    });

    test('dispositivo visto pero puerto sin abrir', () {
      final m = _monitor(connected: false);
      m.setUsbDevicesFound(1);
      expect(m.stage, UsbStage.deviceNotOpened);
    });

    test('puerto abierto pero sin datos', () {
      final m = _monitor();
      expect(m.stage, UsbStage.openNoData);
    });

    test('operativo con telemetría', () {
      final m = _monitor();
      m.ingestLine('[MS] fw=2 up=1 cyc=30 on=4/4 polls=1 rxb=1 frm=1 crc=0 '
          'wid=0 rs485=9600 usb=115200');
      expect(m.stage, UsbStage.operational);
    });
  });

  group('diagnóstico accionable', () {
    test('sin USB avisa de cable y da instrucciones', () {
      final m = _monitor(connected: false);
      final issues = m.issues();
      expect(issues.first.level, IssueLevel.critical);
      expect(issues.first.title, contains('No se detecta el maestro'));
      expect(issues.first.action, isNotNull);
    });

    test('dispositivo sin abrir apunta al permiso USB', () {
      final m = _monitor(connected: false);
      m.setUsbDevicesFound(1);
      final issue = m.issues().first;
      expect(issue.action, contains('permiso USB'));
    });

    test('firmware antiguo se detecta por ausencia de telemetría', () {
      final m = _monitor();
      m.ingestLine('[READY] Esperando comandos...');
      final titles = m.issues().map((i) => i.title);
      expect(titles, contains('Firmware del maestro antiguo'));
    });

    test('si fallan TODAS las cajas se culpa al bus, no a cada caja', () {
      final m = _monitor();
      m.ingestLine('[MS] fw=2 up=1 cyc=300 on=0/4 polls=1 rxb=1 frm=0 crc=0 '
          'wid=0 rs485=9600 usb=115200');
      for (final id in kDefaultBoxIds) {
        m.ingestLine('[PS] dev=$id on=0 rep=0 to=40 crc=0 cmd=0 rtt=0 age=-1');
      }

      final issues = m.issues();
      final titles = issues.map((i) => i.title).toList();
      expect(titles, contains('Ninguna caja responde'));
      expect(
        titles.where((t) => t.startsWith('Caja')).where((t) => t.contains('no responde')),
        isEmpty,
        reason: 'no debe repetir un aviso por cada una de las 4 cajas',
      );
    });

    test('una sola caja caída genera un aviso concreto de esa caja', () {
      final m = _monitor();
      m.ingestLine('[MS] fw=2 up=1 cyc=100 on=3/4 polls=1 rxb=1 frm=1 crc=0 '
          'wid=0 rs485=9600 usb=115200');
      m.ingestLine('[PS] dev=0201 on=1 rep=50 to=0 crc=0 cmd=0 rtt=18 age=5');
      m.ingestLine('[PS] dev=0202 on=1 rep=50 to=0 crc=0 cmd=0 rtt=18 age=5');
      m.ingestLine('[PS] dev=0203 on=1 rep=50 to=0 crc=0 cmd=0 rtt=18 age=5');
      m.ingestLine('[PS] dev=0204 on=0 rep=0 to=40 crc=0 cmd=0 rtt=0 age=-1');

      final issue = m.issues().firstWhere((i) => i.title.contains('0204'));
      expect(issue.level, IssueLevel.critical);
      expect(issue.action, contains('DEV_ID'));
    });

    test('IDs inesperados sugieren DEV_ID duplicado', () {
      final m = _monitor();
      m.ingestLine('[MS] fw=2 up=1 cyc=30 on=4/4 polls=1 rxb=1 frm=1 crc=0 '
          'wid=12 rs485=9600 usb=115200');
      final issue =
          m.issues().firstWhere((i) => i.title.contains('ID inesperado'));
      expect(issue.action, contains('mismo DEV_ID'));
    });

    test('caja viva pero sin emparejar se avisa como info', () {
      final m = _monitor();
      m.ingestLine('[MS] fw=2 up=1 cyc=30 on=1/1 polls=1 rxb=1 frm=1 crc=0 '
          'wid=0 rs485=9600 usb=115200');
      m.ingestLine('[PS] dev=0201 on=1 rep=50 to=0 crc=0 cmd=0 rtt=18 age=5');

      final sinPareja = m.issues(pairedBoxIds: const {});
      expect(
        sinPareja.map((i) => i.title),
        contains('Caja 0201 sin equipo asignado'),
      );

      final conPareja = m.issues(pairedBoxIds: const {'0201'});
      expect(
        conPareja.map((i) => i.title),
        isNot(contains('Caja 0201 sin equipo asignado')),
      );
    });

    test('los problemas salen ordenados por gravedad', () {
      final m = _monitor();
      m.ingestLine('[MS] fw=2 up=1 cyc=30 on=0/1 polls=1 rxb=1 frm=1 crc=0 '
          'wid=3 rs485=9600 usb=115200');
      m.ingestLine('[PS] dev=0201 on=0 rep=0 to=9 crc=4 cmd=0 rtt=0 age=-1');

      final levels = m.issues().map((i) => i.level.index).toList();
      final ordenados = [...levels]..sort();
      expect(levels, ordenados);
    });
  });

  group('prueba de botones', () {
    test('registra qué teclas han llegado de cada caja', () {
      final m = _monitor();
      m.ingestCommand('BTN:0201:P');
      m.ingestCommand('BTN:0201:U');
      m.ingestCommand('BTN:0203:G');

      expect(m.buttonsSeenFor('0201'), {'P', 'U'});
      expect(m.buttonsSeenFor('0203'), {'G'});
      expect(m.buttonsSeenFor('0204'), isEmpty);
    });

    test('reiniciar la prueba limpia lo registrado', () {
      final m = _monitor();
      m.ingestCommand('BTN:0201:P');
      m.resetButtonTest();
      expect(m.buttonsSeenFor('0201'), isEmpty);
    });

    test('en modo prueba avisa de los botones que faltan por pulsar', () {
      final m = _monitor();
      m.ingestLine('[MS] fw=2 up=1 cyc=30 on=1/1 polls=1 rxb=1 frm=1 crc=0 '
          'wid=0 rs485=9600 usb=115200');
      m.ingestLine('[PS] dev=0201 on=1 rep=50 to=0 crc=0 cmd=1 rtt=18 age=5');
      m.setButtonTestMode(true);
      m.ingestCommand('BTN:0201:P');

      final issue = m
          .issues(pairedBoxIds: const {'0201'})
          .firstWhere((i) => i.title.contains('faltan botones'));
      expect(issue.detail, contains('U'));
      expect(issue.detail, contains('G'));
      expect(issue.detail, isNot(contains('P,')));
    });

    test('un comando mal formado no rompe el registro', () {
      final m = _monitor();
      m.ingestCommand('P_A');
      m.ingestCommand('BTN:solo:dos:partes:mas');
      expect(m.boxes, isEmpty);
    });
  });

  test('al desconectar el USB se olvida el estado del hardware', () {
    final m = _monitor();
    m.ingestLine('[PS] dev=0201 on=1 rep=50 to=0 crc=0 cmd=0 rtt=18 age=5');
    expect(m.boxes, isNotEmpty);

    m.setUsbConnected(false);
    expect(m.boxes, isEmpty);
    expect(m.master, isNull);
    expect(m.masterAlive, isFalse);
  });
}
