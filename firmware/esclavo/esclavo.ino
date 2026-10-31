// ==============================
// PadelSlave_RS485_9600_min_debug
// ==============================
//
// El MISMO fichero sirve para todas las cajas, sin editar nada: el ID de cada
// caja sale de su MAC de fabrica (ver DEV_ID). El maestro aprende las cajas
// cuando alguien las pulsa (ver "Descubrimiento" en docs/protocol/README.md).

#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_VL6180X.h>
#include "driver/uart.h"
#include <esp_task_wdt.h>

// ===== Watchdog =====
// Si el loop se cuelga (p. ej. el bus I2C del ToF bloqueado, o el UART) la
// placa se reinicia sola en vez de quedarse muda hasta que alguien la
// desenchufe. 5 s es mucho mas que una vuelta normal del loop.
static const uint32_t WDT_TIMEOUT_MS = 5000;

static void startWatchdog() {
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  esp_task_wdt_config_t cfg = {
    .timeout_ms = WDT_TIMEOUT_MS,
    .idle_core_mask = 0,
    .trigger_panic = true,
  };
  // El core 3.x ya arranca el watchdog: se reconfigura. Si no, se crea.
  if (esp_task_wdt_reconfigure(&cfg) != ESP_OK) esp_task_wdt_init(&cfg);
#else
  esp_task_wdt_init(WDT_TIMEOUT_MS / 1000, true);
#endif
  esp_task_wdt_add(NULL);  // vigila la tarea del loop
}

// Sin oir al maestro en este tiempo (ni preguntas a esta caja ni la pregunta
// general), la caja se reinicia: es lo mismo que haria el cliente
// desenchufando. Mientras el maestro funciona no pasa nunca: pregunta varias
// veces por segundo. Con el maestro apagado se reinicia en bucle, sin dano.
static const uint32_t NO_POLL_RESTART_MS = 10000;
static uint32_t lastHeardMs = 0;

// Si el maestro no pregunta por esta caja en este tiempo, es que no la
// conoce: entonces, y solo si se ha pulsado un boton, contesta a la pregunta
// general. Una caja conocida y conectada recibe preguntas cada ~80 ms.
static const uint32_t UNKNOWN_AFTER_MS = 1500;
static uint32_t lastOwnPollMs = 0;

// ===== DEBUG (desactivado) =====
#define DEBUG_SLAVE 0
#define DEBUG_TOF 0
#if DEBUG_SLAVE
  #define DBG(...) Serial.printf(__VA_ARGS__)
#else
  #define DBG(...)
#endif

// ===== Identidad =====
// Los 2 ultimos bytes de la MAC de fabrica, que es unica por chip. Las placas
// de un mismo lote tienen MAC consecutivas, asi que no se repiten en la
// practica. Se calcula en setup().
static uint16_t DEV_ID = 0;

// ID reservado para la pregunta general del maestro (descubrimiento).
static const uint16_t BROADCAST_ID = 0xFFFF;
static const uint8_t  REQ_POLL     = 0x01;
static const uint8_t  REQ_DISCOVER = 0x02;

static uint16_t deviceIdFromMac() {
  uint64_t mac = ESP.getEfuseMac();  // byte 0 de la MAC en los bits bajos
  uint16_t id = (uint16_t)((((mac >> 32) & 0xFF) << 8) | ((mac >> 40) & 0xFF));
  // 0x0000 no es un ID util y 0xFFFF es la pregunta general.
  if (id == 0x0000 || id == BROADCAST_ID) id ^= 0x5A5A;
  return id;
}

// ===== Botones =====
#define BTN_P 5
#define BTN_U 6
#define BTN_G 7

// BotÃ³n a GND => activo LOW con INPUT_PULLUP
#define BTN_ACTIVE_LOW 1

// Debounce igual que BLE
static const unsigned long DEBOUNCE_MS = 80;
static int lastP, lastU, lastG;
static unsigned long tP = 0, tU = 0, tG = 0;

// === ANTI-DOBLE PUNTO GLOBAL: 0,5 s entre puntos (el sonido de la app ya confirma el punto) ===
static const uint32_t POINT_COOLDOWN_MS = 500;
static uint32_t lastPointMs = 0;

