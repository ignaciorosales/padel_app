# 🔌 Configuración Hardware RS-485 - Sistema de Marcador Pádel

## 📐 Topología del Sistema

```
TV Box (Windows)
    │
    │ USB-A
    │
┌───▼────────────────┐
│ Módulo USB-RS485   │ ← 120Ω (resistencia de terminación)
│ (MAX485/MAX3485)   │
└───┬────────────────┘
    │
    │ Cable 60m (par trenzado)
    │ A+ (Verde)
    │ B- (Blanco-Verde)
    │ GND (Común)
    │
    ├─────────┐
    │         │
┌───▼─────┐   │
│ ESP32-1 │   │ ← Botonera campo izquierdo
│ A+ B-   │   │
└─────────┘   │
              │
    ├─────────┤
    │         │
┌───▼─────┐   │
│ ESP32-2 │   │ ← Botonera campo derecho
│ A+ B-   │   │
└─────────┘   │
              │
    ├─────────┤
    │         │
┌───▼─────┐   │
│ ESP32-3 │   │ ← Botonera árbitro
│ A+ B-   │   │
└─────────┘   │
              │
            120Ω ← Resistencia de terminación final
```

## 🛠️ Componentes Necesarios

### TV Box (Receptor)
- **Módulo USB-RS485**: MAX485 o MAX3485
  - Chip: MAX485 (3.3V - 5V compatible)
  - Conexión: USB-A macho al TV Box
  - Resistencia: 120Ω interna entre A+ y B- (o agregar externa)
  - LEDs indicadores (TX/RX) recomendados

### Cable Principal (60 metros)
- **Tipo**: Par trenzado Cat5e/Cat6 (UTP o STP)
- **Conductores**:
  - **A+ (DATA+)**: Cable Verde
  - **B- (DATA-)**: Cable Blanco-Verde
  - **GND**: Cable Naranja (común para alimentación)
  - **VCC**: Cable Blanco-Naranja (opcional, si se alimenta por cable)
- **Características**:
  - Impedancia: 120Ω
  - Calibre: AWG 24 (suficiente para señal + alimentación <500mA)

### ESP32 (Transmisor - cada botonera)
- **Microcontrolador**: ESP32-C3 o ESP32-S3
- **Módulo RS-485**: MAX485
  - **Conexiones ESP32 → MAX485**:
    - GPIO 21 → DI (Data Input)
    - GPIO 20 → RO (Receiver Output)
    - GPIO 10 → DE/RE (Driver Enable, unidos)
    - 3.3V → VCC
    - GND → GND
  - **Conexiones MAX485 → Bus**:
    - A → A+ del cable (Verde)
    - B → B- del cable (Blanco-Verde)
    - GND → GND del cable

### Resistencias de Terminación
- **Valor**: 120Ω ± 5% (1/4W)
- **Ubicación 1**: Dentro del módulo USB-RS485 (extremo TV Box)
- **Ubicación 2**: En el último ESP32 de la línea (extremo más alejado)
- **Instalación**: Soldar entre pines A+ y B- del MAX485

## 🔧 Instrucciones de Instalación

### Paso 1: Preparar el Cable (60m)

1. **Cortar el cable** a la longitud exacta del recorrido
2. **Pelar y preparar extremos**:
   - Extremo 1 (TV Box): Conector USB-A del módulo RS-485
   - Extremo 2 (Final): Conexión al último ESP32 + resistencia 120Ω

3. **Código de colores** (cable Cat5e):
   ```
   Verde         → A+ (DATA+)
   Blanco-Verde  → B- (DATA-)
   Naranja       → GND
   Blanco-Naranja → VCC (5V opcional)
   ```

### Paso 2: Conectar TV Box

1. **Módulo USB-RS485**:
   - Conectar cables Verde (A+) y Blanco-Verde (B-) del cable principal
   - Conectar GND
   - **IMPORTANTE**: Verificar que tenga resistencia de 120Ω entre A+ y B-
     - Si no la tiene, soldar una resistencia 120Ω entre los bornes A y B

2. **Enchufar USB-A** al TV Box

3. **Verificar en Windows**:
   ```powershell
   # Abrir Device Manager
   devmgmt.msc
   
   # Buscar en "Ports (COM & LPT)"
   # Debe aparecer algo como "USB Serial Port (COM3)"
   ```

### Paso 3: Conectar Cada ESP32 (Botoneras)

