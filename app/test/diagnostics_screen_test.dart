import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Puntazo/config/box_pairing_service.dart';
import 'package:Puntazo/features/usb_serial/diagnostics_screen.dart';
import 'package:Puntazo/features/usb_serial/hardware_health.dart';

/// La pantalla de diagnóstico es la herramienta sobre la que se apoya la
/// instalación en pista. Que compile no basta: si revienta al dibujarse (un
/// overflow, un provider que falta, un null) el fallo aparece justo cuando
/// hace falta y no hay forma de depurarlo allí.
///
/// Estos tests la obligan a renderizarse en cada estado por el que va a pasar
/// durante un montaje real, en el tamaño del televisor y en uno pequeño.
void main() {
  late BoxPairingService pairing;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    pairing = await BoxPairingService.init();
  });

  tearDown(() => pairing.dispose());

  // Ojo: el monitor NO se destruye con addTearDown. flutter_test comprueba
  // los timers pendientes al terminar el cuerpo del test, ANTES de ejecutar
  // los tearDown, y el watchdog del monitor es un Timer periódico. Hay que
  // destruirlo dentro del propio test: de eso se encarga render().
  HardwareHealthMonitor monitor() => HardwareHealthMonitor();

  Widget harness(HardwareHealthMonitor m) => MaterialApp(
        home: RepositoryProvider.value(
          value: pairing,
          child: DiagnosticsScreen(monitor: m),
        ),
      );

  /// Dibuja la pantalla a un tamaño concreto y falla si Flutter lanza algo
  /// (los overflow de layout llegan aquí como excepción).
  Future<void> render(
    WidgetTester tester,
    HardwareHealthMonitor m, {
    required Size size,
    Future<void> Function()? luego,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(harness(m));
      // pump() y no pumpAndSettle(): el watchdog del monitor es un Timer
      // periódico, así que el árbol nunca "se asienta".
      await tester.pump();
      expect(tester.takeException(), isNull);
      if (luego != null) await luego();
    } finally {
      m.dispose();
      await tester.pump();
    }
  }

  const tv = Size(1920, 1080);
  const pequeno = Size(1280, 720);

  /// Deja el monitor como estaría con las 4 cajas respondiendo.
  void todoCorrecto(HardwareHealthMonitor m) {
    m.setUsbConnected(true, deviceName: 'ESP32-C3');
    m.ingestLine('[MS] fw=2 up=125340 cyc=82 on=4/4 polls=2010 rxb=9001 '
        'frm=1200 crc=0 wid=0 rs485=9600 usb=115200');
    for (final id in kDefaultBoxIds) {
      m.ingestLine('[PS] dev=$id on=1 rep=412 to=0 crc=0 cmd=3 rtt=18 age=31');
    }
  }

  group('se dibuja sin reventar', () {
    testWidgets('sin nada conectado', (tester) async {
      await render(tester, monitor(), size: tv);
      expect(find.text('DIAGNÓSTICO DEL SISTEMA'), findsOneWidget);
      expect(find.textContaining('No se detecta el maestro'), findsWidgets);
    });

    testWidgets('dispositivo visto pero sin abrir el puerto', (tester) async {
      final m = monitor()..setUsbDevicesFound(1);
      await render(tester, m, size: tv);
      expect(find.textContaining('permiso USB'), findsWidgets);
    });

    testWidgets('conectado pero el maestro no dice nada', (tester) async {
      final m = monitor()..setUsbConnected(true, deviceName: 'ESP32-C3');
      await render(tester, m, size: tv);
      expect(find.textContaining('no envía nada'), findsWidgets);
    });

    testWidgets('firmware antiguo del maestro', (tester) async {
      final m = monitor()..setUsbConnected(true);
      m.ingestLine('[READY] Esperando comandos...');
      await render(tester, m, size: tv);
      expect(find.textContaining('Firmware del maestro antiguo'), findsWidgets);
    });

    testWidgets('todo correcto, 4 de 4 cajas', (tester) async {
      final m = monitor();
      todoCorrecto(m);
      await render(tester, m, size: tv);
      expect(find.text('4 de 4 cajas conectadas'), findsOneWidget);
      expect(find.textContaining('Todo correcto'), findsOneWidget);
      for (final id in kDefaultBoxIds) {
        expect(find.text(id.toUpperCase()), findsOneWidget);
      }
    });

    testWidgets('una caja caída', (tester) async {
      final m = monitor();
      m.setUsbConnected(true);
      m.ingestLine('[MS] fw=2 up=1 cyc=140 on=3/4 polls=1 rxb=1 frm=1 crc=0 '
          'wid=0 rs485=9600 usb=115200');
      for (final id in ['0201', '0202', '0203']) {
        m.ingestLine('[PS] dev=$id on=1 rep=50 to=0 crc=0 cmd=0 rtt=18 age=5');
      }
      m.ingestLine('[PS] dev=0204 on=0 rep=0 to=40 crc=0 cmd=0 rtt=0 age=-1');

      await render(tester, m, size: tv);
      expect(find.textContaining('Caja 0204 no responde'), findsWidgets);
      expect(find.text('NUNCA VISTA'), findsOneWidget);
    });

    testWidgets('el bus entero caído', (tester) async {
      final m = monitor();
      m.setUsbConnected(true);
      m.ingestLine('[MS] fw=2 up=1 cyc=300 on=0/4 polls=1 rxb=0 frm=0 crc=0 '
          'wid=0 rs485=9600 usb=115200');
      for (final id in kDefaultBoxIds) {
        m.ingestLine('[PS] dev=$id on=0 rep=0 to=40 crc=0 cmd=0 rtt=0 age=-1');
      }
      await render(tester, m, size: tv);
      expect(find.textContaining('Ninguna caja responde'), findsWidgets);
    });

    testWidgets('muchos problemas a la vez no rompen el layout', (tester) async {
      // El peor caso para el alto de la columna de incidencias.
      final m = monitor();
      m.setUsbConnected(true);
      m.ingestLine('[MS] fw=2 up=1 cyc=400 on=1/4 polls=1 rxb=1 frm=1 crc=9 '
          'wid=4 rs485=9600 usb=115200');
      m.ingestLine('[PS] dev=0201 on=1 rep=30 to=20 crc=9 cmd=0 rtt=55 age=9');
      m.ingestLine('[PS] dev=0202 on=0 rep=0 to=40 crc=0 cmd=0 rtt=0 age=-1');
      m.ingestLine('[PS] dev=0203 on=0 rep=5 to=40 crc=3 cmd=0 rtt=0 age=900');
      m.ingestLine('[PS] dev=0204 on=0 rep=0 to=40 crc=0 cmd=0 rtt=0 age=-1');
      m.setButtonTestMode(true);
      await render(tester, m, size: tv);
    });

    testWidgets('modo prueba con las casillas de botones', (tester) async {
      final m = monitor();
      todoCorrecto(m);
      m.setButtonTestMode(true);
      m.ingestCommand('BTN:0201:P');
      await render(tester, m, size: tv);
      expect(find.textContaining('MODO PRUEBA ACTIVO'), findsOneWidget);
      // Tres casillas P/U/G por cada una de las 4 cajas.
      expect(find.text('P'), findsNWidgets(4));
      expect(find.text('U'), findsNWidgets(4));
      expect(find.text('G'), findsNWidgets(4));
    });

    testWidgets('con líneas en el log del puerto', (tester) async {
      final m = monitor();
      todoCorrecto(m);
      for (var i = 0; i < 60; i++) {
        m.ingestLine('[INFO] linea de relleno numero $i para llenar el log');
      }
      await render(tester, m, size: tv);
    });
  });

  group('aguanta pantallas más pequeñas', () {
    testWidgets('720p con todo correcto', (tester) async {
      final m = monitor();
      todoCorrecto(m);
      await render(tester, m, size: pequeno);
    });

    testWidgets('720p con el peor caso de incidencias', (tester) async {
      final m = monitor();
      m.setUsbConnected(true);
      m.ingestLine('[MS] fw=2 up=1 cyc=400 on=0/4 polls=1 rxb=1 frm=1 crc=9 '
          'wid=4 rs485=9600 usb=115200');
      for (final id in kDefaultBoxIds) {
        m.ingestLine('[PS] dev=$id on=0 rep=0 to=40 crc=2 cmd=0 rtt=0 age=-1');
      }
      await render(tester, m, size: pequeno);
    });
  });

  group('los controles responden', () {
    testWidgets('el botón de prueba de botones cambia de estado',
        (tester) async {
      final m = monitor();
      todoCorrecto(m);
      await render(tester, m, size: tv, luego: () async {
        expect(m.buttonTestMode, isFalse);
        await tester.tap(find.text('Probar botones'));
        await tester.pump();
        expect(m.buttonTestMode, isTrue);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Salir de prueba'));
        await tester.pump();
        expect(m.buttonTestMode, isFalse);
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('«Actualizar» pide el estado al maestro', (tester) async {
      final enviados = <String>[];
      final m = HardwareHealthMonitor(
        onSend: (line) async => enviados.add(line),
      );
      todoCorrecto(m);
      await render(tester, m, size: tv, luego: () async {
        await tester.tap(find.text('Actualizar'));
        await tester.pump();
        expect(enviados, ['STATUS'],
            reason: 'debe enviar STATUS por el puerto serie al maestro');
      });
    });

    testWidgets('reiniciar la prueba limpia las casillas', (tester) async {
      final m = monitor();
      todoCorrecto(m);
      m.setButtonTestMode(true);
      m.ingestCommand('BTN:0201:P');
      await render(tester, m, size: tv, luego: () async {
        expect(m.buttonsSeenFor('0201'), {'P'});
        await tester.tap(find.text('Reiniciar prueba'));
        await tester.pump();
        expect(m.buttonsSeenFor('0201'), isEmpty);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
