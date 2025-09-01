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

#define BLE_DEVICE_NAME   "PadelScore-C3"
#define MFG_ID_LSB  0xFF
#define MFG_ID_MSB  0xFF
static const uint8_t PROTO_VER = 0x01;

// ======= Estado del marcador (solo para mostrar algo en Serial) =======
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

  // Build Arduino String from raw bytes (safe with 0x00)
  String mfg;
  mfg.reserve(sizeof(p));
  for (size_t i = 0; i < sizeof(p); ++i) mfg += (char)p[i];

  BLEAdvertisementData advData, scanResp;
  advData.setManufacturerData(mfg);   // MD en ADV primario
  scanResp.setName(BLE_DEVICE_NAME);  // nombre en Scan Response

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
  WiFi.mode(WIFI_OFF);          // suficiente en ESP32
  Serial.begin(115200);
  unsigned long t0 = millis();
  while (!Serial && (millis() - t0 < 2000)) { delay(10); }

  setCpuFrequencyMhz(80);
  gDeviceId = calcDevIdFromEfuse();

  resetMatch(score); // estado visible en Serial
  setupBroadcast();

  Serial.println();
  Serial.printf("devId: 0x%04X (derivado de efuse MAC)\n", gDeviceId);
  Serial.println(F("MD: [FF FF] 'P' 'S' ver devLo devHi 'C' cmd seq crcLo crcHi"));
  printHelp();
  printScoreboard(score);
}

void loop() {
  // Lee comandos desde el Monitor Serie
  if (Serial.available()) {
    int ch = Serial.read();
    if (ch != -1) {
      char c = (char)ch;
      if (c == '\r' || c == '\n') {
        // ignora
      } else {
        if (c >= 'A' && c <= 'Z') c = char(c - 'A' + 'a');
        bool bumpSeq = false;

        switch (c) {
          case 'p': bumpSeq = true; break;                 // sólo transmite
          case 'u': bumpSeq = true; break;                 // sólo transmite
          case 'g': pushHistory(); resetGame(score); bumpSeq = true; break; // visible en Serial
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

  // Reemite periódicamente el último comando (misma seq)
  const unsigned long now = millis();
  if (now - lastReTx > RE_TX_MS) {
    lastReTx = now;
    applyAdvPayload(lastCmd);
  }
}