// ===== RS-485 (UART1 ESP32-C3) =====
#define RS485_TX_PIN 4
#define RS485_RX_PIN 10
#define RS485_EN_PIN 1
#define RS485_RX_INVERT 0
HardwareSerial RS485(1);
#define RS485_BAUD   9600
static const uint32_t RS485_POST_TX_US = 200;
static const uint32_t RS485_SLAVE_REPLY_DELAY_US = 1500;

// ===== ToF =====
Adafruit_VL6180X TOF;
bool tofReady = false;

// === Tuning ToF ===
// El ToF no puede distinguir tapa vs paleta si quedan a la misma distancia.
// Por eso se clasifica por patron temporal:
// - toque corto y liberacion: paleta, suma punto al soltar
// - objeto que queda puesto: tapa, bloquea puntos hasta retirarla
static const uint16_t TOF_COVER_MAX_MM          = 8;
static const uint16_t TOF_COVER_RELEASE_MM      = 35;
static const uint16_t TOF_COVER_HOLD_MS         = 2500;
static const uint16_t TOF_COVER_RELEASE_HOLD_MS = 400;
static const uint16_t TOF_POINT_MIN_MM          = 10;
static const uint16_t TOF_POINT_MAX_MM          = 180;
static const uint16_t TOF_RELEASE_MM            = 230;
static const uint16_t TOF_HOLD_MS               = 700;
static const uint16_t TOF_RELEASE_HOLD          = 300;
static const uint16_t TOF_COOLDOWN_MS           = 2000;
static const uint16_t TOF_MAX_MOTION            = 40;
static const uint16_t TOF_INVALID_GRACE_MS      = 180;
static const uint16_t TOF_BUTTON_INHIBIT_MS     = 1200;
static const uint16_t TOF_SAMPLE_MS             = 40;    // ~25 Hz

// Estado ToF igual que en el BLE
struct {
  uint32_t enterMs      = 0;
  uint32_t lastFireMs   = 0;
  uint32_t lastSampleMs = 0;
  uint32_t coverSinceMs = 0;
  uint32_t coverClearSinceMs = 0;
  uint32_t lastNearMs = 0;
  uint16_t lastDist     = 0;
  bool     armed        = true;
  bool     covered      = false;
  bool     touchActive  = false;
} tofState;

static uint32_t tofInhibitUntilMs = 0;

static inline bool tofIsInhibited(uint32_t nowMs) {
  return (int32_t)(tofInhibitUntilMs - nowMs) > 0;
}

static void inhibitToFForButton(uint32_t nowMs) {
  tofInhibitUntilMs = nowMs + TOF_BUTTON_INHIBIT_MS;
  tofState.touchActive = false;
  tofState.enterMs = 0;
  tofState.lastNearMs = 0;
}

// ===== pendingCmd =====
static volatile char pendingCmd = 'n';
static uint32_t lastPollLogMs = 0;
static uint32_t lastRs485DebugLogMs = 0;
static uint32_t rs485RxBytes = 0;
static uint32_t rs485StartBytes = 0;
static uint32_t rs485Frames = 0;
static uint32_t rs485CrcErrors = 0;
static uint32_t rs485WrongId = 0;
static uint32_t rs485Replies = 0;
static uint8_t lastRs485Byte = 0;
#if DEBUG_TOF
static uint32_t lastTofDebugLogMs = 0;
#endif

static bool initToF() {
  for (uint8_t attempt = 1; attempt <= 20; ++attempt) {
    if (TOF.begin()) {
      Serial.printf("VL6180X OK (ToF habilitado, intento %u).\n",
                    (unsigned)attempt);
      return true;
    }
    delay(250);
  }

  Serial.println("VL6180X no encontrado (solo botones).");
  return false;
}

static inline void rs485ReceiveMode() {
  digitalWrite(RS485_EN_PIN, LOW);
  delayMicroseconds(50);
}

static inline void rs485TransmitMode() {
  digitalWrite(RS485_EN_PIN, HIGH);
  delayMicroseconds(50);
}

