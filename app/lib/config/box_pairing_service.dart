import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';


/// Empareja cada caja física (identificada por su ID de hardware) con un
/// LADO de la pista.
///
/// Las cajas están fijas en la pista y los jugadores cambian de lado al
/// terminar cada set, así que una caja no pertenece a un equipo: pertenece a
/// un lado, y el equipo que puntúa es el que juega en ese lado en ese momento
/// (lo resuelve [HardwareCommandHandler] con el `isSwapped` del marcador).
///
/// El maestro reenvía `BTN:<idHex>:<P|U|G>` y esta clase dice en qué lado está
/// cada caja. Se configura una vez con el asistente ([startSetup]) o a mano en
/// Ajustes ▸ Mandos, y se recuerda de forma persistente.
///
/// Valor guardado por caja:
///  - 1 => [left], el lado que la pantalla muestra a la izquierda
///  - 2 => [right]
///  - 0 => [unassigned], caja conocida pero sin lado (ver [unassignBox])
///
/// Los valores 1/2 son los mismos que se guardaban cuando se emparejaba por
/// equipo: el Equipo 1 se muestra a la izquierda al empezar, así que un
/// emparejamiento antiguo sigue significando lo mismo.
class BoxPairingService {
  static const String _key = 'box_team_pairings';

  static const int left = 1;
  static const int right = 2;

  /// Caja conocida pero sin lado. Los IDs de las cajas son fijos (los define
  /// su firmware), así que quitarle el lado no la borra de la lista.
  static const int unassigned = 0;

  /// Cajas que espera el asistente en cada lado.
  static const int boxesPerSide = 2;

  final SharedPreferences _prefs;

  /// Mapa `idCaja (hex minúsculas) -> lado (1|2, o 0 sin lado)`.
  final ValueNotifier<Map<String, int>> pairings;

  /// IDs de cajas de las que llegó al menos un comando pero todavía NO están
  /// emparejadas. Se acumulan TODAS las que van apareciendo (más reciente
  /// primero) — una caja nunca tapa el aviso de otra. La UI de Ajustes las
  /// usa para ofrecer asignarlas sin teclear el ID.
  final ValueNotifier<List<String>> unpairedBoxes =
      ValueNotifier<List<String>>(const []);

  /// Asistente de configuración en curso, o `null` si no hay ninguno.
  final ValueNotifier<BoxSetup?> setup = ValueNotifier<BoxSetup?>(null);

  /// Se llama al guardar el asistente con la línea [keepCommand] para el
  /// maestro, que así olvida las cajas que no se pulsaron. Lo conecta quien
  /// tiene el USB, para no acoplar esta clase al transporte.
  void Function(String line)? onSetupSaved;

  /// `KEEP <id> <id>…`: el maestro se queda solo con esas cajas.
  static String keepCommand(Iterable<String> ids) =>
      ['KEEP', ...ids.map((id) => id.toUpperCase())].join(' ');

  BoxPairingService._(this._prefs, Map<String, int> initial)
      : pairings = ValueNotifier<Map<String, int>>(initial);

