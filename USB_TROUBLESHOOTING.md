# 🔧 Guía de Troubleshooting - Sistema USB Serial

## Resumen del Sistema

```
┌─────────────┐     RS-485      ┌────────────┐     USB      ┌─────────────┐
│  Botoneras  │ ◄────────────► │   ESP32    │ ◄──────────► │  App Puntazo │
│  (Esclavos) │                │  (Master)   │   Serial    │  (Android)   │
└─────────────┘                └────────────┘              └─────────────┘
```

---

## 🚦 Estados del Indicador USB (esquina superior izquierda)

| Color | Estado | Significado |
|-------|--------|-------------|
| 🔴 Rojo | Sin dispositivo | No se detecta ningún USB conectado |
| 🟠 Naranja | Dispositivo encontrado | USB detectado, intentando conectar |
| 🟡 Amarillo | Conectado sin datos | Conectado pero no llegan datos del ESP32 |
| 🔵 Azul | Recibiendo datos | Llegan datos pero no son comandos válidos |
| 🟢 Verde | Operativo | Sistema funcionando, comandos procesados |

**Toca el indicador** para expandir y ver más detalles.

---

## 🔍 Diagnóstico por Síntoma

### ❌ Indicador ROJO - "Sin dispositivo USB"

**Causas posibles:**
1. Cable USB no conectado
2. Cable USB defectuoso (solo carga, no datos)
3. ESP32 apagado o sin alimentación
4. Puerto USB del tablet/TV box dañado

**Soluciones:**
1. ✅ Verifica que el cable está bien conectado en ambos extremos
2. ✅ Prueba con otro cable USB (asegúrate que sea de DATOS)
3. ✅ Verifica que el LED del ESP32 está encendido
4. ✅ Prueba otro puerto USB del dispositivo Android
5. ✅ Reinicia la app Puntazo

---

### 🟠 Indicador NARANJA - "Dispositivo encontrado"

**Significado:** El USB fue detectado pero no se pudo establecer conexión serial.

**Causas posibles:**
1. Permisos USB no otorgados
2. Otro app usando el puerto serial
3. Driver USB no compatible

**Soluciones:**
1. ✅ Cuando aparezca el diálogo de permisos USB, selecciona **"Permitir"**
2. ✅ Marca la casilla "Usar por defecto para este dispositivo"
3. ✅ Cierra otras apps que puedan usar USB (terminales serie, etc.)
4. ✅ Desconecta y reconecta el cable USB

---

### 🟡 Indicador AMARILLO - "Conectado sin datos"

**Significado:** Conexión USB establecida pero el ESP32 no envía datos.

**Causas posibles:**
1. ESP32 no tiene el firmware correcto cargado
2. ESP32 colgado o en error
3. Baudrate incorrecto
4. Problema con el cable/conexión intermitente

**Soluciones:**
1. ✅ **Reinicia el ESP32** (botón RESET o desconecta/reconecta alimentación)
2. ✅ Verifica que el firmware `maestroESP32_Serial.ino` está cargado
3. ✅ Conecta el ESP32 a una PC con Arduino IDE y abre el **Monitor Serie** a 115200 baud
   - Deberías ver mensajes como `[INFO] PadelMaster RS485 -> USB`
4. ✅ Si no ves mensajes, recarga el firmware

---

### 🔵 Indicador AZUL - "Recibiendo datos"

**Significado:** Llegan datos del ESP32 pero no se reconocen como comandos válidos.

**Causas posibles:**
1. Los datos son mensajes de debug `[INFO]`, `[DBG]`, etc.
2. Los botones no están enviando comandos
3. Problema con la comunicación RS-485 entre Master y Esclavos

**Soluciones:**
1. ✅ Presiona un botón físico y observa si el indicador cambia a verde
2. ✅ Expande el panel de diagnóstico para ver los logs
3. ✅ Si ves `[RS485] dev=0x0201 cmd='p'` pero no se suma el punto:
   - El ESP32 recibe del botón pero hay un problema parseando
4. ✅ Si NO ves mensajes `[RS485]`:
   - El problema está en la comunicación RS-485 (revisar cableado)

---

### 🟢 Indicador VERDE - "Operativo"

**Significado:** ¡Todo funciona! Los comandos se procesan correctamente.

El contador al lado muestra cuántos comandos se han procesado.

---

## 📋 Checklist de Verificación

### Antes de probar:
- [ ] ESP32 encendido (LED visible)
- [ ] Cable USB conectado entre ESP32 y tablet/TV box
- [ ] App Puntazo abierta
- [ ] Permisos USB otorgados

### Al probar botones:
- [ ] Indicador cambia a verde al presionar
- [ ] Contador de comandos incrementa
- [ ] El marcador refleja el punto sumado

---

## 🔌 Comandos que envía el ESP32

| Comando | Acción en la App |
|---------|-----------------|
| `P_A` | Punto para Equipo Azul |
| `P_B` | Punto para Equipo Rojo |
| `UNDO_A` | Deshacer último punto Equipo Azul |
| `UNDO_B` | Deshacer último punto Equipo Rojo |
| `RESET` | Reiniciar partido |

---

## 🛠️ Herramientas de Debug

### 1. Panel de Diagnóstico (en la app)
- Toca el indicador USB en la esquina superior izquierda
- Muestra estadísticas: bytes recibidos, comandos, errores
- Muestra los últimos mensajes del log

### 2. Página de Test USB
- Toca el botón naranja 🔶 (icono USB) en la esquina superior derecha
- Vista completa de dispositivos USB detectados
- Log detallado de comunicación
- Permite enviar comandos de prueba al ESP32

### 3. Monitor Serie de Arduino (en PC)
- Conecta el ESP32 a la PC
- Abre Arduino IDE > Herramientas > Monitor Serie
- Configura 115200 baud
- Deberías ver:
  ```
  [INFO] ================================
  [INFO]   PadelMaster RS485 -> USB
  [INFO]   Puntazo App Compatible
  [INFO] ================================
  [READY] Esperando comandos...
  ```
- Al presionar botones deberías ver:
  ```
  [RS485] dev=0x0201 cmd='p' rtt=45 ms
  P_A
  ```

---

## ⚠️ Problemas Comunes y Soluciones Rápidas

| Problema | Solución Rápida |
|----------|----------------|
| Indicador siempre rojo | Cambiar cable USB por uno de DATOS |
| Se conecta y desconecta solo | Cable flojo o defectuoso |
| Puntos se suman doble | Ajustar DEBOUNCE_MS en firmware (aumentar a 300-500) |
| Un botón no funciona | Revisar conexión RS-485 de ese esclavo |
| Todos los botones no funcionan | Revisar alimentación de la red RS-485 |

---

## 📞 Información para Reportar Problemas

Cuando reportes un problema, incluye:

1. **Color del indicador USB** cuando ocurre el problema
2. **Últimos mensajes** del panel de diagnóstico expandido
3. **Qué acción** estabas realizando
4. **Qué esperabas** que pasara vs qué pasó realmente

Si tienes acceso al ESP32 con Arduino IDE:
- Captura de pantalla del **Monitor Serie**
- Mensajes que aparecen al presionar botones
