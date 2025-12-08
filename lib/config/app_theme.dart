import 'package:flutter/material.dart';

/// Colores personalizados para la app de pádel
class PadelColors {
  // Colores de equipos
  static const blueTeamLight = Color(0xFF4E95FF);
  static const blueTeamDark = Color(0xFF0D2A4D);
  static const redTeamLight = Color(0xFFFC4242);
  static const redTeamDark = Color(0xFF912430);
  
  // Colores de fondo del scoreboard
  static const blueGradientStart = Color(0xFF4E95FF);
  static const blueGradientEnd = Color(0xFF0D2A4D);
  static const redGradientStart = Color(0xFFFC4242);
  static const redGradientEnd = Color(0xFF912430);
  
  // Colores de acento
  static const gold = Color(0xFFFFC107);
  static const orange = Color(0xFFFF9800);
  static const purple = Color(0xFFAB47BC);
  static const amber = Color(0xFFFFB300);
  
  // Estados especiales
  static const tieBreakColor = Color(0xFFFF6E40);
  static const deuceColor = Color(0xFFAB47BC);
  static const goldenPointColor = Color(0xFFFFB300);
  static const winnerColor = Color(0xFFFFC107);
}

/// Tema personalizado para la app de pádel
class PadelTheme {
  // Tema claro con colores personalizables SOLO para equipos (no para UI general)
  static ThemeData lightTheme({Color? team1Color, Color? team2Color}) {
    final t1Color = team1Color ?? PadelColors.blueTeamLight;
    final t2Color = team2Color ?? PadelColors.redTeamLight;
    
    final colorScheme = ColorScheme.light(
      primary: PadelColors.blueTeamLight,  // UI general siempre azul
      primaryContainer: const Color(0xFFD6E8FF),
      secondary: PadelColors.redTeamLight,  // UI general siempre rojo
      secondaryContainer: const Color(0xFFFFDAD6),
      tertiary: PadelColors.gold,
      tertiaryContainer: const Color(0xFFFFECB3),
      surface: const Color(0xFFFAFAFA),
      surfaceContainerHighest: const Color(0xFFE0E0E0),
      error: const Color(0xFFB00020),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: const Color(0xFF1A1A1A),
      onSurfaceVariant: const Color(0xFF5A5A5A),
      outline: const Color(0xFFBDBDBD),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      
      // Typography
      fontFamily: 'Roboto',
      textTheme: _buildTextTheme(colorScheme.onSurface),
      
      // Card
      cardTheme: CardThemeData(
        elevation: 2,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      
      // App Bar
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      
      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      
      // Filled Button
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      
      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      
      // Icon Button
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      
      // Divider
      dividerTheme: DividerThemeData(
        color: colorScheme.outline.withOpacity(0.2),
        thickness: 1,
      ),
      
      // Segmented Button (Light theme)
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.primary;
            }
            return colorScheme.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.onPrimary;
            }
            return colorScheme.onSurface;
          }),
          side: WidgetStateProperty.resolveWith<BorderSide>((states) {
            if (states.contains(WidgetState.selected)) {
              return BorderSide(color: colorScheme.primary, width: 1.5);
            }
            return BorderSide(color: colorScheme.outline.withOpacity(0.5), width: 1);
          }),
        ),
      ),
      
      // Floating Action Button (Light theme)
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        highlightElevation: 8,
      ),
      
      // Extensions personalizadas
      extensions: <ThemeExtension<dynamic>>[
        PadelThemeExtension(
          teamBlueColor: t1Color,
          teamRedColor: t2Color,
          scoreboardBackgroundBlue: t1Color,
          scoreboardBackgroundRed: t2Color,
          sidebarBackground: Colors.white.withOpacity(0.95),
          sidebarDivider: Colors.black.withOpacity(0.1),
          digitalFontColor: Colors.white,
          hexPatternColor: Colors.white.withOpacity(0.05),
          brandBackgroundColor: Colors.black.withOpacity(0.3),
          tieBreakColor: PadelColors.tieBreakColor,
          deuceColor: PadelColors.deuceColor,
          goldenPointColor: PadelColors.goldenPointColor,
          winnerOverlayBackground: Colors.black.withOpacity(0.85),
        ),
      ],
    );
  }

  // Tema oscuro con colores personalizables SOLO para equipos (no para UI general)
  static ThemeData darkTheme({Color? team1Color, Color? team2Color}) {
    final t1Color = team1Color ?? PadelColors.blueTeamLight;
    final t2Color = team2Color ?? PadelColors.redTeamLight;
    
    final colorScheme = ColorScheme.dark(
      primary: PadelColors.blueTeamLight,  // UI general siempre azul
      primaryContainer: const Color(0xFF1E3A5F),
      secondary: PadelColors.redTeamLight,  // UI general siempre rojo
      secondaryContainer: const Color(0xFF5F1E1E),
      tertiary: PadelColors.gold,
      tertiaryContainer: const Color(0xFF5F4C1E),
      surface: const Color(0xFF121212),
      surfaceContainerHighest: const Color(0xFF2A2A2A),
      error: const Color(0xFFCF6679),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: const Color(0xFFE0E0E0),
      onSurfaceVariant: const Color(0xFFB0B0B0),
      outline: const Color(0xFF3A3A3A),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      
      // Typography
      fontFamily: 'Roboto',
      textTheme: _buildTextTheme(colorScheme.onSurface),
      
      // Card
      cardTheme: CardThemeData(
        elevation: 4,
        color: const Color(0xFF1E1E1E),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      
      // App Bar
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      
      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      
      // Filled Button
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      
      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide(color: colorScheme.outline),
        ),
      ),
      
      // Icon Button
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      
      // Divider
      dividerTheme: DividerThemeData(
        color: colorScheme.outline.withOpacity(0.2),
        thickness: 1,
      ),
      
      // Segmented Button (Dark theme)
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.primary;
            }
            return colorScheme.surfaceContainerHighest;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.onPrimary;
            }
            return colorScheme.onSurface;
          }),
          side: WidgetStateProperty.resolveWith<BorderSide>((states) {
            if (states.contains(WidgetState.selected)) {
              return BorderSide(color: colorScheme.primary, width: 1.5);
            }
            return BorderSide(color: colorScheme.outline.withOpacity(0.5), width: 1);
          }),
        ),
      ),
      
      // Floating Action Button (Dark theme)
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 6,
        highlightElevation: 12,
      ),
      
      // Extensions personalizadas
      extensions: <ThemeExtension<dynamic>>[
        PadelThemeExtension(
          teamBlueColor: t1Color,
          teamRedColor: t2Color,
          scoreboardBackgroundBlue: t1Color,
          scoreboardBackgroundRed: t2Color,
          sidebarBackground: const Color(0xFF1A1A2E).withOpacity(0.95),
          sidebarDivider: Colors.white.withOpacity(0.1),
          digitalFontColor: Colors.white,
          hexPatternColor: Colors.white.withOpacity(0.05),
          brandBackgroundColor: Colors.black.withOpacity(0.3),
          tieBreakColor: PadelColors.tieBreakColor,
          deuceColor: PadelColors.deuceColor,
          goldenPointColor: PadelColors.goldenPointColor,
          winnerOverlayBackground: Colors.black.withOpacity(0.85),
        ),
      ],
    );
  }

  static TextTheme _buildTextTheme(Color baseColor) {
    return TextTheme(
      displayLarge: TextStyle(fontSize: 96, fontWeight: FontWeight.w300, color: baseColor),
      displayMedium: TextStyle(fontSize: 60, fontWeight: FontWeight.w300, color: baseColor),
      displaySmall: TextStyle(fontSize: 48, fontWeight: FontWeight.w400, color: baseColor),
      headlineLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w400, color: baseColor),
      headlineMedium: TextStyle(fontSize: 34, fontWeight: FontWeight.w400, color: baseColor),
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w400, color: baseColor),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: baseColor),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: baseColor),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: baseColor),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: baseColor),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: baseColor),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: baseColor),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: baseColor),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: baseColor),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: baseColor),
    );
  }
}

