# Guía de Prueba de Comunicación Serial RS-485

## ✅ Arquitectura Correcta

### 🎯 **Concepto Clave: Botones Físicos vs Equipos**

Las **botoneras NO están asignadas a equipos**. Cada botonera tiene 2 botones físicos (A y B) que envían comandos genéricos. Es la **aplicación Flutter** quien mapea estos botones a los equipos blue/red según la configuración del partido.

```
Botonera (ESP32)
├── Botón A (físico) → Envía comando 'a'
└── Botón B (físico) → Envía comando 'b'

App Flutter recibe:
- 'a' → Punto para Team.blue (lado izquierdo)
- 'b' → Punto para Team.red (lado derecho)
```

**Ventaja**: Una misma botonera puede usarse en cualquier posición de la cancha. La app decide el mapeo.

## ✅ Verificación de la Configuración

### 1. Verificar Puertos Disponibles

Ejecuta el script de prueba:

```bash
dart run test_serial_ports.dart
```

Deberías ver algo como:

```
✅ Encontrados 1 puerto(s):

📍 Puerto: COM3
   Nombre: COM3
   Descripción: USB Serial Port
   Fabricante: FTDI
   Vendor ID: 0x0403
   Product ID: 0x6001
   ✅ Puerto se puede abrir para lectura
```

Si no aparecen puertos:
- Verifica que el módulo USB-RS485 esté conectado
- Instala los drivers apropiados (FTDI, CH340, etc.)
- Revisa el Administrador de Dispositivos en Windows

---

## 🔧 Configuración de Dispositivos ESP32

### **NO se necesita configuración de equipos en la app**

A diferencia de BLE, con RS-485 **no hay "pairing" de dispositivos por equipo**. Las botoneras simplemente envían:
- **Botón A** → Comando `'a'`
- **Botón B** → Comando `'b'`

La app mapea automáticamente:
- `'a'` → **Team Blue** (equipo izquierdo)
- `'b'` → **Team Red** (equipo derecho)

### ¿Cómo configurar el firmware ESP32?

Cada ESP32 debe tener un **Device ID único** (16 bits) para evitar colisiones en el bus RS-485.

1. **Método 1**: Si usas el ID de MAC WiFi:
   ```cpp
   // En tu firmware ESP32:
   uint64_t mac = ESP.getEfuseMac();
   uint16_t devId = (uint16_t)(mac & 0xFFFF); // Últimos 2 bytes de MAC
   ```

2. **Método 2**: ID hardcodeado en firmware:
   ```cpp
   // Configura un ID único para cada botonera
   const uint16_t DEVICE_ID = 0x0001; // Para ESP32 #1
   const uint16_t DEVICE_ID = 0x0002; // Para ESP32 #2
   const uint16_t DEVICE_ID = 0x0003; // Para ESP32 #3
   ```

3. **Método 3**: Configurado en EEPROM/Preferences:
   ```cpp
   Preferences prefs;
   prefs.begin("config", true);
   uint16_t devId = prefs.getUShort("devId", 0x0001);
   ```

---

## 📡 Formato de Paquete Serial (10 bytes)

```
Byte  | Campo    | Valor                | Descripción
------|----------|----------------------|---------------------------
0     | Header1  | 'P' (0x50)          | Inicio de paquete
1     | Header2  | 'S' (0x53)          | Confirmación inicio
2     | Version  | 0x01                | Versión de protocolo
3     | DevID_Lo | 0x00-0xFF           | Byte bajo del Device ID
4     | DevID_Hi | 0x00-0xFF           | Byte alto del Device ID
5     | Type     | 'C' (0x43)          | Tipo: Comando
6     | Command  | 'p'/'u'/'g'         | Comando (ver abajo)
7     | Sequence | 0x00-0xFF           | Número de secuencia
8     | CRC_Lo   | 0x00-0xFF           | Byte bajo del CRC16-CCITT
9     | CRC_Hi   | 0x00-0xFF           | Byte alto del CRC16-CCITT
```

### Comandos Soportados:

| Comando | Valor ASCII | Acción                                |
|---------|-------------|---------------------------------------|
| `'a'`   | 0x61        | **Botón A** → Punto para Team Blue    |
| `'b'`   | 0x62        | **Botón B** → Punto para Team Red     |
| `'u'`   | 0x75        | Undo (deshacer último punto)          |
| `'g'`   | 0x67        | Game restart (reiniciar partido)      |

**Ejemplo de uso en la cancha:**
- Botonera en lado izquierdo: Jugadores presionan **Botón A** → Team Blue gana punto
- Botonera en lado derecho: Jugadores presionan **Botón B** → Team Red gana punto
- Árbitro puede usar **Botón U** (undo) desde cualquier botonera

---

## 🧪 Prueba Manual con Simulador Serial

### Opción 1: Com0Com (Windows)

