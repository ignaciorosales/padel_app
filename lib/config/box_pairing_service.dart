import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Puntazo/features/models/scoring_models.dart';

/// Empareja cada caja/mando físico (identificado por su ID de hardware) con
/// un equipo del partido.
///
/// El hardware ya no decide el equipo: el master reenvía `BTN:<idHex>:<P|U|G>`
/// y esta clase resuelve a qué equipo pertenece cada caja. El emparejamiento
/// se hace una sola vez (Ajustes > Mandos) y se recuerda de forma persistente
/// hasta que el usuario lo cambie o elimine una caja.
///
/// `teamIndex`:
///  - 1 => Equipo 1 ([Team.blue])
///  - 2 => Equipo 2 ([Team.red])
class BoxPairingService {
  static const String _key = 'box_team_pairings';

  /// Emparejamiento por defecto (compatible con el reparto histórico:
  /// 0201/0202 → Equipo 1, 0203/0204 → Equipo 2).
  static const Map<String, int> _defaults = {
    '0201': 1,
    '0202': 1,
    '0203': 2,
    '0204': 2,
  };

  final SharedPreferences _prefs;

  /// Mapa `idCaja (hex minúsculas) -> teamIndex (1|2)`.
  final ValueNotifier<Map<String, int>> pairings;

  /// Última caja detectada que NO está emparejada todavía. La UI de Ajustes
  /// la usa para ofrecer asignarla a un equipo sin teclear el ID a mano.
  final ValueNotifier<String?> lastUnpairedBox = ValueNotifier<String?>(null);

  BoxPairingService._(this._prefs, Map<String, int> initial)
      : pairings = ValueNotifier<Map<String, int>>(initial);

  /// Inicializa el servicio leyendo el emparejamiento guardado.
  static Future<BoxPairingService> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      Map<String, int> map;
      if (raw == null) {
        map = Map<String, int>.of(_defaults);
      } else {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        map = decoded.map(
          (k, v) => MapEntry(_norm(k), (v as num).toInt()),
        );
      }
      return BoxPairingService._(prefs, map);
    } catch (_) {
      // CRASH SAFETY: si falla la lectura, arrancar con los valores por
      // defecto (solo en memoria si SharedPreferences fallara del todo).
      final prefs = await SharedPreferences.getInstance();
      return BoxPairingService._(prefs, Map<String, int>.of(_defaults));
    }
  }

  /// Equipo emparejado con la caja, o `null` si no está emparejada.
  Team? teamForBox(String boxId) {
    final idx = pairings.value[_norm(boxId)];
    if (idx == null) return null;
    return idx == 1 ? Team.blue : Team.red;
  }

  /// Índice de equipo (1|2) emparejado con la caja, o `null`.
  int? teamIndexForBox(String boxId) => pairings.value[_norm(boxId)];

  /// Asigna (o reasigna) una caja a un equipo (1|2) y lo persiste.
  Future<void> setPairing(String boxId, int teamIndex) async {
    if (teamIndex != 1 && teamIndex != 2) return;
    final id = _norm(boxId);
    final next = Map<String, int>.of(pairings.value)..[id] = teamIndex;
    pairings.value = next;
    if (lastUnpairedBox.value == id) {
      lastUnpairedBox.value = null;
    }
    await _persist();
  }

  /// Elimina una caja del emparejamiento (p. ej. si se rompe y se sustituye).
  Future<void> removeBox(String boxId) async {
    final id = _norm(boxId);
    if (!pairings.value.containsKey(id)) return;
    final next = Map<String, int>.of(pairings.value)..remove(id);
    pairings.value = next;
    await _persist();
  }

  /// Registra una caja vista sin emparejar para poder asignarla desde Ajustes.
  void reportUnpairedBox(String boxId) {
    final id = _norm(boxId);
    if (pairings.value.containsKey(id)) return;
    if (lastUnpairedBox.value != id) {
      lastUnpairedBox.value = id;
    }
  }

  /// Descarta la caja no emparejada pendiente (p. ej. tras cerrar el aviso).
  void clearUnpairedBox() {
    if (lastUnpairedBox.value != null) {
      lastUnpairedBox.value = null;
    }
  }

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
    lastUnpairedBox.dispose();
  }
}