#### Esquema de conexión ESP32:

```
ESP32-C3          MAX485          Bus RS-485
                                  (Cable 60m)
GPIO 21 (TX) ──► DI
GPIO 20 (RX) ◄── RO
GPIO 10      ──► DE/RE
                 (unidos)
3.3V         ──► VCC
GND          ──► GND ──────────► GND (Naranja)
                 A  ──────────► A+ (Verde)
                 B  ──────────► B- (Blanco-Verde)
```

#### Procedimiento:

1. **Empalmar cables** en cada punto donde pase por una botonera:
   - **NO cortar** el cable principal
   - Hacer un **tap-off** (derivación) corta (<30cm) hacia el ESP32
   - Usar conectores rápidos o soldar + termocontraíble

2. **Conexión ESP32 → MAX485**:
   ```
   ESP32      →  MAX485
   ────────────────────
   GPIO 21    →  DI (pin 1)
   GPIO 20    →  RO (pin 4)
   GPIO 10    →  DE y RE unidos (pins 2-3)
   3.3V       →  VCC (pin 8)
   GND        →  GND (pin 5)
   ```

3. **Conexión MAX485 → Bus**:
   ```
   MAX485     →  Cable 60m
   ─────────────────────
   A (pin 6)  →  Verde (A+)
   B (pin 7)  →  Blanco-Verde (B-)
   GND        →  Naranja (GND)
   ```

4. **Solo en el ÚLTIMO ESP32**:
   - Soldar resistencia de **120Ω** entre cables Verde (A+) y Blanco-Verde (B-)
   - Esto termina el bus y evita reflexiones de señal

### Paso 4: Alimentación de los ESP32

Tienes 2 opciones:

#### Opción A: Alimentación Local (Recomendado)
- Cada ESP32 se alimenta de un cargador USB 5V local
- **Ventaja**: No hay caída de tensión en el cable largo
- **Desventaja**: Necesitas enchufes cerca de cada botonera

#### Opción B: Alimentación por Cable (Power-over-Bus)
- Usa los cables Naranja (GND) y Blanco-Naranja (VCC 5V)
- Inyecta 5V desde el TV Box
- **Ventaja**: Solo un enchufe (TV Box)
- **Desventaja**: 
  - Caída de tensión en 60m (~0.5V @ 500mA)
  - Cable AWG 24 limita corriente total a ~500mA (3 ESP32 @ 150mA c/u)

**Cálculo caída de tensión**:
```
Cable Cat5e AWG24: ~84Ω/km
60m = 0.06km × 84Ω = 5Ω (ida + vuelta = 10Ω)
Corriente 3 ESP32: 3 × 150mA = 450mA
Caída: V = I × R = 0.45A × 10Ω = 4.5V
Tensión ESP32 final: 5V - 4.5V = 0.5V ❌ NO SUFICIENTE

Solución: Usar 7-9V en origen + reguladores buck en cada ESP32
```

## 📊 Especificaciones Técnicas

### Protocolo de Comunicación

| Parámetro | Valor |
|-----------|-------|
| Velocidad | 115200 baud |
| Bits de datos | 8 |
| Paridad | None |
| Bits de parada | 1 |
| Control de flujo | None |
| Modo | Half-duplex (solo TX desde ESP32) |

### Frame de Datos (10 bytes)

```
Byte 0: 'P'       (0x50) - Header
Byte 1: 'S'       (0x53) - Header
Byte 2: version   (0x01) - Protocolo v1
Byte 3: devIdLo   (0x00-0xFF) - Device ID bajo
Byte 4: devIdHi   (0x00-0xFF) - Device ID alto
Byte 5: 'C'       (0x43) - Command frame
Byte 6: cmd       ('p'|'u'|'g') - Comando
Byte 7: seq       (1-255) - Número de secuencia
Byte 8: crcLo     (0x00-0xFF) - CRC16 bajo
Byte 9: crcHi     (0x00-0xFF) - CRC16 alto
```

**CRC**: CRC16-CCITT (poly 0x1021, init 0xFFFF)

### Comandos

| Comando | ASCII | Hex | Descripción |
|---------|-------|-----|-------------|
| Punto | 'p' | 0x70 | Marca un punto para el equipo |
| Undo | 'u' | 0x75 | Deshace el último punto |
| Restart | 'g' | 0x67 | Reinicia el partido |

