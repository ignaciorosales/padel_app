# 🎨 Sistema de Selección de Equipos

## 📋 Resumen

El usuario ahora puede **elegir los colores de cada equipo** desde la configuración de la app. Los colores se guardan persistentemente y se aplican automáticamente al marcador.

## 🎯 ¿Cómo Funciona?

### 1. **Paleta de Equipos Disponibles** (`padel_config.json`)

```json
{
  "availableTeams": [
    { "id": "azul", "displayName": "Azul", "colorHex": "#1976D2" },
    { "id": "rojo", "displayName": "Rojo", "colorHex": "#D32F2F" },
    { "id": "verde", "displayName": "Verde", "colorHex": "#009900" },
    { "id": "negro", "displayName": "Negro", "colorHex": "#171717" },
    { "id": "rosa", "displayName": "Rosa", "colorHex": "#E91E63" },
    { "id": "violeta", "displayName": "Violeta", "colorHex": "#9C27B0" },
    { "id": "naranja", "displayName": "Naranja", "colorHex": "#FF6600" },
    { "id": "turquesa", "displayName": "Turquesa", "colorHex": "#00BCD4" },
    { "id": "amarillo", "displayName": "Amarillo", "colorHex": "#FFC107" }
  ]
}
```

**`availableTeams`** es la paleta de equipos que el usuario puede elegir.

### 2. **Persistencia de Selección** (`TeamSelectionService`)

La selección del usuario se guarda en `SharedPreferences`:
- **`selected_team1_id`**: ID del equipo seleccionado para el lado izquierdo (default: "verde")
- **`selected_team2_id`**: ID del equipo seleccionado para el lado derecho (default: "negro")

### 3. **Aplicación Automática**

Cuando el usuario cambia los colores:
1. Se guarda en SharedPreferences
2. Se notifica a través de `ValueNotifier`
3. `main.dart` escucha los cambios y **reconstruye el tema automáticamente**
4. El marcador se actualiza instantáneamente con los nuevos colores y nombres

## 🏗️ Arquitectura del Sistema

### Archivos Clave

#### **`lib/config/team_selection_service.dart`** (NUEVO)
Servicio centralizado para gestionar la selección de equipos:

```dart
class TeamSelectionService {
  // Persistencia
  final SharedPreferences _prefs;
  
  // Notificadores para cambios en tiempo real
  final ValueNotifier<String> team1Selection;  // ID del equipo 1
  final ValueNotifier<String> team2Selection;  // ID del equipo 2
  
  // Métodos públicos
  TeamDef? getTeam1()              // Obtener equipo 1 completo
  TeamDef? getTeam2()              // Obtener equipo 2 completo
  Color getColor1()                // Color del equipo 1
  Color getColor2()                // Color del equipo 2
  Future<void> setTeam1(String id) // Cambiar equipo 1
  Future<void> setTeam2(String id) // Cambiar equipo 2
}
```

#### **`lib/config/app_config.dart`** (ACTUALIZADO)
Modelo de configuración simplificado:

```dart
@freezed
class AppConfig with _$AppConfig {
  const factory AppConfig({
    @Default(<TeamDef>[]) List<TeamDef> availableTeams,  // Paleta de equipos
    @Default(<TeamDef>[]) List<TeamDef> teams,            // Para sinónimos de voz
    // ... otros campos ...
  }) = _AppConfig;
}

extension AppConfigX on AppConfig {
  TeamDef? teamById(String id);              // Buscar equipo por ID
  Color colorForTeamId(String id);           // Obtener color de un equipo
}
```

#### **`lib/main.dart`** (ACTUALIZADO)
Inicializa el servicio y escucha cambios:

```dart
Future<void> main() async {
  final config = await ConfigLoader.load();
  final teamSelection = await TeamSelectionService.init(config);
  runApp(PadelApp(config: config, teamSelection: teamSelection));
}

class _PadelAppState extends State<PadelApp> {
  @override
  void initState() {
    super.initState();
    // Escuchar cambios en la selección para reconstruir el tema
    widget.teamSelection.team1Selection.addListener(_onTeamColorsChanged);
    widget.teamSelection.team2Selection.addListener(_onTeamColorsChanged);
  }
  
  void _onTeamColorsChanged() {
    if (mounted) {
      setState(() {
        // Forzar reconstrucción del MaterialApp con nuevos colores
      });
    }
  }
  
  ThemeData _lightTheme() {
    final team1Color = widget.teamSelection.getColor1();
    final team2Color = widget.teamSelection.getColor2();
    return PadelTheme.lightTheme(team1Color: team1Color, team2Color: team2Color);
  }
}
```

#### **`lib/features/widgets/scoreboard.dart`** (ACTUALIZADO)
Usa nombres dinámicos desde la selección:

```dart
BlocBuilder<ScoringBloc, ScoringState>(
  buildWhen: (p, n) => false,
  builder: (ctx, _) {
    final teamService = RepositoryProvider.of<TeamSelectionService>(ctx);
    final team = teamService.getTeam1();
    final teamName = team?.displayName.toUpperCase() ?? 'EQUIPO 1';
    return Text(teamName, ...);
  },
),
```

#### **`lib/features/settings/match_settings_screen.dart`** (ACTUALIZADO)
Nueva sección de "Colores de equipos" en Apariencia:

```dart
// Equipo 1
ValueListenableBuilder<String>(
  valueListenable: teamService.team1Selection,
  builder: (_, selectedId, __) {
    return Wrap(
      children: config.availableTeams.map((team) {
        final isSelected = team.id == selectedId;
        return _ColorTile(
          team: team,
          isSelected: isSelected,
          onPressed: () async {
            await teamService.setTeam1(team.id);
            // El tema se reconstruirá automáticamente
          },
        );
      }).toList(),
    );
  },
),
```

## 🎨 UI de Selección de Colores

### Pantalla de Configuración → Apariencia

1. **Tema de la aplicación**: Claro / Oscuro (como antes)
2. **Colores de equipos** (NUEVO):
   - **Equipo 1 (Lado izquierdo)**: Grid de 9 opciones de colores
   - **Equipo 2 (Lado derecho)**: Grid de 9 opciones de colores

### Widget `_ColorTile`

Cada opción de color muestra:
- ⭕ **Círculo de color** (60x60 px)
- ✓ **Check** si está seleccionado
- 📝 **Nombre** del equipo
- 🎯 **Focus visual** mejorado para Android TV (borde azul, sombra)
- ⚡ **Animación** de escala al hacer focus

## 📱 Flujo de Uso

### Primera Vez
1. App inicia con defaults: Verde (izquierda) y Negro (derecha)
2. Usuario abre Configuración → Apariencia
3. Ve 9 opciones de colores para cada equipo
4. Selecciona "Rosa" para Equipo 1
5. Selecciona "Turquesa" para Equipo 2
6. **Inmediatamente** el marcador se actualiza:
   - Fondo izquierdo: Rosa
   - Fondo derecho: Turquesa
   - Etiquetas: "ROSA" y "TURQUESA"

### Próximas Veces
- La selección se mantiene guardada en SharedPreferences
- Al abrir la app, carga automáticamente "Rosa" y "Turquesa"
- No necesita volver a configurar

## 🔄 Sincronización en Tiempo Real

### Listeners y Notificadores

```
Usuario selecciona color
       ↓
TeamSelectionService.setTeam1(id)
       ↓
Guarda en SharedPreferences
       ↓
Notifica via team1Selection ValueNotifier
       ↓
_PadelAppState._onTeamColorsChanged()
       ↓
setState() → Reconstruye MaterialApp
       ↓
_lightTheme() / _darkTheme() leen nuevos colores
       ↓
PadelTheme.xxxTheme(team1Color, team2Color)
       ↓
Scoreboard se actualiza con nuevos colores/nombres
```

## 🎯 Ventajas del Sistema

### ✅ **Persistente**
- La selección se guarda en SharedPreferences
- Sobrevive a cierres de la app
- No requiere configuración repetida

### ✅ **Reactivo**
- Cambios instantáneos sin reiniciar
- Listeners automáticos
- UI siempre sincronizada

### ✅ **Extensible**
- Fácil agregar más colores en `padel_config.json`
- Solo editar el JSON, no código Dart
- Sistema escalable para futuras mejoras

### ✅ **Tipo-Seguro**
- Modelos Freezed
- Validación automática de IDs
- Fallbacks robustos

## 📝 Cómo Agregar Más Colores

Editar `assets/config/padel_config.json`:

```json
{
  "availableTeams": [
    // ... equipos existentes ...
    {
      "id": "dorado",
      "displayName": "Dorado",
      "colorHex": "#FFD700"
    },
    {
      "id": "plateado",
      "displayName": "Plateado",
      "colorHex": "#C0C0C0"
    }
  ]
}
```

**No se requiere cambiar código Dart.** Solo rebuild y los nuevos colores aparecen automáticamente.

## 🔍 Debugging

### Ver selección actual:
```dart
print('Team 1: ${teamSelection.team1Selection.value}');
print('Team 2: ${teamSelection.team2Selection.value}');
```

### Ver colores aplicados:
```dart
print('Color 1: ${teamSelection.getColor1()}');
print('Color 2: ${teamSelection.getColor2()}');
```

### Limpiar persistencia:
```dart
final prefs = await SharedPreferences.getInstance();
await prefs.remove('selected_team1_id');
await prefs.remove('selected_team2_id');
```

## 🚀 Estado Actual

### ✅ Implementado:
- [x] Modelo `ColorOption` y `availableTeams` en config
- [x] `TeamSelectionService` con SharedPreferences
- [x] Integración en `main.dart` con listeners
- [x] UI de selección en `match_settings_screen.dart`
- [x] Actualización automática de tema y marcador
- [x] Persistencia de selección
- [x] 9 colores predefinidos (azul, rojo, verde, negro, rosa, violeta, naranja, turquesa, amarillo)

### 🎨 Colores Disponibles:
1. **Azul** #1976D2
2. **Rojo** #D32F2F
3. **Verde** #009900 (default equipo 1)
4. **Negro** #171717 (default equipo 2)
5. **Rosa** #E91E63
6. **Violeta** #9C27B0
7. **Naranja** #FF6600
8. **Turquesa** #00BCD4
9. **Amarillo** #FFC107

### 📲 Defaults:
- Equipo 1: Verde
- Equipo 2: Negro

## 🎉 Resultado Final

El usuario puede:
1. ✅ Ver 9 opciones de colores para cada equipo
2. ✅ Seleccionar cualquier combinación
3. ✅ Ver cambios instantáneos en el marcador
4. ✅ Guardar su selección permanentemente
5. ✅ Personalizar completamente la apariencia del partido

**El sistema es completamente dinámico, persistente y fácil de extender.** 🚀