static void rs485WriteFrame(const uint8_t* data, size_t len) {
  rs485TransmitMode();
  RS485.write(data, len);
  RS485.flush();
  delayMicroseconds(RS485_POST_TX_US);
  rs485ReceiveMode();
}

static void logRs485Debug() {
  uint32_t now = millis();
  if (now - lastRs485DebugLogMs < 2000) return;
  lastRs485DebugLogMs = now;
  Serial.printf("[RS485 DBG] rxBytes=%lu startA0=%lu frames=%lu crcErr=%lu wrongId=%lu replies=%lu last=0x%02X\n",
                (unsigned long)rs485RxBytes,
                (unsigned long)rs485StartBytes,
                (unsigned long)rs485Frames,
                (unsigned long)rs485CrcErrors,
                (unsigned long)rs485WrongId,
                (unsigned long)rs485Replies,
                lastRs485Byte);
}

// ===== CRC16-CCITT =====
static uint16_t crc16_ccitt(const uint8_t* data, size_t len) {
  uint16_t crc = 0xFFFF;
  for (size_t i = 0; i < len; ++i) {
    crc ^= (uint16_t)data[i] << 8;
    for (int b = 0; b < 8; ++b) {
      if (crc & 0x8000)
        crc = (uint16_t)((crc << 1) ^ 0x1021);
      else
        crc = (uint16_t)(crc << 1);
    }
  }
  return crc;
}

// ===== Helpers botones =====
static inline bool isPressedLevel(int level) {
  return BTN_ACTIVE_LOW ? (level == LOW) : (level == HIGH);
}

static inline bool edgeChanged(int pin, int &last, unsigned long &tMark, int &newState) {
  int st = digitalRead(pin);
  unsigned long now = millis();
  if (st != last && (now - tMark) > DEBOUNCE_MS) {
    tMark = now;
    last = st;
    newState = st;
    return true;
  }
  return false;
}

// ===== Botones con misma lÃ³gica que BLE =====
static void pollButtons() {
  int newSt;

  // --- BTN P: POINT con cooldown global ---
  if (edgeChanged(BTN_P, lastP, tP, newSt)) {
    if (isPressedLevel(newSt)) {
      uint32_t now = millis();
      inhibitToFForButton(now);
      if (now - lastPointMs >= POINT_COOLDOWN_MS) {
        pendingCmd = 'p';
        lastPointMs = now;
        // Solo log cuando se acepta el comando
        Serial.printf("[CMD] src=BTN_P cmd='p' t=%lu ms\n", (unsigned long)now);
      }
    }
  }

  // --- BTN U: UNDO (sin cooldown global) ---
  if (edgeChanged(BTN_U, lastU, tU, newSt)) {
    if (isPressedLevel(newSt)) {
      uint32_t now = millis();
      inhibitToFForButton(now);
      pendingCmd = 'u';
      Serial.printf("[CMD] src=BTN_U cmd='u' t=%lu ms\n", (unsigned long)now);
    }
  }

  // --- BTN G: START/RESTART (sin cooldown global) ---
  if (edgeChanged(BTN_G, lastG, tG, newSt)) {
    if (isPressedLevel(newSt)) {
      uint32_t now = millis();
      inhibitToFForButton(now);
      pendingCmd = 'g';
      Serial.printf("[CMD] src=BTN_G cmd='g' t=%lu ms\n", (unsigned long)now);
    }
  }
}