### Timing

| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| Transmisión 10 bytes @ 115200 | ~0.87 ms | Tiempo TX desde ESP32 |
| Propagación 60m | ~0.3 µs | Velocidad luz en cobre (0.67c) |
| Procesamiento TV Box | <0.5 ms | Parse + validación CRC |
| **Latencia Total E2E** | **<2 ms** | Desde botón hasta UI actualizada |
| Cooldown puntos | 4 segundos | Anti-rebote global |
| Intervalo mínimo comandos | 300 ms | Entre cualquier comando |

### Limitaciones del Bus

| Parámetro | Valor | Motivo |
|-----------|-------|--------|
| Longitud máxima cable | 100m | @ 115200 baud (especificación RS-485) |
| Dispositivos máximos | 32 | Carga capacitiva del bus |
| Derivaciones (tap-offs) | <30cm | Evitar reflexiones |
| Impedancia bus | 120Ω | Terminación correcta |

## ✅ Verificación de la Instalación

### 1. Test de Continuidad (Multímetro)

```
TV Box Extremo    →    ESP32 Final
─────────────────────────────────
A+ (Verde)        →    120-130Ω  (debe incluir las 2 resistencias de 120Ω en serie)
B- (Blanco-Verde) →    (medido entre A+ y B-)
GND (Naranja)     →    <1Ω       (continuidad)
```

### 2. Test de Voltaje (con ESP32 alimentados)

```powershell
# En el ÚLTIMO ESP32, medir:
A+ respecto a GND:  ~2.5V (idle, estado recesivo)
B- respecto a GND:  ~2.5V (idle, estado recesivo)
A+ - B-:            ~0V   (diferencial idle)

# Durante transmisión:
A+ - B-:            ±200mV (señal diferencial)
```

### 3. Test Software (TV Box)

1. **Instalar app de terminal serial**:
   ```powershell
   # Opción 1: PuTTY
   winget install PuTTY.PuTTY
   
   # Opción 2: Usar PowerShell con .NET
   ```

2. **Conectar al puerto COM**:
   ```powershell
   # Identificar puerto
   [System.IO.Ports.SerialPort]::getportnames()
   # Ejemplo output: COM3
   
   # Configurar puerto
   $port = new-Object System.IO.Ports.SerialPort COM3,115200,None,8,one
   $port.Open()
   
   # Leer datos (presionar botón en ESP32)
   while($true) {
       $data = $port.ReadByte()
       Write-Host ([char]$data) -NoNewline
   }
   ```

3. **Presionar botón en ESP32**: Deberías ver bytes hexadecimales en la terminal:
   ```
   50 53 01 AB CD 43 70 01 xx xx
   P  S  v  devId  C  p  seq crc
   ```

### 4. Test de la App Flutter

1. **Ejecutar app**:
   ```powershell
   cd c:\Users\Sergio\padel_app
   flutter run -d windows
   ```

2. **Verificar conexión**:
   - La app debe detectar automáticamente el puerto COM
   - En consola debe aparecer: `[SERIAL] ✅ Conectado a COM3 @ 115200 baud`

3. **Probar botones**:
   - Presionar botón 'P' en cualquier ESP32
   - El marcador debe incrementar
   - En consola: `[SERIAL] ✅ Comando: p:123 (dev=0xABCD, team=blue)`

## 🐛 Troubleshooting

### Problema: App no detecta puerto COM

**Causas**:
- Driver USB-RS485 no instalado
- Puerto COM en uso por otra app

**Solución**:
```powershell
# Ver puertos disponibles
[System.IO.Ports.SerialPort]::getportnames()

# Si no aparece COM, instalar driver CH340/CP2102/FTDI según chip USB
# Verificar en Device Manager (devmgmt.msc)
```

### Problema: Comandos no llegan / CRC inválido

**Causas**:
- Resistencias de terminación faltantes o incorrectas
- Cable demasiado largo o dañado
- Conexiones A+/B- invertidas en algún punto

**Solución**:
1. Medir resistencia entre A+ y B- en extremos: debe ser ~60Ω (120Ω || 120Ω)
2. Verificar polaridad A+/B- en TODOS los ESP32
3. Reducir baud rate a 57600 si cable >60m:
   ```cpp
   // En ESP32: PadelScoreboard_Serial.ino
   #define RS485_BAUD 57600  // Cambiar de 115200
   ```