1. Instala [com0com](https://sourceforge.net/projects/com0com/)
2. Crea un par de puertos virtuales: COM10 ↔ COM11
3. La app Flutter escucha en COM10
4. Tú envías datos de prueba desde COM11

### Opción 2: Hyperterminal / Putty

Conecta al puerto COM del USB-RS485 y envía bytes manualmente:

```
50 53 01 01 00 43 70 2A XX XX
```

Donde `XX XX` es el CRC16-CCITT calculado sobre los primeros 8 bytes.

### Opción 3: Script Python

```python
import serial
import struct

def crc16_ccitt(data):
    crc = 0xFFFF
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            if crc & 0x8000:
                crc = ((crc << 1) ^ 0x1021) & 0xFFFF
            else:
                crc = (crc << 1) & 0xFFFF
    return crc

# Construir paquete para BOTÓN A (lado izquierdo)
dev_id = 0x0001  # ESP32 #1
cmd = ord('a')   # Botón A → Team Blue
seq = 42         # Secuencia

packet = bytes([
    0x50, 0x53,           # 'P' 'S'
    0x01,                 # Versión
    dev_id & 0xFF,        # DevID bajo
    (dev_id >> 8) & 0xFF, # DevID alto
    0x43,                 # 'C'
    cmd,                  # Comando 'a'
    seq                   # Secuencia
])

crc = crc16_ccitt(packet)
packet += bytes([crc & 0xFF, (crc >> 8) & 0xFF])

# Enviar por serial
ser = serial.Serial('COM3', 115200)
ser.write(packet)
ser.close()

print(f"✅ Enviado botón A: {packet.hex(' ')}")

# Para probar BOTÓN B (lado derecho), cambiar:
# cmd = ord('b')  # Botón B → Team Red
```

---

## 🔍 Monitoreo de Debug

La app Flutter imprime logs en consola cuando recibe mensajes:

```
[SERIAL] ✅ Conectado a COM3 @ 115200 baud
[SERIAL] ✅ Comando: p:blue:42 (dev=0x0001, team=blue)
[MAIN] Punto para blue (seq: 42)
```

Si no recibes mensajes, verifica:

1. **Puerto correcto**: ¿La app abrió el puerto correcto?
2. **Baudrate**: Debe ser 115200 en ambos lados
3. **CRC válido**: Calcula correctamente el CRC16-CCITT
4. **Dispositivo pareado**: El Device ID debe estar en `knownDevices`
5. **Formato de paquete**: Verifica que sean exactamente 10 bytes con 'P' 'S' al inicio

---

## 🐛 Troubleshooting

### "No hay puertos disponibles"
- ✅ Conecta el módulo USB-RS485
- ✅ Instala drivers del fabricante
- ✅ Verifica en Administrador de Dispositivos

### "CRC inválido"
- ✅ Verifica que el CRC se calcule sobre los primeros 8 bytes
- ✅ Usa polinomio 0x1021 con init 0xFFFF
- ✅ Orden: CRC_Lo, CRC_Hi (little-endian)

### "Dispositivo no pareado"
- ✅ Verifica que el Device ID esté en `knownDevices` en main.dart
- ✅ Imprime el Device ID recibido en debug
- ✅ Confirma que ESP32 use el mismo ID

### "Punto ignorado (cooldown)"
- ⏰ Normal: hay cooldown de 4 segundos entre puntos del mismo dispositivo
- ⚠️  Si necesitas más rapidez, reduce `_pointCooldownUs` en padel_serial_client.dart

### "Stream cerrado" o "Desconectado"
- 🔄 La app reintenta reconectar cada 3 segundos automáticamente
- ✅ Verifica que el cable USB no esté suelto
- ✅ Revisa los logs: puede ser un problema de alimentación del ESP32

---

## ✅ Checklist de Producción

Antes de desplegar en el TV Box:

- [ ] Drivers USB-RS485 instalados
- [ ] Puertos detectados con `test_serial_ports.dart`
- [ ] Device IDs configurados en firmware ESP32
- [ ] Device IDs agregados a `knownDevices` en main.dart
- [ ] Baudrate 115200 en firmware y app
- [ ] CRC16-CCITT calculado correctamente en firmware
- [ ] Paquete de 10 bytes con header 'P' 'S'
- [ ] Resistencias de 120Ω instaladas en ambos extremos del bus
- [ ] Cable de 60m pasa por todas las botoneras
- [ ] Tap-offs a ESP32 son cortos (<30cm)
- [ ] Probado recepción de mensajes en debug
- [ ] Probado cooldown de 4 segundos funciona
- [ ] Probado comandos 'p', 'u', 'g'

---

## 📞 Soporte

Si sigues teniendo problemas:

1. Ejecuta `test_serial_ports.dart` y comparte la salida
2. Comparte los logs de Flutter cuando presionas un botón físico
3. Verifica con un analizador lógico o osciloscopio las señales A+/B-
4. Prueba con un único ESP32 primero antes de conectar los 3
