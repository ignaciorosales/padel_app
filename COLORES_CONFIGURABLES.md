# Colores Configurables por Equipos

## 📋 Resumen

La aplicación ahora permite personalizar **los colores de los equipos en el marcador** mediante `padel_config.json`. Los colores de la interfaz general (botones, menús, etc.) permanecen con el esquema azul/rojo original para mantener consistencia en la UI.

## 🎨 ¿Qué es Configurable?

### ✅ Colores Personalizables:
- **Fondo del marcador** (gradientes izquierdo/derecho)
- **Nombres de equipos** (etiquetas superiores)
- **Extensiones de tema** específicas del scoreboard

### ❌ NO Configurable (Siempre Azul):
- Botones flotantes (FAB)
- Menús y navegación
- Elementos de UI general
- Colores primarios/secundarios del tema

## 🎨 Configuración Actual

**Archivo:** `assets/config/padel_config.json`

```json
{
  "teams": [
    {
      "id": "team1",
      "displayName": "Equipo Verde",
      "colorHex": "#009900",
      "synonyms": ["verde", "equipo 1", "uno", "a"]
    },
    {
      "id": "team2",
      "displayName": "Equipo Negro",
      "colorHex": "#171717",
      "synonyms": ["negro", "equipo 2", "dos", "b"]
    }
  ]
}
```

### Colores Actuales:
- **Equipo 1 (Verde)**: `#009900` - Verde brillante
- **Equipo 2 (Negro)**: `#171717` - Negro oscuro

## 🔧 Cambios Implementados

### 1. **app_theme.dart**
- `PadelTheme.lightTheme()` → `PadelTheme.lightTheme({Color? team1Color, Color? team2Color})`
- `PadelTheme.darkTheme()` → `PadelTheme.darkTheme({Color? team1Color, Color? team2Color})`
- Los temas ahora aceptan colores personalizados que se aplican a:
  - Gradientes del fondo del marcador
  - Colores primarios y secundarios del theme
  - Extensiones del tema (PadelThemeExtension)

### 2. **main.dart**
- `_lightTheme()` y `_darkTheme()` ahora leen los colores de `AppConfig`
- Los colores se extraen dinámicamente:
  ```dart
  final team1Color = config.colorFor('team1');  // #009900
  final team2Color = config.colorFor('team2');  // #171717
  ```

### 3. **scoreboard.dart**
- **Gradientes de fondo**: Usan `padelTheme.scoreboardBackgroundBlue/Red` (ahora dinámicos)
- **Nombres de equipos**: Usan `cfg.teams[0/1].displayName.toUpperCase()`
  - Antes: "VERDE" / "NEGRO" (hardcoded)
  - Ahora: De configuración ("EQUIPO VERDE" / "EQUIPO NEGRO")

## 🎨 Paleta de Colores Sugerida

Puedes cambiar los colores en `padel_config.json` para personalizar la apariencia:

### Combinaciones Populares:

**Clásico (Azul vs Rojo):**
```json
"colorHex": "#0062FF"  // Equipo 1 - Azul
"colorHex": "#FF0000"  // Equipo 2 - Rojo
```

**Verde vs Negro (Actual):**
```json
"colorHex": "#009900"  // Equipo 1 - Verde
"colorHex": "#171717"  // Equipo 2 - Negro
```

**Naranja vs Púrpura:**
```json
"colorHex": "#FF6600"  // Equipo 1 - Naranja
"colorHex": "#9C27B0"  // Equipo 2 - Púrpura
```

**Amarillo vs Azul:**
```json
"colorHex": "#FFD600"  // Equipo 1 - Amarillo
"colorHex": "#1976D2"  // Equipo 2 - Azul
```

**Turquesa vs Coral:**
```json
"colorHex": "#00BCD4"  // Equipo 1 - Turquesa
"colorHex": "#FF5722"  // Equipo 2 - Coral
```

## 📝 Cómo Cambiar los Colores

1. Abre `assets/config/padel_config.json`
2. Modifica `colorHex` de cada equipo (formato: `#RRGGBB`)
3. Modifica `displayName` si deseas cambiar el nombre mostrado
4. Reinicia la aplicación para ver los cambios

### Ejemplo Completo:

```json
{
  "teams": [
    {
      "id": "team1",
      "displayName": "Los Tigres",
      "colorHex": "#FF6600",
      "synonyms": ["tigres", "naranja", "equipo 1"]
    },
    {
      "id": "team2",
      "displayName": "Los Leones",
      "colorHex": "#9C27B0",
      "synonyms": ["leones", "púrpura", "equipo 2"]
    }
  ]
}
```

## 🎯 Dónde se Aplican los Colores

### Marcador Principal (scoreboard.dart):
- ✅ Fondo diagonal izquierdo (Equipo 1 - Verde #009900)
- ✅ Fondo diagonal derecho (Equipo 2 - Negro #171717)
- ✅ Nombres de equipos ("EQUIPO VERDE" / "EQUIPO NEGRO")

### UI General (NO cambia):
- ❌ Botones flotantes (siempre azul)
- ❌ Menús y diálogos (siempre azul)
- ❌ Elementos interactivos (mantienen color azul original)

## ⚠️ Consideraciones

### Contraste:
Los colores deben tener buen contraste con el texto blanco:
- ✅ Verde (#009900) - Excelente contraste
- ✅ Negro (#171717) - Excelente contraste
- ❌ Amarillo claro (#FFFF00) - Mal contraste (difícil de leer)

### Legibilidad en TV:
Para pantallas de TV (Android TV Box), se recomienda:
- Colores saturados y brillantes
- Alto contraste con el texto blanco
- Evitar tonos muy claros o pasteles

### Accesibilidad:
- Los usuarios con daltonismo pueden tener dificultad con ciertas combinaciones
- Verde + Rojo puede ser problemático
- Verde + Negro (actual) es una buena alternativa

## 🚀 Compilación y Despliegue

Después de cambiar los colores en `padel_config.json`:

```powershell
# Compilar APK para Android TV Box
flutter build apk

# El archivo estará en:
# build\app\outputs\flutter-apk\app-release.apk
```

No es necesario modificar código Dart para cambiar colores, solo el archivo JSON.

## 📊 Resultado Final

Con la configuración actual (Verde #009900 y Negro #171717):
- **Lado izquierdo**: Gradiente verde (brillante → oscuro)
- **Lado derecho**: Gradiente negro (oscuro → muy oscuro)
- **Etiquetas**: "EQUIPO VERDE" y "EQUIPO NEGRO" (en blanco)
- **Todos los elementos interactivos**: Usan los colores de los equipos

¡Los colores ahora son 100% configurables sin tocar código! 🎉