### Problema: Solo funciona el ESP32 más cercano

**Causas**:
- Falta resistencia de 120Ω en extremo final
- Tap-offs demasiado largos (>30cm) causan reflexiones

**Solución**:
1. Verificar resistencia 120Ω soldada en ÚLTIMO ESP32
2. Acortar derivaciones a <30cm
3. Usar topología "daisy-chain" en lugar de derivaciones largas

### Problema: Errores aleatorios / comandos duplicados

**Causas**:
- Ruido electromagnético (cables paralelos a 220V AC)
- Cable UTP sin blindaje cerca de motores/luces

**Solución**:
1. Usar cable STP (shielded twisted pair) en lugar de UTP
2. Conectar blindaje a GND solo en UN extremo (TV Box)
3. Separar >30cm de cables de potencia 220V
4. Agregar ferrite beads en extremos del cable

## 📦 Lista de Materiales (BOM)

| Componente | Cantidad | Precio aprox. | Link/Código |
|------------|----------|---------------|-------------|
| Módulo USB-RS485 | 1 | $8-15 | FTDI o CH340 variant |
| Cable Cat5e UTP | 60m | $0.15/m = $9 | Par trenzado AWG24 |
| ESP32-C3 | 3 | $3-5 c/u = $15 | Espressif oficial |
| Módulo MAX485 | 3 | $1-2 c/u = $6 | Breakout board |
| Resistencia 120Ω 1/4W | 4 | $0.10 c/u = $0.40 | (2 de repuesto) |
| Conectores rápidos | 10 | $0.20 c/u = $2 | Empalmes sin soldadura |
| Termocontraíble | 1m | $1 | Aislamiento empalmes |
| **TOTAL** | | **~$56** | Instalación completa |

## 📸 Fotos de Referencia

### Módulo USB-RS485 (extremo TV Box)
```
┌─────────────────────────┐
│  [ ]  USB-A connector   │ ← al TV Box
│                         │
│   MAX485 chip           │
│   [LED] TX  [LED] RX    │
│                         │
│   [A+] [B-] [GND]       │ ← al cable 60m (Verde/Blanco-Verde/Naranja)
│                         │
│   [120Ω] ← resistencia  │
└─────────────────────────┘
```

### Conexión ESP32 + MAX485 (cada botonera)
```
┌──────────────────┐        ┌─────────────┐
│   ESP32-C3       │        │  MAX485     │
│                  │        │             │
│  GPIO 21 (TX) ──────────► DI (pin 1)   │
│  GPIO 20 (RX) ◄────────── RO (pin 4)   │
│  GPIO 10      ──────────► DE/RE (2-3)  │
│  3.3V         ──────────► VCC (pin 8)  │
│  GND          ──────────► GND (pin 5)  │
│                  │        │             │
│                  │        │ A (pin 6) ─────► Cable Verde (A+)
│                  │        │ B (pin 7) ─────► Cable Blanco-Verde (B-)
│                  │        │ GND       ─────► Cable Naranja (GND)
│                  │        │             │
│  [Botones]       │        └─────────────┘
│  P U G           │
└──────────────────┘
```

---

## 🎯 Checklist Final de Instalación

- [ ] Cable 60m pelado y preparado en ambos extremos
- [ ] Módulo USB-RS485 con resistencia 120Ω verificada
- [ ] USB-RS485 conectado al TV Box (COM detectado en Device Manager)
- [ ] 3× ESP32 programados con `PadelScoreboard_Serial.ino`
- [ ] 3× Módulos MAX485 con conexiones verificadas (GPIO 21/20/10)
- [ ] Resistencia 120Ω soldada en el ÚLTIMO ESP32 (extremo final del bus)
- [ ] Todos los ESP32 conectados al bus con tap-offs <30cm
- [ ] Código de colores verificado: Verde=A+, Blanco-Verde=B-, Naranja=GND
- [ ] Test de continuidad: A+-B- = 120-130Ω entre extremos
- [ ] App Flutter ejecutándose: `flutter run -d windows`
- [ ] Test presionando botones: comandos llegan y marcador se actualiza
- [ ] Sin errores CRC en consola durante 5 minutos de prueba

---

**Fecha**: Noviembre 2025  
**Versión Hardware**: v1.0  
**Protocolo**: RS-485 @ 115200 baud  
**Arquitectura**: Bus lineal half-duplex  
