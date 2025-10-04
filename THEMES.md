# Temas de la App de Pádel

## Descripción

La aplicación de pádel utiliza un sistema de temas personalizado con Material 3 que permite cambiar fácilmente entre temas claro y oscuro, manteniendo consistencia visual en todos los widgets.

## Estructura

### Archivo Principal: `lib/config/app_theme.dart`

Este archivo contiene:

1. **PadelColors**: Colores constantes utilizados en toda la aplicación
2. **PadelTheme**: Clase con métodos estáticos para generar temas
3. **PadelThemeExtension**: Extensión personalizada del tema con colores específicos

## Colores Disponibles

### Colores de Equipos
```dart
PadelColors.blueTeamLight  // #4E95FF - Azul claro del equipo azul
PadelColors.blueTeamDark   // #0D2A4D - Azul oscuro del equipo azul
PadelColors.redTeamLight   // #FC4242 - Rojo claro del equipo rojo
PadelColors.redTeamDark    // #912430 - Rojo oscuro del equipo rojo
```

### Colores de Acento
```dart
PadelColors.gold           // #FFC107 - Dorado para ganador
PadelColors.orange         // #FF9800 - Naranja
PadelColors.purple         // #AB47BC - Púrpura para deuce
PadelColors.amber          // #FFB300 - Ámbar para punto de oro
```

### Colores de Estados Especiales
```dart
PadelColors.tieBreakColor      // #FF6E40 - Naranja para tie-break
PadelColors.deuceColor         // #AB47BC - Púrpura para deuce
PadelColors.goldenPointColor   // #FFB300 - Dorado para punto de oro
PadelColors.winnerColor        // #FFC107 - Dorado para pantalla de ganador
```

## Uso de Temas

### En main.dart

```dart
MaterialApp(
  theme: PadelTheme.lightTheme(),
  darkTheme: PadelTheme.darkTheme(),
  themeMode: ThemeMode.system, // o .light, .dark
  home: MyHomePage(),
)
```

### En Widgets

#### Usando colores del ColorScheme estándar:
```dart
@override
Widget build(BuildContext context) {
  return Container(
    color: Theme.of(context).colorScheme.primary,
    child: Text(
      'Hola',
      style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
    ),
  );
}
```

#### Usando colores personalizados de PadelThemeExtension:
```dart
@override
Widget build(BuildContext context) {
  final padelTheme = context.padelTheme;
  
  return Container(
    color: padelTheme.teamBlueColor,
    child: Text(
      'Equipo Azul',
      style: TextStyle(color: padelTheme.digitalFontColor),
    ),
  );
}
```

## Propiedades de PadelThemeExtension

```dart
teamBlueColor               // Color del equipo azul
teamRedColor                // Color del equipo rojo
scoreboardBackgroundBlue    // Color de fondo del scoreboard (lado azul)
scoreboardBackgroundRed     // Color de fondo del scoreboard (lado rojo)
sidebarBackground           // Color de fondo del sidebar del árbitro
sidebarDivider              // Color de divisores en el sidebar
digitalFontColor            // Color de la fuente digital
hexPatternColor             // Color del patrón hexagonal de fondo
brandBackgroundColor        // Color de fondo del brand "PadelScore.uy"
tieBreakColor               // Color para indicadores de tie-break
deuceColor                  // Color para indicadores de deuce
goldenPointColor            // Color para indicadores de punto de oro
winnerOverlayBackground     // Color de fondo del overlay de ganador
```

## Personalización de Colores

### Método 1: Modificar PadelColors

Edita directamente los valores en `lib/config/app_theme.dart`:

```dart
class PadelColors {
  static const blueTeamLight = Color(0xFF4E95FF); // Cambia este valor
  static const redTeamLight = Color(0xFFFC4242);  // Cambia este valor
  // ...
}
```

### Método 2: Crear variantes de tema

Puedes crear nuevos métodos en PadelTheme para diferentes variantes:

```dart
class PadelTheme {
  // Tema existente
  static ThemeData lightTheme() { ... }
  static ThemeData darkTheme() { ... }
  
  // Nuevo tema personalizado
  static ThemeData customTheme() {
    // Tu implementación personalizada
  }
}
```

### Método 3: Extender dinámicamente

Si necesitas cambiar colores en tiempo de ejecución:

```dart
final customExtension = PadelThemeExtension(
  teamBlueColor: Color(0xFF00FF00), // Verde
  teamRedColor: Color(0xFFFF00FF),  // Magenta
  // ... otros colores
);

return MaterialApp(
  theme: ThemeData(
    // ... configuración base
    extensions: [customExtension],
  ),
);
```

## Ejemplos de Uso en Widgets Existentes

### Scoreboard
```dart
final padelTheme = context.padelTheme;

Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [
        PadelColors.blueGradientStart,
        PadelColors.blueGradientEnd,
      ],
    ),
  ),
  child: CustomPaint(
    painter: HexPainter(color: padelTheme.hexPatternColor),
  ),
)
```

### Referee Sidebar
```dart
final padelTheme = context.padelTheme;

Card(
  color: padelTheme.sidebarBackground,
  child: Column(
    children: [
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: padelTheme.teamBlueColor,
        ),
        child: Text('Equipo AZUL'),
      ),
      Divider(color: padelTheme.sidebarDivider),
    ],
  ),
)
```

### Indicador de Tie-Break
```dart
final padelTheme = context.padelTheme;

Container(
  decoration: BoxDecoration(
    color: padelTheme.tieBreakColor.withOpacity(0.2),
    border: Border.all(color: padelTheme.tieBreakColor),
  ),
  child: Text(
    'TIE-BREAK',
    style: TextStyle(color: padelTheme.tieBreakColor),
  ),
)
```

## Diferencias entre Tema Claro y Oscuro

### Tema Claro
- Fondo blanco/gris muy claro
- Textos oscuros
- Sidebar con fondo blanco semi-transparente
- Divisores negros semi-transparentes

### Tema Oscuro
- Fondo negro/gris oscuro
- Textos claros
- Sidebar con fondo oscuro (#1A1A2E) semi-transparente
- Divisores blancos semi-transparentes

## Mejores Prácticas

1. **Usa `context.padelTheme`** para acceder a colores personalizados
2. **Usa `Theme.of(context).colorScheme`** para colores estándar de Material
3. **Mantén consistencia**: Si un widget usa `teamBlueColor`, todos los widgets de equipo azul deberían usar el mismo
4. **Respeta el modo del sistema**: Usa `ThemeMode.system` cuando sea posible
5. **Prueba ambos temas**: Siempre verifica que tu UI se vea bien en claro y oscuro

## Transiciones de Tema

Las transiciones entre temas son automáticas y fluidas gracias a:

1. `lerp()` en PadelThemeExtension que interpola entre colores
2. `AnimatedTheme` implícito en Material App
3. Material 3 con transiciones suaves entre estados

## Troubleshooting

### Los colores no se actualizan
- Verifica que estás usando `context.padelTheme` y no colores hardcodeados
- Asegúrate de que el widget se reconstruye cuando cambia el tema

### Colores incorrectos en modo oscuro
- Revisa que tu widget responde al cambio de tema
- Usa `Theme.of(context).brightness` si necesitas lógica condicional

### Performance
- Los temas son eficientes, pero evita llamar `context.padelTheme` múltiples veces
- Guarda la referencia en una variable local si la usas varias veces

```dart
final padelTheme = context.padelTheme; // Una sola vez
// Luego usa padelTheme.teamBlueColor, padelTheme.teamRedColor, etc.
```
