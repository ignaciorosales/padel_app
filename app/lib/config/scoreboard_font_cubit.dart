import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Presets de tamaño para los números del marcador (solo la pantalla del
/// marcador, no el resto de la app).
enum ScoreboardFontSize {
  small,
  medium,
  large,
  extraLarge,
}

extension ScoreboardFontSizeX on ScoreboardFontSize {
  /// Factor de escala aplicado a los números del marcador (puntos y games).
  /// `medium` es 1.0 para conservar el tamaño actual por defecto.
  double get scale {
    switch (this) {
      case ScoreboardFontSize.small:
        return 0.85;
      case ScoreboardFontSize.medium:
        return 1.0;
      case ScoreboardFontSize.large:
        return 1.15;
      case ScoreboardFontSize.extraLarge:
        return 1.3;
    }
  }

  /// Etiqueta mostrada en Ajustes.
  String get label {
    switch (this) {
      case ScoreboardFontSize.small:
        return 'Pequeño';
      case ScoreboardFontSize.medium:
        return 'Mediano';
      case ScoreboardFontSize.large:
        return 'Grande';
      case ScoreboardFontSize.extraLarge:
        return 'Gigante';
    }
  }
}

/// Cubit que persiste el preset de tamaño de los números del marcador.
/// Sigue el mismo patrón que [ThemeCubit]/[DebugSettingsCubit] con
/// SharedPreferences.
class ScoreboardFontCubit extends Cubit<ScoreboardFontSize> {
  static const String _key = 'scoreboard_font_size';

  final SharedPreferences _prefs;

  ScoreboardFontCubit._(this._prefs, ScoreboardFontSize size) : super(size);

  /// Inicializa leyendo la preferencia guardada (por defecto `medium`).
  static Future<ScoreboardFontCubit> init() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key) ?? ScoreboardFontSize.medium.index;
    final clamped = index.clamp(0, ScoreboardFontSize.values.length - 1);
    return ScoreboardFontCubit._(prefs, ScoreboardFontSize.values[clamped]);
  }

  /// Cambia y persiste el preset seleccionado.
  Future<void> setSize(ScoreboardFontSize size) async {
    if (state != size) {
      await _prefs.setInt(_key, size.index);
      emit(size);
    }
  }
}
