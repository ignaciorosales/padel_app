# 📊 Sistema de Telemetría BLE - Guía de Testing

## ✅ ¿Qué mide?

El sistema de telemetría mide la **latencia end-to-end** desde que se recibe un paquete BLE hasta que se emite el comando al Bloc:

```
[RX BLE] → [Parse] → [Dedup] → [Cooldown] → [Emit Comando] ✅
   ^                                              ^
   |_______________ LATENCIA MEDIDA ______________|
```

### Métricas disponibles:
- **Promedio (avg)**: Latencia media de todas las mediciones
- **Mínimo (min)**: Mejor caso observado
- **Máximo (max)**: Peor caso observado
- **P95**: El 95% de las mediciones están por debajo de este valor
- **Contadores por comando**: Cuántas veces se procesó cada tipo (a, b, u, g)

### Desglose de etapas:
- **Parse**: Tiempo de validación CRC y extracción de campos
- **Dedup**: Tiempo de búsqueda en queue circular (30 elementos)
- **Cooldown**: Tiempo de verificación anti-doble

---

## 🎯 Cómo testear en la app móvil

### **1. Activar el overlay de telemetría**

Envuelve tu widget principal con `BleTelemetryOverlay`:

```dart
// lib/main.dart (ejemplo)
import 'package:Puntazo/features/ble/ble_telemetry_overlay.dart';

// ... dentro de build()
return BleTelemetryOverlay(
  bleClient: _ble,
  child: MaterialApp(
    // ... tu app
  ),
);
```

### **2. Usar el overlay durante testing**

1. Presiona el botón flotante **⚡** en la esquina superior derecha
2. Verás un panel negro con estadísticas en tiempo real:
   ```
   ⚡ BLE Telemetría
   ─────────────────────────────
   Promedio:    0.85 ms
   Mínimo:      0.12 ms  
   Máximo:      3.42 ms
   P95:         1.20 ms
   Muestras:    127
   
   Comandos procesados:
   🔵 Punto Azul    45
   🔴 Punto Rojo    52
   ↩️  Undo         18
   🔄 Restart        2
   
   Últimas 5 mediciones:
   🔵 Punto Azul: 0.78ms (parse=15µs, dedup=3µs)
   🔴 Punto Rojo: 1.02ms (parse=18µs, dedup=2µs)
   ...
   ```

3. **Botón Refresh (🔄)**: Resetea todas las estadísticas para iniciar nueva medición

---

## 🧪 Escenarios de testing

### **Escenario 1: Latencia baseline (sin carga)**
**Objetivo:** Medir latencia con 1 solo dispositivo BLE, sin ruido RF

**Pasos:**
1. Parear 1 remoto BLE
2. Resetear telemetría (🔄)
3. Presionar botón P (punto) **10 veces** con ~2s entre cada uno
4. Observar métricas:
   - ✅ **Esperado:** Avg < 1ms, Max < 5ms
   - ❌ **Problema:** Avg > 2ms indica overhead excesivo

### **Escenario 2: Ráfagas (dedup stress test)**
**Objetivo:** Verificar que deduplicación funciona con múltiples paquetes

**Pasos:**
1. Presionar botón P y **mantener presionado 1 segundo**
2. Tu ESP32 emitirá 3-5 paquetes con mismo `seq`
3. Observar:
   - ✅ **Esperado:** Solo 1 comando en contador (dedup funcionando)
   - ❌ **Problema:** 3-5 comandos = dedup fallando

### **Escenario 3: Rally rápido (cooldown test)**
**Objetivo:** Simular rally de pádel con múltiples puntos rápidos

**Pasos:**
1. Alternar entre 2 mandos (azul/rojo) cada ~500ms
2. Presionar P 20 veces alternando
3. Observar:
   - ✅ **Esperado:** Todos los puntos registrados, latencia consistente
   - ❌ **Problema:** Puntos perdidos = cooldown muy agresivo

### **Escenario 4: Entorno RF ruidoso**
**Objetivo:** Medir impacto del filtro RSSI < -95

