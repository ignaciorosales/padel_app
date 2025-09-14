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

#include <Wire.h>
#include <Adafruit_VL6180X.h>

#define BLE_DEVICE_NAME   "PadelScore-C3"
#define MFG_ID_LSB  0xFF
#define MFG_ID_MSB  0xFF
static const uint8_t PROTO_VER = 0x01;

Adafruit_VL6180X TOF;   // TOF050C (VL6180)

// === TOF tuning ===
const uint16_t TOF_MIN_MM       = 10;    // ignora “casi pegado”
const uint16_t TOF_THRESH_MM    = 200;   // ≤ 20 cm “dentro de zona”
const uint16_t TOF_RELEASE_MM   = 220;   // ≥ 22 cm “fuera de zona” (histéresis)
const uint16_t TOF_HOLD_MS      = 1000;  // 1 s quieto
const uint16_t TOF_COOLDOWN_MS  = 1000;  // anti-doble
const uint16_t TOF_SAMPLE_MS    = 60;    // ~16 Hz
const uint16_t TOF_RELEASE_HOLD = 150;   // 150 ms lejos para rearmar (anti-serrucho)
const uint16_t TOF_MAX_MOTION   = 15;    // máx. variación dentro del hold (mm)

struct {
  uint32_t enterMs      = 0;
  uint32_t lastFireMs   = 0;
  uint32_t lastSampleMs = 0;
  bool     armed        = true;
  uint16_t lastDist     = 999;
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
static const unsigned long DEBOUNCE_MS = 40;

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
static const unsigned long RE_TX_MS = 2000;  // reemite cada 2 s
static uint8_t gSeq = 1;                     // 1..255

// Stable device id from efuse MAC (low 16 bits)
static uint16_t gDeviceId = 0;
static inline uint16_t calcDevIdFromEfuse() {
  uint64_t mac = ESP.getEfuseMac();
  return (uint16_t)(mac & 0xFFFF);
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

  BLEAdvertisementData advData, scanResp;
  advData.setManufacturerData(mfg);
  scanResp.setName(BLE_DEVICE_NAME);

  adv->stop();
  adv->setAdvertisementData(advData);
  adv->setScanResponseData(scanResp);
  adv->start();
}

// Inicializa BLE “beacon”
static void setupBroadcast() {
  BLEDevice::init(BLE_DEVICE_NAME);
  adv = BLEDevice::getAdvertising();
  adv->setScanResponse(true);
  applyAdvPayload('p'); // estado neutro
}

// ======= Serial helpers =======
static void printHelp() {
  Serial.println(F("Comandos por Serial: p u g s (h=ayuda)"));
  Serial.println(F("p: POINT (solo transmite)"));
  Serial.println(F("u: UNDO  (solo transmite)"));
  Serial.println(F("g: START/RESTART GAME (resetea juego local y transmite)"));
  Serial.println(F("s: ver estado local"));
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
  gDeviceId = calcDevIdFromEfuse();

  pinMode(BTN_P, INPUT_PULLUP);
  pinMode(BTN_U, INPUT_PULLUP);
  pinMode(BTN_G, INPUT_PULLUP);

  Wire.begin(2, 3);          // SDA=2, SCL=3
  Wire.setClock(100000);     // 100 kHz para bring-up
  if (!TOF.begin()) {
    Serial.println(F("VL6180 (TOF050C) NO encontrado — revisa cableado (VIN, GND, SDA=2, SCL=3)."));
  } else {
    Serial.println(F("VL6180 (TOF050C) OK — listo para medir a <20 cm con HOLD=1s."));
  }

  resetMatch(score);
  setupBroadcast();

  Serial.println();
  Serial.printf("devId: 0x%04X (derivado de efuse MAC)\n", gDeviceId);
  Serial.println(F("MD: [FF FF] 'P' 'S' ver devLo devHi 'C' cmd seq crcLo crcHi"));
  printHelp();
  printScoreboard(score);
}

void loop() {
  // --- Botones físicos ---
  if (edgePressed(BTN_P, lastP, tP)) {
    gSeq = (gSeq == 255) ? 1 : (uint8_t)(gSeq + 1);
    applyAdvPayload('p');
    Serial.printf("BTN P → TX 'p' seq=%u\n", gSeq);
  }
  if (edgePressed(BTN_U, lastU, tU)) {
    gSeq = (gSeq == 255) ? 1 : (uint8_t)(gSeq + 1);
    applyAdvPayload('u');
    Serial.printf("BTN U → TX 'u' seq=%u\n", gSeq);
  }
  if (edgePressed(BTN_G, lastG, tG)) {
    pushHistory();
    resetGame(score);
    gSeq = (gSeq == 255) ? 1 : (uint8_t)(gSeq + 1);
    applyAdvPayload('g');
    Serial.printf("BTN G → TX 'g' seq=%u\n", gSeq);
    printScoreboard(score);
  }

  // --- Comandos por Serial ---
  if (Serial.available()) {
    int ch = Serial.read();
    if (ch != -1) {
      char c = (char)ch;
      if (c != '\r' && c != '\n') {
        if (c >= 'A' && c <= 'Z') c = char(c - 'A' + 'a');
        bool bumpSeq = false;
        switch (c) {
          case 'p': bumpSeq = true; break;
          case 'u': bumpSeq = true; break;
          case 'g': pushHistory(); resetGame(score); bumpSeq = true; break;
          case 's': printScoreboard(score); break;
          case 'h': default: printHelp(); break;
        }
        if (bumpSeq) {
          gSeq = (gSeq == 255) ? 1 : (uint8_t)(gSeq + 1);
          applyAdvPayload(c);
          Serial.printf("TX '%c' seq=%u\n", c, gSeq);
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
      bool inZone = valid && (d >= TOF_MIN_MM) && (d <= TOF_THRESH_MM);
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

            // === DISPARO: AGREGAR PUNTO ===
            gSeq = (gSeq == 255) ? 1 : (uint8_t)(gSeq + 1);
            applyAdvPayload('p');
            Serial.printf("TOF → TX 'p' seq=%u  (d=%umm)\n", gSeq, d);

            tofState.lastFireMs = nowMs;
            tofState.armed = false;     // desarmar hasta que se aleje
            farSinceMs = 0;
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

  // --- Reemisión periódica ---
  const unsigned long now = millis();
  if (now - lastReTx > RE_TX_MS) {
    lastReTx = now;
    applyAdvPayload(lastCmd);
  }
}
