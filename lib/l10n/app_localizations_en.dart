// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Puntazo';

  @override
  String get team1Default => 'Team 1';

  @override
  String get team2Default => 'Team 2';

  @override
  String get actionsSection => 'ACTIONS';

  @override
  String get rulesSection => 'RULES';

  @override
  String get undo => 'Undo';

  @override
  String get undoPoint => 'Undo point';

  @override
  String get redo => 'Redo';

  @override
  String get redoPoint => 'Redo point';

  @override
  String get serve => 'Serve';

  @override
  String get changeServer => 'Change server';

  @override
  String get goldenPointOn => 'Golden Point: ON';

  @override
  String get goldenPointOff => 'Golden Point: OFF';

  @override
  String get changeToAdvantage => 'Change to Advantage mode';

  @override
  String get changeToGoldenPoint => 'Change to Golden Point';

  @override
  String get goldenPointExplanation => 'At 40-40, one point decides';

  @override
  String get advantageExplanation => 'At 40-40, play advantages';

  @override
  String get thirdSetSuperTB => '3rd Set: Super TB';

  @override
  String get thirdSetComplete => '3rd Set: Complete';

  @override
  String get changeToComplete => 'Change to complete set';

  @override
  String get changeToSuperTB => 'Change to Super TB';

  @override
  String get superTBExplanation => '10-point tie-break instead of 3rd set';

  @override
  String get completeSetExplanation => 'Normal set with possible TB at 6-6';

  @override
  String get tieBreakAt66 => 'At 6-6: 7-point tie-break';

  @override
  String get newMatch => 'New match';

  @override
  String get newMatchConfirmTitle => 'New match';

  @override
  String get newMatchConfirmMessage => 'This will reset the score. Continue?';

  @override
  String get cancel => 'Cancel';

  @override
  String get yesReset => 'Yes, reset';

  @override
  String get advantage => 'Advantage';

  @override
  String get deuce => 'Deuce';

  @override
  String get tieBreak => 'Tie-Break';

  @override
  String get superTieBreak => 'Super Tie-Break';

  @override
  String get matchPoint => 'Match Point';

  @override
  String get setPoint => 'Set Point';

  @override
  String get gamePoint => 'Game Point';

  @override
  String get breakPoint => 'Break Point';

  @override
  String get set => 'Set';

  @override
  String get game => 'Game';

  @override
  String get usbConnected => 'USB connected';

  @override
  String get usbDisconnected => 'USB disconnected';

  @override
  String get goldenPoint => 'Golden Point';

  @override
  String pointFor(String teamName) {
    return 'Point $teamName';
  }

  @override
  String get serveToggle => 'Serve (toggle)';

  @override
  String get goldOn => 'Gold ON';

  @override
  String get goldOff => 'Gold OFF';

  @override
  String get tbAt66 => 'TB at 6–6';

  @override
  String get tbAt1212 => 'TB at 12–12';

  @override
  String get green => 'Green';

  @override
  String get black => 'Black';

  @override
  String get settings => 'SETTINGS';

  @override
  String get darkTheme => 'Dark theme';

  @override
  String get lightTheme => 'Light theme';

  @override
  String get toggleTheme => 'Toggle theme';

  @override
  String get teamsSection => 'TEAMS';

  @override
  String get selectTeam1 => 'Team 1';

  @override
  String get selectTeam2 => 'Team 2';

  @override
  String get changeTeams => 'Change teams';

  @override
  String get selectTeamColor => 'Select team color';

  @override
  String get team1Color => 'Team 1 Color';

  @override
  String get team2Color => 'Team 2 Color';

  @override
  String get confirm => 'Confirm';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get tabTeams => 'Teams';

  @override
  String get tabRules => 'Rules';

  @override
  String get tabDisplay => 'Display';

  @override
  String get openSettings => 'Open settings';

  @override
  String get close => 'Close';

  @override
  String get selectColor => 'Select color';

  @override
  String get rulesDescription => 'Configure match rules';

  @override
  String get displayDescription => 'Display settings';

  @override
  String get themeMode => 'Theme mode';

  @override
  String get showDebugButton => 'Show debug button';

  @override
  String get showDebugButtonHint =>
      'Shows the button that opens the testing panel to simulate the button box';

  @override
  String get pressToSelect => 'Press OK to select';

  @override
  String get settingsSelected => 'Selected';
}