/// Extension personalizada del tema con colores específicos de pádel
class PadelThemeExtension extends ThemeExtension<PadelThemeExtension> {
  final Color teamBlueColor;
  final Color teamRedColor;
  final Color scoreboardBackgroundBlue;
  final Color scoreboardBackgroundRed;
  final Color sidebarBackground;
  final Color sidebarDivider;
  final Color digitalFontColor;
  final Color hexPatternColor;
  final Color brandBackgroundColor;
  final Color tieBreakColor;
  final Color deuceColor;
  final Color goldenPointColor;
  final Color winnerOverlayBackground;

  const PadelThemeExtension({
    required this.teamBlueColor,
    required this.teamRedColor,
    required this.scoreboardBackgroundBlue,
    required this.scoreboardBackgroundRed,
    required this.sidebarBackground,
    required this.sidebarDivider,
    required this.digitalFontColor,
    required this.hexPatternColor,
    required this.brandBackgroundColor,
    required this.tieBreakColor,
    required this.deuceColor,
    required this.goldenPointColor,
    required this.winnerOverlayBackground,
  });

  /// Factory para crear desde AppConfig
  factory PadelThemeExtension.fromConfig(dynamic config) {
    // Extraer colores de equipos desde config si existen
    Color team1Color = PadelColors.blueTeamLight;
    Color team2Color = PadelColors.redTeamLight;
    
    try {
      if (config != null && config.teams != null && config.teams.isNotEmpty) {
        if (config.teams.length > 0 && config.teams[0].colorHex != null) {
          team1Color = _hexToColor(config.teams[0].colorHex);
        }
        if (config.teams.length > 1 && config.teams[1].colorHex != null) {
          team2Color = _hexToColor(config.teams[1].colorHex);
        }
      }
    } catch (e) {
      // Usar colores por defecto si hay error
    }
    
    return PadelThemeExtension(
      teamBlueColor: team1Color,
      teamRedColor: team2Color,
      scoreboardBackgroundBlue: team1Color,
      scoreboardBackgroundRed: team2Color,
      sidebarBackground: const Color(0xFF1A1A2E).withOpacity(0.95),
      sidebarDivider: Colors.white.withOpacity(0.1),
      digitalFontColor: Colors.white,
      hexPatternColor: Colors.white.withOpacity(0.05),
      brandBackgroundColor: Colors.black.withOpacity(0.3),
      tieBreakColor: PadelColors.tieBreakColor,
      deuceColor: PadelColors.deuceColor,
      goldenPointColor: PadelColors.goldenPointColor,
      winnerOverlayBackground: Colors.black.withOpacity(0.85),
    );
  }
  