// ===== ToF con misma lÃ³gica que BLE =====
static void pollToF() {
  if (!tofReady) return;

  const uint32_t nowMs = millis();
  if (nowMs - tofState.lastSampleMs < TOF_SAMPLE_MS) return;
  tofState.lastSampleMs = nowMs;

  uint16_t d  = TOF.readRange();
  uint8_t  st = TOF.readRangeStatus();

  static uint16_t dPrev = 0xFFFF;
  static uint32_t farSinceMs = 0;
  static uint32_t lastInZoneMs = 0;

  bool valid             = (st == 0);
  bool coverReading      = valid && (d <= TOF_COVER_MAX_MM);
  bool coverClearReading = (!valid) || (d >= TOF_COVER_RELEASE_MM);
  bool inZone            = valid &&
                           !coverReading &&
                           (d >= TOF_POINT_MIN_MM) &&
                           (d <= TOF_POINT_MAX_MM);
  bool farZone           = (!valid) ||
                           (d >= TOF_RELEASE_MM) ||
                           coverReading;

#if DEBUG_TOF
  if (nowMs - lastTofDebugLogMs >= 200) {
    lastTofDebugLogMs = nowMs;
    const char* zone = "invalid";
    if (valid) {
      if (coverReading) {
        zone = "tapa";
      } else if (inZone) {
        zone = "paleta";
      } else if (d < TOF_POINT_MIN_MM) {
        zone = "ambigua";
      } else if (d >= TOF_RELEASE_MM) {
        zone = "libre";
      } else {
        zone = "transicion";
      }
    }
    Serial.printf("[TOF DBG] d=%u st=%u zone=%s covered=%u armed=%u\n",
                  (unsigned)d, (unsigned)st, zone,
                  tofState.covered ? 1 : 0,
                  tofState.armed ? 1 : 0);
  }
#endif

  if (coverReading) {
    tofState.coverClearSinceMs = 0;
    if (tofState.coverSinceMs == 0) {
      tofState.coverSinceMs = nowMs;
    }

    tofState.enterMs = 0;
    farSinceMs = 0;

    if (!tofState.covered &&
        (nowMs - tofState.coverSinceMs) >= TOF_COVER_HOLD_MS) {
      tofState.covered = true;
      tofState.armed = false;
      Serial.printf("[TOF] tapa detectada t=%lu ms d=%u\n",
                    (unsigned long)nowMs, (unsigned)d);
    }
  } else {
    tofState.coverSinceMs = 0;
  }

  if (tofState.covered) {
    if (coverClearReading) {
      if (tofState.coverClearSinceMs == 0) {
        tofState.coverClearSinceMs = nowMs;
      }
      if ((nowMs - tofState.coverClearSinceMs) >= TOF_COVER_RELEASE_HOLD_MS) {
        tofState.covered = false;
        tofState.armed = true;
        tofState.enterMs = 0;
        farSinceMs = 0;
        Serial.printf("[TOF] tapa liberada t=%lu ms d=%u st=%u\n",
                      (unsigned long)nowMs, (unsigned)d, (unsigned)st);
      }
    } else {
      tofState.coverClearSinceMs = 0;
    }

    if (valid) {
      dPrev = d;
      tofState.lastDist = d;
    }
    return;
  }

  // Una lectura de tapa bloquea de inmediato, aun antes de confirmar el log.
  if (coverReading) {
    if (valid) {
      dPrev = d;
      tofState.lastDist = d;
    }
    return;
  }
  if (tofState.armed) {
    if (inZone) {
      lastInZoneMs = nowMs;
      if (tofState.enterMs == 0) {
        tofState.enterMs = nowMs;
      }

      if (valid && dPrev != 0xFFFF) {
        int16_t delta = (int16_t)d - (int16_t)dPrev;
        if (abs(delta) > TOF_MAX_MOTION) {
          tofState.enterMs = nowMs;
        }
      }

      if ((nowMs - tofState.enterMs) >= TOF_HOLD_MS &&
          (nowMs - tofState.lastFireMs) >= TOF_COOLDOWN_MS) {

        if (nowMs - lastPointMs >= POINT_COOLDOWN_MS) {
          pendingCmd = 'p';
          tofState.lastFireMs = nowMs;
          lastPointMs = nowMs;
          tofState.armed = false;
          farSinceMs = 0;

          // Solo log cuando realmente dispara punto
          Serial.printf("[CMD] src=ToF   cmd='p' t=%lu ms d=%u\n",
                        (unsigned long)nowMs, (unsigned)d);
        } else {
          // Bloqueado por cooldown global -> no logueamos para no spamear
          tofState.enterMs = nowMs; // reinicia hold para futuro disparo
        }
      }
    } else if (tofState.enterMs != 0 &&
               !coverReading &&
               (nowMs - lastInZoneMs) <= TOF_INVALID_GRACE_MS) {
      // Mantiene vivo el apoyo si hay un corte breve de lectura por angulo/color.
    } else {
      tofState.enterMs = 0;
    }
  } else {
    // Ya disparÃ³: esperar que se aleje para rearmar
    if (farZone) {
      if (farSinceMs == 0) {
        farSinceMs = nowMs;
      }
      if ((nowMs - farSinceMs) >= TOF_RELEASE_HOLD &&
          (nowMs - tofState.lastFireMs) >= TOF_COOLDOWN_MS) {
        tofState.armed = true;
        tofState.enterMs = 0;
        farSinceMs = 0;
      }
    } else {
      farSinceMs = 0;
    }
  }

  if (valid) {
    dPrev = d;
    tofState.lastDist = d;
  }
}

