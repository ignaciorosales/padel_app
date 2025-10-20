// PadelScoreboard_Serial.ino — BLE advertising (connectionless) version
//
// Manufacturer Data (12 bytes):
// [0]  Company ID LSB (0xFF)
// [1]  Company ID MSB (0xFF)
// [2]  'P' (0x50)
// [3]  'S' (0x53)
// [4]  protoVer (0x01)
// [5]  devIdLo
// [6]  devIdHi
// [7]  'C' (0x43) frame type = Command
// [8]  cmd  ('p','u','g')
// [9]  seq  (1..255, never 0)
// [10] crcLo  (CRC16-CCITT over bytes 2..9)
// [11] crcHi

#include "Config.h"
#include "PadelRules.h"

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEAdvertising.h>
#include <WiFi.h>
#include <Preferences.h>
#include <esp_system.h>

#include <Wire.h>
#include <Adafruit_VL6180X.h>

#define BLE_DEVICE_NAME   "PadelScore-C3"
#define MFG_ID_LSB  0xFF
#define MFG_ID_MSB  0xFF
static const uint8_t PROTO_VER = 0x01;

Adafruit_VL6180X TOF;   // TOF050C (VL6180)

// === TOF tuning OPTIMIZADO ===
const uint16_t TOF_MAX_MM       = 400;   // ≤ 40 cm "dentro de zona"
const uint16_t TOF_THRESH_MM    = 400;   // umbral de detección
const uint16_t TOF_RELEASE_MM   = 500;   // debe alejarse >50cm para rearmar
const uint16_t TOF_HOLD_MS      = 600;   // 0.6s quieto antes de disparar
const uint16_t TOF_RELEASE_HOLD = 300;   // 0.3s lejos antes de rearmar
const uint16_t TOF_COOLDOWN_MS  = 2000;  // 2s anti-doble BULLET PROOF
const uint16_t TOF_MAX_MOTION   = 15;    // máx 15mm de movimiento para considerar "quieto"
const uint16_t TOF_SAMPLE_MS    = 40;    // 25 Hz para mejor respuesta

// === ANTI-DOBLE PUNTO GLOBAL: 4 segundos entre puntos ===
const uint32_t POINT_COOLDOWN_MS = 4000;  // 4s entre puntos (IMPOSIBLE marcar doble)
static uint32_t lastPointMs = 0;           // Timestamp del último punto marcado

struct {
  uint32_t enterMs      = 0;
  uint32_t lastFireMs   = 0;
  uint32_t lastSampleMs = 0;
  uint16_t lastDist     = 0;
  bool     armed        = true;
} tofState;

// ======= Estado del marcador =======
Score score;
Score history[UNDO_DEPTH];
int   histSize = 0;

static void pushHistory() {
  if (histSize >= UNDO_DEPTH) {
    for (int i = 1; i < UNDO_DEPTH; ++i) history[i-1] = history[i];
    histSize = UNDO_DEPTH - 1;
  }
  history[histSize++] = score;
}
static void popHistory() { if (histSize > 0) score = history[--histSize]; }

// ======= Botones físicos =======
#define BTN_P 5   // POINT
#define BTN_U 6   // UNDO
#define BTN_G 7   // START/RESTART

static int lastP = HIGH, lastU = HIGH, lastG = HIGH;
static unsigned long tP = 0, tU = 0, tG = 0;
static const unsigned long DEBOUNCE_MS = 80;  // Balance óptimo: respuesta rápida + anti-rebote

static inline bool edgePressed(int pin, int &last, unsigned long &tMark) {
  const int st = digitalRead(pin);
  const unsigned long now = millis();
  if (st != last && (now - tMark) > DEBOUNCE_MS) {
    tMark = now;
    last = st;
    return (st == LOW); // LOW = pulsado (INPUT_PULLUP)
  }
  return false;
}

// ======= Advertising =======
static BLEAdvertising* adv = nullptr;
static char lastCmd = 'p';                   // último comando emitido
static unsigned long lastReTx = 0;
static const unsigned long RE_TX_MS = 1000;  // reemite cada 1 s (antes 2s)
static uint8_t gSeq = 1;                     // 1..255

// Persistent unique device ID (stored in NVS flash)
static uint16_t gDeviceId = 0;
static Preferences prefs;