  static Color _hexToColor(String hex) {
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16) ?? 0xFF2196F3;
    return Color(v);
  }

  @override
  PadelThemeExtension copyWith({
    Color? teamBlueColor,
    Color? teamRedColor,
    Color? scoreboardBackgroundBlue,
    Color? scoreboardBackgroundRed,
    Color? sidebarBackground,
    Color? sidebarDivider,
    Color? digitalFontColor,
    Color? hexPatternColor,
    Color? brandBackgroundColor,
    Color? tieBreakColor,
    Color? deuceColor,
    Color? goldenPointColor,
    Color? winnerOverlayBackground,
  }) {
    return PadelThemeExtension(
      teamBlueColor: teamBlueColor ?? this.teamBlueColor,
      teamRedColor: teamRedColor ?? this.teamRedColor,
      scoreboardBackgroundBlue: scoreboardBackgroundBlue ?? this.scoreboardBackgroundBlue,
      scoreboardBackgroundRed: scoreboardBackgroundRed ?? this.scoreboardBackgroundRed,
      sidebarBackground: sidebarBackground ?? this.sidebarBackground,
      sidebarDivider: sidebarDivider ?? this.sidebarDivider,
      digitalFontColor: digitalFontColor ?? this.digitalFontColor,
      hexPatternColor: hexPatternColor ?? this.hexPatternColor,
      brandBackgroundColor: brandBackgroundColor ?? this.brandBackgroundColor,
      tieBreakColor: tieBreakColor ?? this.tieBreakColor,
      deuceColor: deuceColor ?? this.deuceColor,
      goldenPointColor: goldenPointColor ?? this.goldenPointColor,
      winnerOverlayBackground: winnerOverlayBackground ?? this.winnerOverlayBackground,
    );
  }

  @override
  PadelThemeExtension lerp(ThemeExtension<PadelThemeExtension>? other, double t) {
    if (other is! PadelThemeExtension) {
      return this;
    }
    return PadelThemeExtension(
      teamBlueColor: Color.lerp(teamBlueColor, other.teamBlueColor, t)!,
      teamRedColor: Color.lerp(teamRedColor, other.teamRedColor, t)!,
      scoreboardBackgroundBlue: Color.lerp(scoreboardBackgroundBlue, other.scoreboardBackgroundBlue, t)!,
      scoreboardBackgroundRed: Color.lerp(scoreboardBackgroundRed, other.scoreboardBackgroundRed, t)!,
      sidebarBackground: Color.lerp(sidebarBackground, other.sidebarBackground, t)!,
      sidebarDivider: Color.lerp(sidebarDivider, other.sidebarDivider, t)!,
      digitalFontColor: Color.lerp(digitalFontColor, other.digitalFontColor, t)!,
      hexPatternColor: Color.lerp(hexPatternColor, other.hexPatternColor, t)!,
      brandBackgroundColor: Color.lerp(brandBackgroundColor, other.brandBackgroundColor, t)!,
      tieBreakColor: Color.lerp(tieBreakColor, other.tieBreakColor, t)!,
      deuceColor: Color.lerp(deuceColor, other.deuceColor, t)!,
      goldenPointColor: Color.lerp(goldenPointColor, other.goldenPointColor, t)!,
      winnerOverlayBackground: Color.lerp(winnerOverlayBackground, other.winnerOverlayBackground, t)!,
    );
  }
}

/// Helper extension para acceder fácilmente a los colores personalizados
extension PadelThemeContext on BuildContext {
  PadelThemeExtension get padelTheme {
    final theme = Theme.of(this).extension<PadelThemeExtension>();
    
    // ▲ FALLBACK SEGURO: Si el tema no existe, usar colores por defecto
    if (theme == null) {
      return const PadelThemeExtension(
        teamBlueColor: Color(0xFF2196F3),
        teamRedColor: Color(0xFFE53935),
        scoreboardBackgroundBlue: Color(0xFF1565C0),
        scoreboardBackgroundRed: Color(0xFFC62828),
        sidebarBackground: Color(0xFF263238),
        sidebarDivider: Color(0xFF455A64),
        digitalFontColor: Colors.white,
        hexPatternColor: Color(0x1AFFFFFF),
        brandBackgroundColor: Color(0xFF37474F),
        tieBreakColor: Color(0xFFFF6F00),
        deuceColor: Color(0xFFFFCA28),
        goldenPointColor: Color(0xFFFFD700),
        winnerOverlayBackground: Color(0xCC000000),
      );
    }
    
    return theme;
  }
}
