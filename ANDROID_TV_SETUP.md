# Guía de Instalación en Android TV Box

## 📱 Requisitos

- **TV Box Android** (cualquier versión Android 5.0+)
- **Módulo USB-RS485** compatible:
  - FTDI FT232 ✅ (recomendado)
  - CH340/CH341 ✅
  - CP210x (Silicon Labs) ✅
  - PL2303 ✅
- **Cable USB OTG** (si la TV Box solo tiene micro-USB)
- **Cable RS-485** de 60m con par trenzado
- **3 Botoneras ESP32** (programadas con el protocolo)

## 🔧 Preparación

### 1. Habilitar Modo Desarrollador en TV Box

1. Ve a **Configuración** → **Acerca de**
2. Presiona 7 veces sobre **Número de compilación**
3. Aparecerá mensaje: "Ahora eres desarrollador"

### 2. Habilitar Depuración USB (opcional, solo para desarrollo)

1. **Configuración** → **Opciones de desarrollador**
2. Activa **Depuración USB**
3. Activa **Instalar apps por USB** (si existe)

### 3. Conectar Módulo USB-RS485

```
TV Box (USB-A)
    ↓ (o cable USB OTG si es micro-USB)
Módulo USB-RS485
    ↓ (A+/B-)
Cable RS-485 de 60m
    ↓
Botoneras ESP32 (x3)
```

**Importante**: El módulo USB-RS485 debe tener resistencia de terminación de 120Ω activada.

## 📦 Instalación de la App

### Opción A: Compilar desde PC (Desarrollo)

1. Conecta la TV Box al PC por USB
2. Verifica que se detecta:
   ```powershell
   flutter devices
   ```
   Debería aparecer algo como: `Android TV (mobile) • android`

3. Compila e instala:
   ```powershell
   flutter run -d android
   ```

### Opción B: Instalar APK (Producción)

1. Compila el APK:
   ```powershell
   flutter build apk --release
   ```
   Se generará en: `build\app\outputs\flutter-apk\app-release.apk`

2. Transferir APK a la TV Box:
   - **Via USB**: Copiar APK a pendrive → conectar a TV Box
   - **Via red**: Usar `adb install` o apps como "Send Files to TV"
   - **Via navegador**: Subir APK a Drive/Dropbox y descargar desde TV

3. Instalar APK en TV Box:
   - Abrir **Explorador de archivos**
   - Navegar al APK
   - Tocar para instalar
   - Permitir "Instalar desde fuentes desconocidas" si pregunta

## 🎮 Primera Ejecución

### 1. Conectar USB-RS485

1. Conecta el módulo USB-RS485 a la TV Box
2. La app detectará automáticamente el dispositivo
3. Android pedirá permiso: **"¿Permitir acceso a dispositivo USB?"**
4. Marca ☑ **"Usar siempre para esta aplicación"**
5. Presiona **OK**

### 2. Verificar Conexión

En los logs de la app (si está en modo debug) deberías ver:

```
[SERIAL] Dispositivo encontrado:
  VID: 0x403
  PID: 0x6001
  Nombre: FT232R USB UART
[SERIAL] ✅ Conectado a FT232R USB UART
[SERIAL] Configuración: 115200 8N1
```

### 3. Probar Botoneras

1. Presiona **Botón A** en una botonera ESP32
2. Deberías ver:
   - Marcador aumenta para **Team BLUE** (izquierda)
   - Log: `[SERIAL] ✅ Comando: a:1:42`

3. Presiona **Botón B** en una botonera
4. Deberías ver:
   - Marcador aumenta para **Team RED** (derecha)
   - Log: `[SERIAL] ✅ Comando: b:2:43`

## 🔍 Solución de Problemas

### ❌ "No se detecta módulo USB-RS485"

**Causas comunes**:
1. Cable USB-OTG defectuoso → Prueba con otro
2. TV Box sin soporte USB-Host → Verifica en especificaciones
3. Módulo USB-RS485 sin drivers → Usa chip FTDI (soporte nativo en Android)

**Solución**:
```
1. Desconecta USB-RS485
2. Reinicia TV Box
3. Vuelve a conectar USB-RS485
4. La app lo detectará automáticamente
```

