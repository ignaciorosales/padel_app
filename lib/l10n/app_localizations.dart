import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// The application title
  ///
  /// In es, this message translates to:
  /// **'Puntazo'**
  String get appTitle;

  /// Default name for team 1
  ///
  /// In es, this message translates to:
  /// **'Equipo 1'**
  String get team1Default;

  /// Default name for team 2
  ///
  /// In es, this message translates to:
  /// **'Equipo 2'**
  String get team2Default;

  /// Section title for actions
  ///
  /// In es, this message translates to:
  /// **'ACCIONES'**
  String get actionsSection;

  /// Section title for rules
  ///
  /// In es, this message translates to:
  /// **'REGLAS'**
  String get rulesSection;

  /// Undo action label
  ///
  /// In es, this message translates to:
  /// **'Deshacer'**
  String get undo;

  /// Tooltip for undo point button
  ///
  /// In es, this message translates to:
  /// **'Deshacer punto'**
  String get undoPoint;

  /// Redo action label
  ///
  /// In es, this message translates to:
  /// **'Rehacer'**
  String get redo;

  /// Tooltip for redo point button
  ///
  /// In es, this message translates to:
  /// **'Rehacer punto'**
  String get redoPoint;

  /// Serve/service label
  ///
  /// In es, this message translates to:
  /// **'Saque'**
  String get serve;

  /// Tooltip for change server button
  ///
  /// In es, this message translates to:
  /// **'Cambiar servidor'**
  String get changeServer;

  /// Golden point enabled label
  ///
  /// In es, this message translates to:
  /// **'Punto Oro: ON'**
  String get goldenPointOn;

  /// Golden point disabled label
  ///
  /// In es, this message translates to:
  /// **'Punto Oro: OFF'**
  String get goldenPointOff;

  /// Tooltip to change to advantage mode
  ///
  /// In es, this message translates to:
  /// **'Cambiar a Ventaja/Desventaja'**
  String get changeToAdvantage;

  /// Tooltip to change to golden point mode
  ///
  /// In es, this message translates to:
  /// **'Cambiar a Punto de Oro'**
  String get changeToGoldenPoint;

  /// Explanation when golden point is enabled
  ///
  /// In es, this message translates to:
  /// **'En 40-40, un punto decide'**
  String get goldenPointExplanation;

  /// Explanation when advantage mode is enabled
  ///
  /// In es, this message translates to:
  /// **'En 40-40, jugar ventajas'**
  String get advantageExplanation;

  /// Label for super tie-break in third set
  ///
  /// In es, this message translates to:
  /// **'3er Set: Super TB'**
  String get thirdSetSuperTB;

  /// Label for complete third set
  ///
  /// In es, this message translates to:
  /// **'3er Set: Completo'**
  String get thirdSetComplete;

  /// Tooltip to change to complete set
  ///
  /// In es, this message translates to:
  /// **'Cambiar a set completo'**
  String get changeToComplete;

  /// Tooltip to change to super tie-break
  ///
  /// In es, this message translates to:
  /// **'Cambiar a Super TB'**
  String get changeToSuperTB;

  /// Explanation for super tie-break mode
  ///
  /// In es, this message translates to:
  /// **'Tie-break a 10 pts en vez de 3er set'**
  String get superTBExplanation;

  /// Explanation for complete set mode
  ///
  /// In es, this message translates to:
  /// **'Set normal con posible TB en 6-6'**
  String get completeSetExplanation;

  /// Info about tie-break at 6-6
  ///
  /// In es, this message translates to:
  /// **'En 6-6: Tie-break a 7 puntos'**
  String get tieBreakAt66;

  /// New match button label
  ///
  /// In es, this message translates to:
  /// **'Nuevo partido'**
  String get newMatch;

  /// Title for new match confirmation dialog
  ///
  /// In es, this message translates to:
  /// **'Nuevo partido'**
  String get newMatchConfirmTitle;

  /// Message for new match confirmation dialog
  ///
  /// In es, this message translates to:
  /// **'Esto reinicia el marcador. ¿Continuar?'**
  String get newMatchConfirmMessage;

  /// Cancel button label
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// Confirm reset button label
  ///
  /// In es, this message translates to:
  /// **'Sí, reiniciar'**
  String get yesReset;

  /// Advantage label in score
  ///
  /// In es, this message translates to:
  /// **'Ventaja'**
  String get advantage;

  /// Deuce label in score
  ///
  /// In es, this message translates to:
  /// **'Iguales'**
  String get deuce;

  /// Tie-break label
  ///
  /// In es, this message translates to:
  /// **'Tie-Break'**
  String get tieBreak;

  /// Super tie-break label
  ///
  /// In es, this message translates to:
  /// **'Super Tie-Break'**
  String get superTieBreak;

  /// Match point indicator
  ///
  /// In es, this message translates to:
  /// **'Punto de Partido'**
  String get matchPoint;

  /// Set point indicator
  ///
  /// In es, this message translates to:
  /// **'Punto de Set'**
  String get setPoint;

  /// Game point indicator
  ///
  /// In es, this message translates to:
  /// **'Punto de Juego'**
  String get gamePoint;

  /// Break point indicator
  ///
  /// In es, this message translates to:
  /// **'Punto de Break'**
  String get breakPoint;

  /// Set label
  ///
  /// In es, this message translates to:
  /// **'Set'**
  String get set;

  /// Game label
  ///
  /// In es, this message translates to:
  /// **'Juego'**
  String get game;

  /// USB connected status
  ///
  /// In es, this message translates to:
  /// **'USB conectado'**
  String get usbConnected;

  /// USB disconnected status
  ///
  /// In es, this message translates to:
  /// **'USB desconectado'**
  String get usbDisconnected;

  /// Golden point label for display
  ///
  /// In es, this message translates to:
  /// **'Punto de Oro'**
  String get goldenPoint;

  /// Point for team button label
  ///
  /// In es, this message translates to:
  /// **'Punto {teamName}'**
  String pointFor(String teamName);

  /// Serve toggle button label
  ///
  /// In es, this message translates to:
  /// **'Saque (toggle)'**
  String get serveToggle;

  /// Golden point ON chip label
  ///
  /// In es, this message translates to:
  /// **'Oro ON'**
  String get goldOn;

  /// Golden point OFF chip label
  ///
  /// In es, this message translates to:
  /// **'Oro OFF'**
  String get goldOff;

  /// Tie-break at 6-6 segment label
  ///
  /// In es, this message translates to:
  /// **'TB a 6–6'**
  String get tbAt66;

  /// Tie-break at 12-12 segment label
  ///
  /// In es, this message translates to:
  /// **'TB a 12–12'**
  String get tbAt1212;

  /// Default green team name
  ///
  /// In es, this message translates to:
  /// **'Verde'**
  String get green;

  /// Default black team name
  ///
  /// In es, this message translates to:
  /// **'Negro'**
  String get black;

  /// Settings section title
  ///
  /// In es, this message translates to:
  /// **'AJUSTES'**
  String get settings;

  /// Dark theme label
  ///
  /// In es, this message translates to:
  /// **'Tema oscuro'**
  String get darkTheme;

  /// Light theme label
  ///
  /// In es, this message translates to:
  /// **'Tema claro'**
  String get lightTheme;

  /// Toggle theme tooltip
  ///
  /// In es, this message translates to:
  /// **'Cambiar tema'**
  String get toggleTheme;

  /// Teams section title
  ///
  /// In es, this message translates to:
  /// **'EQUIPOS'**
  String get teamsSection;

  /// Select team 1 label
  ///
  /// In es, this message translates to:
  /// **'Equipo 1'**
  String get selectTeam1;

  /// Select team 2 label
  ///
  /// In es, this message translates to:
  /// **'Equipo 2'**
  String get selectTeam2;

  /// Change teams button label
  ///
  /// In es, this message translates to:
  /// **'Cambiar equipos'**
  String get changeTeams;

  /// Select team color dialog title
  ///
  /// In es, this message translates to:
  /// **'Seleccionar color de equipo'**
  String get selectTeamColor;

  /// Team 1 color label
  ///
  /// In es, this message translates to:
  /// **'Color Equipo 1'**
  String get team1Color;

  /// Team 2 color label
  ///
  /// In es, this message translates to:
  /// **'Color Equipo 2'**
  String get team2Color;

  /// Confirm button label
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get confirm;

  /// Settings screen title
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get settingsTitle;

  /// Teams tab label
  ///
  /// In es, this message translates to:
  /// **'Equipos'**
  String get tabTeams;

  /// Rules tab label
  ///
  /// In es, this message translates to:
  /// **'Reglas'**
  String get tabRules;

  /// Display tab label
  ///
  /// In es, this message translates to:
  /// **'Pantalla'**
  String get tabDisplay;

  /// Open settings button tooltip
  ///
  /// In es, this message translates to:
  /// **'Abrir configuración'**
  String get openSettings;

  /// Close button label
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get close;

  /// Select color label
  ///
  /// In es, this message translates to:
  /// **'Seleccionar color'**
  String get selectColor;

  /// Rules section description
  ///
  /// In es, this message translates to:
  /// **'Configura las reglas del partido'**
  String get rulesDescription;

  /// Display section description
  ///
  /// In es, this message translates to:
  /// **'Ajustes de visualización'**
  String get displayDescription;

  /// Theme mode label
  ///
  /// In es, this message translates to:
  /// **'Modo de tema'**
  String get themeMode;

  /// TV remote hint
  ///
  /// In es, this message translates to:
  /// **'Pulsa OK para seleccionar'**
  String get pressToSelect;

  /// Label for selected items in settings
  ///
  /// In es, this message translates to:
  /// **'Seleccionado'**
  String get settingsSelected;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