static inline uint16_t getOrCreateDeviceId() {
  prefs.begin("padel", false); // namespace "padel", read-write
  
  // Intentar leer devId existente
  uint16_t stored = prefs.getUShort("devId", 0);
  
  if (stored != 0) {
    // Ya existe un ID guardado - reutilizarlo
    Serial.printf("✓ DevId persistente recuperado: 0x%04X\n", stored);
    prefs.end();
    return stored;
  }
  
  // Primera vez: generar UUID único
  // Semilla con múltiples fuentes de entropía
  WiFi.mode(WIFI_MODE_STA);
  String macStr = WiFi.macAddress();
  uint8_t mac[6];
  sscanf(macStr.c_str(), "%hhx:%hhx:%hhx:%hhx:%hhx:%hhx",
         &mac[0], &mac[1], &mac[2], &mac[3], &mac[4], &mac[5]);
  WiFi.mode(WIFI_OFF);
  
  uint32_t seed = (mac[0] << 24) | (mac[1] << 16) | (mac[2] << 8) | mac[3];
  seed ^= esp_random(); // Hardware RNG del ESP32
  seed ^= millis();     // Timing boot
  randomSeed(seed);
  
  // Generar devId aleatorio (evitar 0x0000 y 0xFFFF)
  uint16_t newId;
  do {
    newId = (uint16_t)random(1, 0xFFFE); // rango 1..65534
  } while (newId == 0x0000 || newId == 0xFFFF);
  
  // Guardar permanentemente en NVS flash
  prefs.putUShort("devId", newId);
  prefs.end();
  
  Serial.printf("🆕 Nuevo devId generado y guardado: 0x%04X\n", newId);
  Serial.printf("   (WiFi MAC: %02X:%02X:%02X:%02X:%02X:%02X)\n",
    mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  
  return newId;
}

// CRC16-CCITT (poly 0x1021, init 0xFFFF)
static uint16_t crc16_ccitt(const uint8_t* data, size_t len) {
  uint16_t crc = 0xFFFF;
  for (size_t i = 0; i < len; ++i) {
    crc ^= (uint16_t)data[i] << 8;
    for (int b = 0; b < 8; ++b) {
      if (crc & 0x8000) crc = (uint16_t)((crc << 1) ^ 0x1021);
      else              crc = (uint16_t)(crc << 1);
    }
  }
  return crc;
}

// Construye y aplica el payload de advertising
static void applyAdvPayload(char cmd) {
  lastCmd = cmd;

  uint8_t p[12];
  p[0]  = MFG_ID_LSB;
  p[1]  = MFG_ID_MSB;
  p[2]  = 'P';
  p[3]  = 'S';
  p[4]  = PROTO_VER;
  p[5]  = (uint8_t)(gDeviceId & 0xFF);
  p[6]  = (uint8_t)((gDeviceId >> 8) & 0xFF);
  p[7]  = 'C';
  p[8]  = (uint8_t)cmd;  // 'p','u','g'
  p[9]  = gSeq;          // 1..255
  const uint16_t crc = crc16_ccitt(&p[2], 8); // bytes 2..9
  p[10] = (uint8_t)(crc & 0xFF);
  p[11] = (uint8_t)(crc >> 8);

  String mfg;
  mfg.reserve(sizeof(p));
  for (size_t i = 0; i < sizeof(p); ++i) mfg += (char)p[i];

  BLEAdvertisementData advData;
  advData.setManufacturerData(mfg);
  // Sin scan response ni nombre: todo va en el paquete principal (más simple)

  adv->stop();
  adv->setAdvertisementData(advData);
  adv->start();
}

// Ráfaga OPTIMIZADA: 4 paquetes con 40ms gap + STOP advertising para evitar flooding
static void sendCmdBurst(char c, int n = 4, int gapMs = 40, bool debug = false) {
  for (int i = 0; i < n; ++i) {
    gSeq = (gSeq == 255) ? 1 : (uint8_t)(gSeq + 1);
    applyAdvPayload(c);
    if (debug && i == 0) {
      Serial.printf("  [TX devId=0x%04X cmd='%c' seq=%u]\n", gDeviceId, c, gSeq);
    }
    if (i < n - 1) delay(gapMs);
  }
  
  // ▲ ANTI-FLOODING: Detener advertising después de ráfaga
  // Evita transmisión continua del mismo comando (ahorro energía + reduce ruido BLE)
  delay(50); // Dar tiempo a que salgan los últimos paquetes
  adv->stop();
}

// Inicializa BLE "beacon" con máxima potencia e intervalos agresivos
static void setupBroadcast() {
  BLEDevice::init(BLE_DEVICE_NAME);

  // ▲ POTENCIA MÁXIMA: +9 dBm en ESP32-C3 (alcance máximo)
  BLEDevice::setPower(ESP_PWR_LVL_P9);

  adv = BLEDevice::getAdvertising();

  // ▲ Sin scan response: menos overhead, captura más simple
  adv->setScanResponse(false);

  // ▲ Intervalos BLE 5.0 AGRESIVOS: 40-50 ms para máxima captura
  //   64 = 40ms  /  80 = 50ms (unidades de 0.625ms)
  adv->setMinInterval(64);
  adv->setMaxInterval(80);
  
  // ▲ Advertising no-conectable: más eficiente (implícito en advertising beacon)

  applyAdvPayload('p'); // estado neutro
  
  // ▲ ANTI-FLOODING: Iniciar detenido, solo transmitir en ráfagas
  adv->stop();
}

// ======= Serial helpers =======
static void printHelp() {
  Serial.println(F("Comandos por Serial: p u g s r (h=ayuda)"));
  Serial.println(F("p: POINT (solo transmite)"));
  Serial.println(F("u: UNDO  (solo transmite)"));
  Serial.println(F("g: START/RESTART GAME (resetea juego local y transmite)"));
  Serial.println(F("s: ver estado local"));
  Serial.println(F("r: REGENERAR devId (borra y crea nuevo UUID)"));
}

static void regenerateDevId() {
  prefs.begin("padel", false);
  prefs.remove("devId");
  prefs.end();
  Serial.println(F("❌ DevId borrado - reinicia el ESP32 para generar nuevo UUID"));
  delay(1000);
  ESP.restart();
}

static void printScoreboard(const Score &s) {
  char pA[8], pB[8];
  formatPointStr(s, pA, pB, sizeof(pA));
  Serial.println(F("----------------------------------------------"));
  Serial.print (F(" Equipos: ")); Serial.print(TEAM_A_NAME);
  Serial.print (F("  vs  "));     Serial.println(TEAM_B_NAME);
  Serial.printf(" Sets     |  A:%u   B:%u\n", s.setsA, s.setsB);
  Serial.printf(" Juegos   |  A:%u   B:%u\n", s.gamesA, s.gamesB);
  Serial.print(F(" Puntos   |  "));
  if (s.tieBreak) Serial.printf("TB %s-%s\n", pA, pB);
  else if (isDeuce(s)) Serial.println(F("Deuce"));
  else if (advA(s))    Serial.println(F("Ad A"));
  else if (advB(s))    Serial.println(F("Ad B"));
  else                 Serial.printf("%s-%s\n", pA, pB);
  if (s.matchOver) Serial.println(F(" *** PARTIDO FINALIZADO ***"));
  Serial.println(F("----------------------------------------------"));
}

// ======= Arduino setup/loop =======
void setup() {
  WiFi.mode(WIFI_OFF);
  Serial.begin(115200);
  unsigned long t0 = millis();
  while (!Serial && (millis() - t0 < 2000)) { delay(10); }

  setCpuFrequencyMhz(80);
  gDeviceId = getOrCreateDeviceId();

  pinMode(BTN_P, INPUT_PULLUP);
  pinMode(BTN_U, INPUT_PULLUP);
  pinMode(BTN_G, INPUT_PULLUP);

  Wire.begin(2, 3);          // SDA=2, SCL=3
  Wire.setClock(100000);     // 100 kHz para bring-up
  if (!TOF.begin()) {
    Serial.println(F("VL6180 (TOF050C) NO encontrado — revisa cableado (VIN, GND, SDA=2, SCL=3)."));
  } else {
    Serial.println(F("VL6180 (TOF050C) OK — <40cm + HOLD=0.6s + COOLDOWN=2s (anti-doble)"));
  }

  resetMatch(score);
  setupBroadcast();

  Serial.println();
  Serial.println(F("=========================================="));
  Serial.printf("devId: 0x%04X (%u decimal)\n", gDeviceId, gDeviceId);
  Serial.printf("  devIdLo (byte 5): 0x%02X\n", (uint8_t)(gDeviceId & 0xFF));
  Serial.printf("  devIdHi (byte 6): 0x%02X\n", (uint8_t)((gDeviceId >> 8) & 0xFF));
  Serial.println(F("=========================================="));
  Serial.println(F("MD: [FF FF] 'P' 'S' ver devLo devHi 'C' cmd seq crcLo crcHi"));
  printHelp();
  printScoreboard(score);
}

void loop() {
  // --- Botones físicos (ráfaga 4 paquetes para máxima confiabilidad) ---
  if (edgePressed(BTN_P, lastP, tP)) {
    // ▲ ANTI-DOBLE: Verificar cooldown de 4s
    const uint32_t now = millis();
    if (now - lastPointMs >= POINT_COOLDOWN_MS) {
      Serial.printf("BTN P → BURST 'p' (4 pkts)\n");
      sendCmdBurst('p'); // usa defaults: 4 paquetes, 40ms gap
      lastPointMs = now; // Actualizar timestamp
    } else {
      const uint32_t remaining = POINT_COOLDOWN_MS - (now - lastPointMs);
      Serial.printf("❌ BTN P BLOQUEADO (cooldown: %ums restantes)\n", remaining);
    }
  }
  if (edgePressed(BTN_U, lastU, tU)) {
    Serial.printf("BTN U → BURST 'u' (4 pkts)\n");
    sendCmdBurst('u');
  }
  if (edgePressed(BTN_G, lastG, tG)) {
    pushHistory();
    resetGame(score);
    Serial.printf("BTN G → BURST 'g' (4 pkts)\n");
    sendCmdBurst('g');
    printScoreboard(score);
  }

  // --- Comandos por Serial ---
  if (Serial.available()) {
    int ch = Serial.read();
    if (ch != -1) {
      char c = (char)ch;
      if (c != '\r' && c != '\n') {
        if (c >= 'A' && c <= 'Z') c = char(c - 'A' + 'a');
        bool sendBurst = false;
        switch (c) {
          case 'p': sendBurst = true; break;
          case 'u': sendBurst = true; break;
          case 'g': pushHistory(); resetGame(score); sendBurst = true; break;
          case 's': printScoreboard(score); break;
          case 'r': regenerateDevId(); break; // Borra UUID y reinicia
          case 'h': default: printHelp(); break;
        }
        if (sendBurst) {
          Serial.printf("BURST '%c' (4 pkts)\n", c);
          sendCmdBurst(c); // usa defaults: 4 paquetes, 40ms gap
        }
      }
    }
  }

  // --- Lector TOF: HOLD + histéresis + anti-serrucho ---
  {
    const uint32_t nowMs = millis();
    if (nowMs - tofState.lastSampleMs >= TOF_SAMPLE_MS) {
      tofState.lastSampleMs = nowMs;

      uint16_t d  = TOF.readRange();
      uint8_t  st = TOF.readRangeStatus();

      static uint16_t dPrev = 0xFFFF;  // “sin lectura previa válida”
      static uint32_t farSinceMs = 0;

      bool valid  = (st == 0);
      bool inZone = valid && (d <= TOF_THRESH_MM);  // Sin mínimo: detecta desde 0mm
      bool farZone = (!valid) || (d >= TOF_RELEASE_MM);

      if (tofState.armed) {
        if (inZone) {
          if (tofState.enterMs == 0) {
            tofState.enterMs = nowMs;
          }
          if (valid && dPrev != 0xFFFF) {
            int16_t delta = (int16_t)d - (int16_t)dPrev;
            if (abs(delta) > TOF_MAX_MOTION) {
              tofState.enterMs = nowMs; // reinicia temporizador de quietud
            }
          }

          if ((nowMs - tofState.enterMs) >= TOF_HOLD_MS &&
              (nowMs - tofState.lastFireMs) >= TOF_COOLDOWN_MS) {

            // ▲ ANTI-DOBLE: Verificar cooldown global de 4s
            if (nowMs - lastPointMs >= POINT_COOLDOWN_MS) {
              // === DISPARO: AGREGAR PUNTO (con ráfaga) ===
              Serial.printf("TOF → BURST 'p' (4 pkts)  (d=%umm)\n", d);
              sendCmdBurst('p', 4, 40, true);

              tofState.lastFireMs = nowMs;
              lastPointMs = nowMs;          // Actualizar timestamp global
              tofState.armed = false;       // desarmar hasta que se aleje
              farSinceMs = 0;
            } else {
              const uint32_t remaining = POINT_COOLDOWN_MS - (nowMs - lastPointMs);
              Serial.printf("❌ TOF BLOQUEADO (cooldown global: %ums restantes)\n", remaining);
              tofState.enterMs = nowMs;     // Reiniciar hold para reintentar después
            }
          }
        } else {
          tofState.enterMs = 0;         // fuera de zona → cancela hold
        }
      } else {
        // Ya disparamos: esperar alejamiento real para rearmar
        if (farZone) {
          if (farSinceMs == 0) farSinceMs = nowMs;
          if ((nowMs - farSinceMs) >= TOF_RELEASE_HOLD &&
              (nowMs - tofState.lastFireMs) >= TOF_COOLDOWN_MS) {
            tofState.armed = true;
            tofState.enterMs = 0;
            farSinceMs = 0;
          }
        } else {
          farSinceMs = 0;               // aún cerca → no rearmar
        }
      }

      if (valid) {
        dPrev = d;
        tofState.lastDist = d;
      }
    }
  }

  // --- Reemisión periódica DESHABILITADA ---
  // PROBLEMA: Con múltiples dispositivos causa comandos duplicados fantasma
  // SOLUCIÓN: Solo transmitir en pulsaciones reales (ráfagas de 4 paquetes son suficientes)
  // const unsigned long now = millis();
  // if (now - lastReTx > RE_TX_MS) {
  //   lastReTx = now;
  //   for (int i = 0; i < 2; ++i) {
  //     gSeq = (gSeq == 255) ? 1 : (uint8_t)(gSeq + 1);
  //     applyAdvPayload(lastCmd);
  //     if (i < 1) delay(40);
  //   }
  // }
}