### ❌ "Permisos USB denegados"

**Solución**:
```
1. Configuración → Apps → Puntazo
2. Permisos → Borrar permisos
3. Abrir app de nuevo
4. Cuando pida permiso USB, marca "Usar siempre"
```

### ❌ "Comandos no se reciben"

**Verificar**:
1. ✅ Cable RS-485 bien conectado (A+/B- correctos)
2. ✅ Resistencias de terminación (120Ω) en ambos extremos
3. ✅ ESP32 programados con protocolo correcto (115200 baud)
4. ✅ Polaridad correcta (no intercambiar A+/B-)

### ❌ "App se cierra al conectar USB"

**Causa**: Conflicto con otra app que usa USB

**Solución**:
```
1. Configuración → Apps
2. Buscar apps que usen USB (ej: "Serial USB Terminal")
3. Desinstalarlas o forzar detención
4. Reiniciar TV Box
```

## 📊 Información Técnica

### Chips USB-Serial Soportados

| Chip       | VID    | PID    | Notas                          |
|------------|--------|--------|--------------------------------|
| FT232R     | 0x0403 | 0x6001 | ✅ Recomendado, más estable    |
| CH340G     | 0x1A86 | 0x7523 | ✅ Económico, funciona bien    |
| CP2102     | 0x10C4 | 0xEA60 | ✅ Buena calidad               |
| PL2303     | 0x067B | 0x2303 | ⚠️ Clones pueden dar problemas |

### Configuración Serial

- **Baud Rate**: 115200
- **Data Bits**: 8
- **Stop Bits**: 1
- **Parity**: None (8N1)
- **Flow Control**: None

### Protocolo RS-485

- **Topología**: Bus lineal (no estrella)
- **Terminación**: 120Ω en ambos extremos
- **Máxima distancia**: 100m @ 115200 baud
- **Nodos máximos**: 32 dispositivos (3 ESP32 en tu caso)

## 🚀 Auto-inicio al Encender TV Box

Para que la app inicie automáticamente cuando conectas el USB-RS485:

### Método 1: Configuración de Android (si está disponible)

1. **Configuración** → **Apps** → **Puntazo**
2. Buscar opción **"Abrir automáticamente"** o **"Abrir enlaces"**
3. Activar para dispositivos USB

### Método 2: App Launcher de Terceros

Instala **"Boot Manager"** o **"Autostart"** desde Play Store:
1. Configurar para iniciar **Puntazo** al boot
2. Configurar para iniciar al detectar USB

### Método 3: Ya configurado en AndroidManifest.xml

La app ya está configurada para responder a eventos USB:

```xml
<intent-filter>
    <action android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED" />
</intent-filter>
```

Cuando conectas el módulo USB-RS485, Android debería:
1. Mostrar diálogo: "¿Abrir Puntazo?"
2. Si marcas "Usar siempre" → Auto-inicio activado ✅

## 📝 Checklist de Instalación

- [ ] TV Box con Android 5.0+
- [ ] Módulo USB-RS485 (FTDI/CH340/CP210x)
- [ ] Cable USB-OTG (si es necesario)
- [ ] APK instalado en TV Box
- [ ] Permisos USB otorgados ("Usar siempre")
- [ ] Cable RS-485 conectado correctamente (A+/B-)
- [ ] Resistencias de terminación (120Ω) instaladas
- [ ] 3 ESP32 programados y energizados
- [ ] Prueba: Botón A → Team Blue ✅
- [ ] Prueba: Botón B → Team Red ✅
- [ ] Prueba: Auto-reconexión USB ✅

## 🎯 Siguiente Paso

Una vez que todo funcione:
1. Monta las botoneras en la cancha (posición deseada)
2. Conecta el cable RS-485 de 60m
3. Coloca la TV Box en posición visible
4. Conecta HDMI a pantalla grande
5. ¡A jugar pádel! 🎾

**Nota**: Las botoneras son universales (no hay "botonera de azules" ni "botonera de rojos"). Cualquier jugador puede usar cualquier botonera. La app mapea:
- **Botón A** → Equipo izquierdo (Blue)
- **Botón B** → Equipo derecho (Red)
