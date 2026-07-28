import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cubit que gestiona preferencias de depuración/testing persistidas.
///
/// De momento controla la visibilidad del botón de depuración (el que abre
/// el overlay de testing para simular la botonera). Sigue el mismo patrón que
/// [ThemeCubit] usando SharedPreferences.
class DebugSettingsCubit extends Cubit<bool> {
  static const String _showDebugButtonKey = 'show_debug_button';

  final SharedPreferences _prefs;

  DebugSettingsCubit._(this._prefs, bool showDebugButton)
      : super(showDebugButton);

  /// Inicializa el cubit leyendo la preferencia guardada.
  /// Por defecto el botón de depuración está visible para no alterar el
  /// comportamiento actual.
  static Future<DebugSettingsCubit> init() async {
    final prefs = await SharedPreferences.getInstance();
    final show = prefs.getBool(_showDebugButtonKey) ?? true;
    return DebugSettingsCubit._(prefs, show);
  }

  /// Si el botón de depuración debe mostrarse.
  bool get showDebugButton => state;

  /// Activa o desactiva la visibilidad del botón de depuración.
  Future<void> setShowDebugButton(bool value) async {
    if (state != value) {
      await _prefs.setBool(_showDebugButtonKey, value);
      emit(value);
    }
  }

  /// Alterna la visibilidad del botón de depuración.
  Future<void> toggle() => setShowDebugButton(!state);
}
