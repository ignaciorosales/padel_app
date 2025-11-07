import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Puntazo/config/app_config.dart';

/// Servicio para persistir la selección de equipos del usuario
class TeamSelectionService {
  static const String _keyTeam1 = 'selected_team1_id';
  static const String _keyTeam2 = 'selected_team2_id';
  
  final AppConfig _config;
  final SharedPreferences _prefs;
  
  // Notificadores para cambios en tiempo real
  final ValueNotifier<String> team1Selection;
  final ValueNotifier<String> team2Selection;
  
  TeamSelectionService._(this._config, this._prefs, this.team1Selection, this.team2Selection);
  
  /// Inicializar servicio (debe llamarse al inicio de la app)
  static Future<TeamSelectionService> init(AppConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Leer selecciones guardadas o usar defaults
      final team1Id = prefs.getString(_keyTeam1) ?? _getDefaultTeam1Id(config);
      final team2Id = prefs.getString(_keyTeam2) ?? _getDefaultTeam2Id(config);
      
      return TeamSelectionService._(
        config,
        prefs,
        ValueNotifier(team1Id),
        ValueNotifier(team2Id),
      );
    } catch (e, st) {
      // ▲ CRASH SAFETY: Si falla SharedPreferences, crear servicio con defaults
      print('[TEAM_SERVICE] ⚠️ Error initializing: $e');
      print('[TEAM_SERVICE] Stack trace: $st');
      print('[TEAM_SERVICE] Using in-memory defaults...');
      
      // Crear servicio sin persistencia (solo en memoria)
      final prefs = await SharedPreferences.getInstance();
      return TeamSelectionService._(
        config,
        prefs,
        ValueNotifier(_getDefaultTeam1Id(config)),
        ValueNotifier(_getDefaultTeam2Id(config)),
      );
    }
  }
  
  /// Obtener ID por defecto para equipo 1 (verde si existe, sino el primero)
  static String _getDefaultTeam1Id(AppConfig config) {
    if (config.availableTeams.isEmpty) return 'verde';
    final verde = config.availableTeams.cast<TeamDef?>().firstWhere(
      (t) => t?.id == 'verde',
      orElse: () => null,
    );
    return verde?.id ?? config.availableTeams.first.id;
  }
  
  /// Obtener ID por defecto para equipo 2 (negro si existe, sino el segundo o primero)
  static String _getDefaultTeam2Id(AppConfig config) {
    if (config.availableTeams.isEmpty) return 'negro';
    final negro = config.availableTeams.cast<TeamDef?>().firstWhere(
      (t) => t?.id == 'negro',
      orElse: () => null,
    );
    if (negro != null) return negro.id;
    return config.availableTeams.length > 1 
        ? config.availableTeams[1].id 
        : config.availableTeams.first.id;
  }
  
  /// Obtener equipo seleccionado para posición 1
  TeamDef? getTeam1() {
    return _config.teamById(team1Selection.value);
  }
  
  /// Obtener equipo seleccionado para posición 2
  TeamDef? getTeam2() {
    return _config.teamById(team2Selection.value);
  }
  
  /// Obtener color para posición 1
  Color getColor1() {
    final team = getTeam1();
    if (team != null) return _hex(team.colorHex);
    return const Color(0xFF009900); // Fallback verde
  }
  
  /// Obtener color para posición 2
  Color getColor2() {
    final team = getTeam2();
    if (team != null) return _hex(team.colorHex);
    return const Color(0xFF171717); // Fallback negro
  }
  
  /// Cambiar selección de equipo 1
  Future<void> setTeam1(String teamId) async {
    try {
      if (_config.teamById(teamId) == null) return; // Validar que exista
      team1Selection.value = teamId;
      await _prefs.setString(_keyTeam1, teamId);
    } catch (e) {
      // ▲ CRASH SAFETY: Si falla la persistencia, al menos actualizar en memoria
      print('[TEAM_SERVICE] ⚠️ Error saving team1: $e');
      team1Selection.value = teamId; // Actualizar en memoria aunque falle el guardado
    }
  }
  
  /// Cambiar selección de equipo 2
  Future<void> setTeam2(String teamId) async {
    try {
      if (_config.teamById(teamId) == null) return; // Validar que exista
      team2Selection.value = teamId;
      await _prefs.setString(_keyTeam2, teamId);
    } catch (e) {
      // ▲ CRASH SAFETY: Si falla la persistencia, al menos actualizar en memoria
      print('[TEAM_SERVICE] ⚠️ Error saving team2: $e');
      team2Selection.value = teamId; // Actualizar en memoria aunque falle el guardado
    }
  }
  
  /// Helper para convertir hex a Color
  Color _hex(String hex) {
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16) ?? 0xFF009900;
    return Color(v);
  }
  
  void dispose() {
    team1Selection.dispose();
    team2Selection.dispose();
  }
}