  /// Inicializa el servicio leyendo el emparejamiento guardado.
  ///
  /// Sin nada guardado arranca VACÍO, sin IDs por defecto: así la app sabe
  /// que nadie ha configurado las cajas y abre el asistente.
  static Future<BoxPairingService> init() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_key);
      if (raw == null) return BoxPairingService._(prefs, {});
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return BoxPairingService._(
        prefs,
        decoded.map((k, v) => MapEntry(_norm(k), (v as num).toInt())),
      );
    } catch (_) {
      // CRASH SAFETY: un valor guardado corrupto equivale a no tener nada;
      // el asistente vuelve a aparecer.
      return BoxPairingService._(prefs, {});
    }
  }

  /// Hay al menos una caja con lado asignado.
  bool get hasPairedBoxes => pairings.value.values.any((v) => v != unassigned);

  /// Lado de la caja ([left] o [right]), o `null` si no está emparejada
  /// (incluye una caja conocida pero marcada como [unassigned]).
  int? sideForBox(String boxId) {
    final side = pairings.value[_norm(boxId)];
    if (side == null || side == unassigned) return null;
    return side;
  }

  /// Asigna (o reasigna) una caja a un lado ([left]|[right]) y lo persiste.
  Future<void> setPairing(String boxId, int side) async {
    if (side != left && side != right) return;
    final id = _norm(boxId);
    final next = Map<String, int>.of(pairings.value)..[id] = side;
    pairings.value = next;
    _removeFromUnpaired(id);
    await _persist();
  }

  /// Quita el lado de una caja SIN quitarla de la lista: los IDs de
  /// las cajas son fijos, así que la caja sigue siendo visible en Ajustes
  /// (como "Sin lado") en vez de desaparecer y depender de que vuelva a
  /// llegar un comando en vivo para poder reasignarla.
  Future<void> unassignBox(String boxId) async {
    final id = _norm(boxId);
    final next = Map<String, int>.of(pairings.value)..[id] = unassigned;
    pairings.value = next;
    _removeFromUnpaired(id);
    await _persist();
  }

  /// Elimina una caja de la lista por completo (p. ej. si se rompe y se
  /// sustituye por otra con distinto ID). A diferencia de [unassignBox],
  /// esta sí hace que la caja desaparezca hasta que vuelva a detectarse.
  Future<void> removeBox(String boxId) async {
    final id = _norm(boxId);
    if (!pairings.value.containsKey(id)) return;
    final next = Map<String, int>.of(pairings.value)..remove(id);
    pairings.value = next;
    await _persist();
  }

  /// Registra una caja vista sin emparejar para poder asignarla desde
  /// Ajustes. Se acumula junto a las demás pendientes (no reemplaza).
  void reportUnpairedBox(String boxId) {
    final id = _norm(boxId);
    if (pairings.value.containsKey(id)) return;
    if (unpairedBoxes.value.contains(id)) return;
    unpairedBoxes.value = [id, ...unpairedBoxes.value];
  }

  /// Descarta una caja no emparejada pendiente puntual (p. ej. tras cerrar
  /// su aviso), sin afectar a las demás que sigan pendientes.
  void clearUnpairedBox(String boxId) => _removeFromUnpaired(_norm(boxId));

  void _removeFromUnpaired(String normalizedId) {
    if (!unpairedBoxes.value.contains(normalizedId)) return;
    unpairedBoxes.value =
        unpairedBoxes.value.where((e) => e != normalizedId).toList();
  }

  // ---- Asistente ---------------------------------------------------------

  /// Empieza el asistente "pulsa un botón de cada caja". Mientras está
  /// abierto, las pulsaciones de las cajas NO puntúan: van a [setupPress].
  ///
  /// Si ya hay cajas configuradas, empieza pidiendo confirmación
  /// ([BoxSetup.confirming]): terminar el asistente sustituye esa
  /// configuración. Sin cajas no hay nada que perder y empieza directamente.
  void startSetup() => setup.value = BoxSetup(
        side: hasPairedBoxes ? BoxSetup.confirmStep : left,
        captured: const {},
      );

  /// Confirma que se quiere rehacer la configuración y empieza por la
  /// izquierda.
  void confirmSetup() {
    if (setup.value?.confirming != true) return;
    setup.value = const BoxSetup(side: left, captured: {});
  }

  /// Registra la caja pulsada en el lado que se está configurando. Al
  /// completar [boxesPerSide] cajas pasa solo al lado siguiente.
  void setupPress(String boxId) {
    final s = setup.value;
    // Durante la confirmación una pulsación no cuenta: aún no se ha aceptado.
    if (s == null || s.done || s.confirming) return;
    final id = _norm(boxId);
    if (s.captured.containsKey(id)) {
      // Misma caja pulsada otra vez: no avanza, solo avisa.
      setup.value = BoxSetup(side: s.side, captured: s.captured, repeated: id);
      return;
    }
    final captured = {...s.captured, id: s.side};
    setup.value = BoxSetup(side: s.side, captured: captured);
    if (captured.values.where((v) => v == s.side).length >= boxesPerSide) {
      nextSetupSide();
    }
  }

  /// Pasa al lado siguiente (también para un lado con menos cajas). Tras el
  /// último lado guarda el resultado, que SUSTITUYE al emparejamiento
  /// anterior: una caja retirada no se queda puntuando por error.
  Future<void> nextSetupSide() async {
    final s = setup.value;
    if (s == null || s.done || s.confirming) return;
    final next = BoxSetup(side: s.side + 1, captured: s.captured);
    setup.value = next;
    if (next.done) {
      pairings.value = Map<String, int>.of(next.captured);
      unpairedBoxes.value = const [];
      onSetupSaved?.call(keepCommand(next.captured.keys));
      await _persist();
    }
  }

  /// Cierra el asistente. Si no había terminado, no cambia nada.
  void closeSetup() => setup.value = null;

  Future<void> _persist() async {
    try {
      await _prefs.setString(_key, jsonEncode(pairings.value));
    } catch (_) {
      // Si falla la persistencia, el cambio queda al menos en memoria.
    }
  }

  static String _norm(String id) => id.trim().toLowerCase();

  void dispose() {
    pairings.dispose();
    unpairedBoxes.dispose();
    setup.dispose();
  }
}

/// Estado del asistente de configuración de cajas.
@immutable
class BoxSetup {
  const BoxSetup({required this.side, required this.captured, this.repeated});

  /// Valor de [side] mientras se pide confirmación para rehacer la
  /// configuración.
  static const int confirmStep = 0;

  /// Lado que se está configurando; [confirmStep] antes de empezar, y pasado
  /// [BoxPairingService.right] es que ya terminó.
  final int side;

  /// Cajas registradas en este asistente: `id -> lado`.
  final Map<String, int> captured;

  /// Caja que se acaba de pulsar por segunda vez, para avisar.
  final String? repeated;

  bool get confirming => side == confirmStep;

  bool get done => side > BoxPairingService.right;

  int countOn(int side) => captured.values.where((v) => v == side).length;
}