// Modo recomendado cuando tapa y paleta quedan a distancia parecida:
// clasifica por duracion y manda el punto al retirar la paleta.
static void pollToFReleaseMode() {
  if (!tofReady) return;

  const uint32_t nowMs = millis();
  if (nowMs - tofState.lastSampleMs < TOF_SAMPLE_MS) return;
  tofState.lastSampleMs = nowMs;

  uint16_t d = TOF.readRange();
  uint8_t st = TOF.readRangeStatus();

  static uint16_t dPrev = 0xFFFF;
  static uint32_t farSinceMs = 0;

  bool valid = (st == 0);
  bool coverDistance = valid && (d <= TOF_COVER_MAX_MM);
  bool inPointWindow = valid && (d >= TOF_POINT_MIN_MM) && (d <= TOF_POINT_MAX_MM);
  bool nearReading = coverDistance || inPointWindow;
  bool clearReading = (!valid) || (d >= TOF_RELEASE_MM);
  bool coverClearReading = (!valid) || (d >= TOF_COVER_RELEASE_MM);
  bool anyButtonPressed =
      isPressedLevel(digitalRead(BTN_P)) ||
      isPressedLevel(digitalRead(BTN_U)) ||
      isPressedLevel(digitalRead(BTN_G));

#if DEBUG_TOF
  if (nowMs - lastTofDebugLogMs >= 200) {
    lastTofDebugLogMs = nowMs;
    const char* zone = "invalid";
    if (valid) {
      if (coverDistance) {
        zone = "muy_cerca";
      } else if (inPointWindow) {
        zone = "contacto";
      } else if (d >= TOF_RELEASE_MM) {
        zone = "libre";
      } else {
        zone = "transicion";
      }
    }
    Serial.printf("[TOF DBG] d=%u st=%u zone=%s covered=%u armed=%u\n",
                  (unsigned)d, (unsigned)st, zone,
                  tofState.covered ? 1 : 0,
                  tofState.armed ? 1 : 0);
  }
#endif

  if (anyButtonPressed) {
    inhibitToFForButton(nowMs);
  }

  if (tofIsInhibited(nowMs)) {
    tofState.touchActive = false;
    tofState.enterMs = 0;
    tofState.lastNearMs = 0;
    if (valid) {
      dPrev = d;
      tofState.lastDist = d;
    }
    return;
  }

  if (tofState.covered) {
    if (coverClearReading) {
      if (tofState.coverClearSinceMs == 0) {
        tofState.coverClearSinceMs = nowMs;
      }
      if ((nowMs - tofState.coverClearSinceMs) >= TOF_COVER_RELEASE_HOLD_MS) {
        tofState.covered = false;
        tofState.armed = true;
        tofState.touchActive = false;
        tofState.enterMs = 0;
        tofState.lastNearMs = 0;
        farSinceMs = 0;
        Serial.printf("[TOF] tapa liberada t=%lu ms d=%u st=%u\n",
                      (unsigned long)nowMs, (unsigned)d, (unsigned)st);
      }
    } else {
      tofState.coverClearSinceMs = 0;
    }

    if (valid) {
      dPrev = d;
      tofState.lastDist = d;
    }
    return;
  }

  if (tofState.armed) {
    if (nearReading) {
      tofState.lastNearMs = nowMs;
      if (!tofState.touchActive) {
        tofState.touchActive = true;
        tofState.enterMs = nowMs;
      }

      if (valid && dPrev != 0xFFFF) {
        int16_t delta = (int16_t)d - (int16_t)dPrev;
        if (abs(delta) > TOF_MAX_MOTION) {
          tofState.enterMs = nowMs;
        }
      }

      if ((nowMs - tofState.enterMs) >= TOF_COVER_HOLD_MS) {
        tofState.covered = true;
        tofState.armed = false;
        tofState.touchActive = false;
        tofState.coverClearSinceMs = 0;
        Serial.printf("[TOF] tapa detectada por permanencia t=%lu ms d=%u\n",
                      (unsigned long)nowMs, (unsigned)d);
      }
    } else if (tofState.touchActive &&
               (nowMs - tofState.lastNearMs) <= TOF_INVALID_GRACE_MS) {
      // Corte breve de lectura por angulo/color: se mantiene el toque.
    } else if (tofState.touchActive) {
      uint32_t touchMs = tofState.lastNearMs - tofState.enterMs;
      tofState.touchActive = false;

      if (touchMs >= TOF_HOLD_MS &&
          touchMs < TOF_COVER_HOLD_MS &&
          (nowMs - tofState.lastFireMs) >= TOF_COOLDOWN_MS) {
        if (nowMs - lastPointMs >= POINT_COOLDOWN_MS) {
          pendingCmd = 'p';
          tofState.lastFireMs = nowMs;
          lastPointMs = nowMs;
          tofState.armed = false;
          farSinceMs = nowMs;
          Serial.printf("[CMD] src=ToF   cmd='p' t=%lu ms touch=%lu ms d=%u\n",
                        (unsigned long)nowMs,
                        (unsigned long)touchMs,
                        (unsigned)d);
        } else {
          tofState.enterMs = 0;
        }
      } else {
        Serial.printf("[TOF] toque ignorado t=%lu ms touch=%lu ms d=%u st=%u\n",
                      (unsigned long)nowMs,
                      (unsigned long)touchMs,
                      (unsigned)d,
                      (unsigned)st);
      }
      tofState.enterMs = 0;
    }
  } else {
    if (clearReading) {
      if (farSinceMs == 0) {
        farSinceMs = nowMs;
      }
      if ((nowMs - farSinceMs) >= TOF_RELEASE_HOLD &&
          (nowMs - tofState.lastFireMs) >= TOF_COOLDOWN_MS) {
        tofState.armed = true;
        tofState.enterMs = 0;
        farSinceMs = 0;
      }
    } else {
      farSinceMs = 0;
    }
  }

  if (valid) {
    dPrev = d;
    tofState.lastDist = d;
  }
}

