import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cubit to manage theme preferences using BLoC pattern
class ThemeCubit extends Cubit<ThemeMode> {
  static const String _themeModeKey = 'theme_mode';
  
  final SharedPreferences _prefs;

  ThemeCubit._(this._prefs, ThemeMode initialMode) : super(initialMode);

  /// Initialize the theme cubit
  static Future<ThemeCubit> init() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(_themeModeKey) ?? 2; // Default to dark
    final themeMode = ThemeMode.values[themeModeIndex.clamp(0, ThemeMode.values.length - 1)];
    return ThemeCubit._(prefs, themeMode);
  }

  /// Current theme mode (alias for state)
  ThemeMode get themeMode => state;

  /// Whether dark mode is enabled
  bool get isDarkMode => state == ThemeMode.dark;

  /// Whether the theme follows system
  bool get isSystemTheme => state == ThemeMode.system;

  /// Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    if (state != mode) {
      await _prefs.setInt(_themeModeKey, mode.index);
      emit(mode);
    }
  }

  /// Toggle between light and dark mode
  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }

  /// Cycle through theme modes (light -> dark -> system -> light)
  Future<void> cycleThemeMode() async {
    final nextIndex = (state.index + 1) % ThemeMode.values.length;
    await setThemeMode(ThemeMode.values[nextIndex]);
  }
}