**Pasos:**
1. Alejar mandos BLE del Android TV (5-10 metros)
2. Presionar botón P 10 veces
3. Observar RSSI en logs verbose (activar `_verbose = true`)
4. Comparar:
   - ✅ **RSSI > -90:** Latencia < 1ms (señal fuerte)
   - ⚠️  **RSSI -90 a -95:** Latencia 1-3ms (aceptable)
   - ❌ **RSSI < -95:** Descartado antes de parsear (buen filtrado)

### **Escenario 5: Estrés sostenido (watchdog test)**
**Objetivo:** Verificar que app no se degrada después de horas

**Pasos:**
1. Dejar app corriendo **1 hora** con telemetría visible
2. Presionar botón P cada ~30s (simular partido)
3. Observar:
   - ✅ **Esperado:** Avg se mantiene < 1.5ms durante toda la prueba
   - ❌ **Problema:** Avg crece gradualmente = memory leak

---

## 📱 Activar logs verbose

Para debugging extremo, editar `padel_ble_client.dart`:

```dart
static const bool _verbose = true; // Cambiar de false a true
```

Esto imprimirá en consola cada medición:

```
[⚡ TELEMETRY] a | total=850µs | parse=15µs | dedup=3µs | cooldown=8µs | devId=0x1a2b
[⚡ TELEMETRY] b | total=920µs | parse=18µs | dedup=2µs | cooldown=7µs | devId=0x3c4d
```

⚠️ **Desactivar verbose en producción** (genera overhead de I/O)

---

## 🎯 Benchmarks objetivo

| Métrica | Objetivo | Aceptable | Problema |
|---------|----------|-----------|----------|
| **Avg** | < 1ms | < 2ms | > 3ms |
| **Max** | < 5ms | < 10ms | > 20ms |
| **P95** | < 1.5ms | < 3ms | > 5ms |
| **Parse** | < 20µs | < 50µs | > 100µs |
| **Dedup** | < 5µs | < 10µs | > 50µs |
| **Cooldown** | < 10µs | < 20µs | > 50µs |

---

## 🔧 Troubleshooting

### Problema: Latencias de **segundos** intermitentes
**Síntomas:** P95 > 1000ms (1 segundo)  
**Causa probable:** Android throttling BLE scan  
**Solución:** Implementar Foreground Service (notificación persistente)

### Problema: **Dobles puntos** frecuentes
**Síntomas:** Contador muestra 2x los puntos esperados  
**Causa probable:** Deduplicación fallando  
**Solución:** Verificar que `_processedSeqs` se inicializa en `pairAs()`

### Problema: Avg **crece con el tiempo**
**Síntomas:** Empieza en 0.8ms, después de 1 hora está en 5ms  
**Causa probable:** Memory leak en queue dedup o telemetría  
**Solución:** Verificar que `_maxHistory = 100` está limitando correctamente

### Problema: **Puntos perdidos** en rallies
**Síntomas:** Presiono 10 veces, solo registra 7  
**Causa probable:** Cooldown demasiado agresivo o RSSI muy bajo  
**Solución:** Ajustar `_minRssi = -100` (menos restrictivo) o `_minCmdInterval = 200ms`

---

## 📊 Exportar datos para análisis

Para análisis avanzado, puedes exportar las mediciones:

```dart
final stats = _ble.telemetry.getStats();
for (final m in stats.recentMeasurements) {
  print('${m.rxTimestampUs},${m.emitTimestampUs},${m.totalLatencyUs},${m.cmd}');
}
```

Esto genera CSV que puedes analizar en Excel/Python.

---

## ✅ Checklist de testing

- [ ] **Baseline:** Avg < 1ms con 1 dispositivo
- [ ] **Dedup:** Ráfagas no generan dobles puntos
- [ ] **Rally:** 20 puntos alternados se registran correctamente
- [ ] **RSSI:** Señales débiles se filtran (< -95 dBm)
- [ ] **Sostenido:** Latencia estable después de 1 hora
- [ ] **P95:** < 1.5ms en condiciones normales
- [ ] **Verbose off:** Sin overhead en producción

---

¿Encontraste un patrón de latencia alto? Comparte el log y analizamos juntos 🔍