// ===== RS-485 parser =====
// Descarta el primer byte del buffer y busca la siguiente cabecera 0xA0
// dentro de lo ya leido. Igual que en el maestro: el ID y el CRC pueden
// contener 0xA0, asi que NO se puede reiniciar la trama al ver ese byte (una
// caja cuya pregunta lleve 0xA0 dentro no contestaria nunca).
static uint8_t resyncFrame(uint8_t* buf, uint8_t len) {
  uint8_t n = len;
  do {
    for (uint8_t i = 1; i < n; ++i) buf[i - 1] = buf[i];
    n--;
  } while (n > 0 && buf[0] != 0xA0);
  return n;
}

static void handleRs485() {
  static uint8_t buf[7];
  static uint8_t idx = 0;

  while (RS485.available() > 0) {
    uint8_t b = RS485.read();
    rs485RxBytes++;
    lastRs485Byte = b;

    if (idx == 0) {
      if (b != 0xA0) {
        continue;
      }
      rs485StartBytes++;
    }

    buf[idx++] = b;
    if (idx < 7) continue;

    // Frame completo
    rs485Frames++;

    uint8_t  devLo    = buf[1];
    uint8_t  devHi    = buf[2];
    uint8_t  req      = buf[3];
    uint16_t targetId = (uint16_t)((devHi << 8) | devLo);
    uint16_t crcRx    = (uint16_t)buf[4] | ((uint16_t)buf[5] << 8);
    uint8_t  cdat[3]  = { devLo, devHi, req };

    if (buf[0] != 0xA0 || buf[6] != 0x55 ||
        crc16_ccitt(cdat, 3) != crcRx) {
      rs485CrcErrors++;
      idx = resyncFrame(buf, 7);
      continue;
    }
    idx = 0;

    uint32_t now = millis();
    lastHeardMs = now;  // el maestro sigue vivo, pregunte a quien pregunte
    const bool own = (targetId == DEV_ID && req == REQ_POLL);
    const bool discover = (targetId == BROADCAST_ID && req == REQ_DISCOVER);
    if (!own && !discover) {
      rs485WrongId++;  // pregunta para otra caja
      continue;
    }

    if (discover) {
      // Solo contesta una caja que el maestro no conoce Y que alguien esta
      // pulsando: asi en la pregunta general no hablan dos cajas a la vez.
      if (now - lastOwnPollMs < UNKNOWN_AFTER_MS || pendingCmd == 'n') {
        continue;
      }
    } else {
      lastOwnPollMs = now;
    }

    if (now - lastPollLogMs >= 2000) {
      lastPollLogMs = now;
      Serial.printf("[RS485] poll ok DEV_ID=0x%04X t=%lu ms\n",
                    DEV_ID, (unsigned long)now);
    }

    // LEO comando pendiente
    char cmd = pendingCmd;
    pendingCmd = 'n';

    // Solo logueamos si realmente hay comando ('p','u','g')
    if (cmd == 'p' || cmd == 'u' || cmd == 'g') {
      Serial.printf("[RS485] reply cmd='%c'%s t=%lu ms\n",
                    cmd, discover ? " (descubrimiento)" : "",
                    (unsigned long)millis());
    }

    // La respuesta lleva SIEMPRE el ID propio: en el descubrimiento es como
    // el maestro se entera de quien es.
    uint8_t r[7];
    r[0] = 0xAA;
    r[1] = (uint8_t)(DEV_ID & 0xFF);
    r[2] = (uint8_t)(DEV_ID >> 8);
    r[3] = (uint8_t)cmd;

    uint8_t cdat2[3] = { r[1], r[2], r[3] };
    uint16_t c = crc16_ccitt(cdat2, 3);
    r[4] = (uint8_t)(c & 0xFF);
    r[5] = (uint8_t)(c >> 8);
    r[6] = 0x55;

    delayMicroseconds(RS485_SLAVE_REPLY_DELAY_US);
    rs485WriteFrame(r, 7);
    rs485Replies++;
  }
}

