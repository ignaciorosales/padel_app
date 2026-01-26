// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Puntazo';

  @override
  String get team1Default => 'Equipo 1';

  @override
  String get team2Default => 'Equipo 2';

  @override
  String get actionsSection => 'ACCIONES';

  @override
  String get rulesSection => 'REGLAS';

  @override
  String get undo => 'Deshacer';

  @override
  String get undoPoint => 'Deshacer punto';

  @override
  String get redo => 'Rehacer';

  @override
  String get redoPoint => 'Rehacer punto';

  @override
  String get serve => 'Saque';

  @override
  String get changeServer => 'Cambiar servidor';

  @override
  String get goldenPointOn => 'Punto Oro: ON';

  @override
  String get goldenPointOff => 'Punto Oro: OFF';

  @override
  String get changeToAdvantage => 'Cambiar a Ventaja/Desventaja';

  @override
  String get changeToGoldenPoint => 'Cambiar a Punto de Oro';

  @override
  String get goldenPointExplanation => 'En 40-40, un punto decide';

  @override
  String get advantageExplanation => 'En 40-40, jugar ventajas';

  @override
  String get thirdSetSuperTB => '3er Set: Super TB';

  @override
  String get thirdSetComplete => '3er Set: Completo';

  @override
  String get changeToComplete => 'Cambiar a set completo';

  @override
  String get changeToSuperTB => 'Cambiar a Super TB';

  @override
  String get superTBExplanation => 'Tie-break a 10 pts en vez de 3er set';

  @override
  String get completeSetExplanation => 'Set normal con posible TB en 6-6';

  @override
  String get tieBreakAt66 => 'En 6-6: Tie-break a 7 puntos';

  @override
  String get newMatch => 'Nuevo partido';

  @override
  String get newMatchConfirmTitle => 'Nuevo partido';

  @override
  String get newMatchConfirmMessage => 'Esto reinicia el marcador. ¿Continuar?';

  @override
  String get cancel => 'Cancelar';

  @override
  String get yesReset => 'Sí, reiniciar';

  @override
  String get advantage => 'Ventaja';

  @override
  String get deuce => 'Iguales';

  @override
  String get tieBreak => 'Tie-Break';

  @override
  String get superTieBreak => 'Super Tie-Break';

  @override
  String get matchPoint => 'Punto de Partido';

  @override
  String get setPoint => 'Punto de Set';

  @override
  String get gamePoint => 'Punto de Juego';

  @override
  String get breakPoint => 'Punto de Break';

  @override
  String get set => 'Set';

  @override
  String get game => 'Juego';

  @override
  String get usbConnected => 'USB conectado';

  @override
  String get usbDisconnected => 'USB desconectado';

  @override
  String get goldenPoint => 'Punto de Oro';

  @override
  String pointFor(String teamName) {
    return 'Punto $teamName';
  }

  @override
  String get serveToggle => 'Saque (toggle)';

  @override
  String get goldOn => 'Oro ON';

  @override
  String get goldOff => 'Oro OFF';

  @override
  String get tbAt66 => 'TB a 6–6';

  @override
  String get tbAt1212 => 'TB a 12–12';

  @override
  String get green => 'Verde';

  @override
  String get black => 'Negro';

  @override
  String get settings => 'AJUSTES';

  @override
  String get darkTheme => 'Tema oscuro';

  @override
  String get lightTheme => 'Tema claro';

  @override
  String get toggleTheme => 'Cambiar tema';

  @override
  String get teamsSection => 'EQUIPOS';

  @override
  String get selectTeam1 => 'Equipo 1';

  @override
  String get selectTeam2 => 'Equipo 2';

  @override
  String get changeTeams => 'Cambiar equipos';

  @override
  String get selectTeamColor => 'Seleccionar color de equipo';

  @override
  String get team1Color => 'Color Equipo 1';

  @override
  String get team2Color => 'Color Equipo 2';

  @override
  String get confirm => 'Confirmar';

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get tabTeams => 'Equipos';

  @override
  String get tabRules => 'Reglas';

  @override
  String get tabDisplay => 'Pantalla';

  @override
  String get openSettings => 'Abrir configuración';

  @override
  String get close => 'Cerrar';

  @override
  String get selectColor => 'Seleccionar color';

  @override
  String get rulesDescription => 'Configura las reglas del partido';

  @override
  String get displayDescription => 'Ajustes de visualización';

  @override
  String get themeMode => 'Modo de tema';

  @override
  String get pressToSelect => 'Pulsa OK para seleccionar';

  @override
  String get settingsSelected => 'Seleccionado';
}