void setup() {
  Serial.begin(115200);
  uint32_t t0 = millis();
  while (!Serial && (millis() - t0 < 2000)) {
    ; // esperar un poquito al USB
  }

  delay(200);
  DEV_ID = deviceIdFromMac();
  Serial.printf("SLAVE RS-485 start, DEV_ID=0x%04X (de la MAC)\n", DEV_ID);

  pinMode(BTN_P, INPUT_PULLUP);
  pinMode(BTN_U, INPUT_PULLUP);
  pinMode(BTN_G, INPUT_PULLUP);
  pinMode(RS485_EN_PIN, OUTPUT);
  rs485ReceiveMode();

  lastP = digitalRead(BTN_P);
  lastU = digitalRead(BTN_U);
  lastG = digitalRead(BTN_G);

  Wire.begin(2, 3);
  Wire.setClock(100000);
  tofReady = initToF();

  RS485.begin(RS485_BAUD, SERIAL_8N1, RS485_RX_PIN, RS485_TX_PIN);
#if RS485_RX_INVERT
  uart_set_line_inverse(UART_NUM_1, UART_SIGNAL_RXD_INV);
#endif
  Serial.printf("RS-485 listo @%u. TX=%d RX=%d EN=%d\n",
                RS485_BAUD, RS485_TX_PIN, RS485_RX_PIN, RS485_EN_PIN);
#if RS485_RX_INVERT
  Serial.println("RS-485 RX invertido: prueba para A/B cruzados.");
#endif

  while (RS485.available()) RS485.read();

  lastHeardMs = millis();
  startWatchdog();
}

void loop() {
  esp_task_wdt_reset();
  if (millis() - lastHeardMs > NO_POLL_RESTART_MS) {
    Serial.println("Sin noticias del maestro: reiniciando.");
    delay(20);
    ESP.restart();
  }

  pollButtons();
  pollToFReleaseMode();
  handleRs485();
  logRs485Debug();
  delay(1);
}


