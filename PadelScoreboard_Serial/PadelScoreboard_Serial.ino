// PadelScoreboard_Serial.ino — BLE advertising (connectionless) version
// Broadcasts Manufacturer Data = [0xFF,0xFF] + "CMD:" + <cmd> + <seq>
// <seq> increments for real commands (a,b,u,g,m) and stays the same for periodic re-broadcasts.

#include "Config.h"
#include "PadelRules.h"

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEAdvertising.h>
#include <WiFi.h>

// ======= Ajustes BLE =======
#define BLE_DEVICE_NAME   "PadelScore-C3"

// Manufacturer Company ID (0xFFFF = testing). Keep in sync with your Flutter sniffer.
#define MFG_ID_LSB  0xFF
#define MFG_ID_MSB  0xFF

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

// ======= Advertising globals/protos =======
static BLEAdvertising* adv = nullptr;
static char lastCmd = 's';                   // último comando emitido (por defecto 's')
static unsigned long lastReTx = 0;           // re-broadcast periódico
static const unsigned long RE_TX_MS = 2000;  // reemite cada 2s para oyentes que lleguen tarde
static uint8_t gSeq = 1;                     // 1..255, nunca 0 para evitar '\0'

// Construye y aplica el payload de advertising con Manufacturer Data = "FFFF:CMD:<c><seq>"
static void applyAdvPayload(char cmd) {
  lastCmd = cmd;

  BLEAdvertisementData ad;
  ad.setName(BLE_DEVICE_NAME);

  // Manufacturer data: [LSB, MSB] + "CMD:" + <cmd> + <seq>
  // Use Arduino String (not std::string) because BLE API expects String.
  String mfg;
  mfg.reserve(2 + 4 + 1 + 1);
  mfg += (char)MFG_ID_LSB;   // 0xFF
  mfg += (char)MFG_ID_MSB;   // 0xFF
  mfg += "CMD:";
  mfg += cmd;                // 'a','b','u','g','m','s'
  mfg += (char)gSeq;         // sequence byte (1..255, never 0)

  ad.setManufacturerData(mfg);

  // Ensure change takes effect
  adv->stop();
  adv->setAdvertisementData(ad);
  adv->start();
}

// Inicializa BLE en modo "beacon" (sin servidor GATT)
static void setupBroadcast() {
  BLEDevice::init(BLE_DEVICE_NAME);
  adv = BLEDevice::getAdvertising();
  adv->setScanResponse(false); // todo en el paquete primario
  applyAdvPayload('s');        // arranca con estado neutro
}

// ======= Serial helpers =======
static void printHelp() {
  Serial.println(F("Comandos: a b u g m s  (h=ayuda)"));
  Serial.println(F("a: A+, b: B+, u: undo, g: reset juego, m: reset partido, s: ver estado"));
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
  WiFi.forceSleepBegin();
  delay(1);
  Serial.begin(115200);
  unsigned long t0 = millis();
  while (!Serial && (millis() - t0 < 2000)) { delay(10); }

  setCpuFrequencyMhz(80); 
  resetMatch(score);
  setupBroadcast();

  Serial.println();
  Serial.println(F("BLE Broadcast listo. No se requiere conexión."));
  Serial.println(F("Escanea 'PadelScore-C3' y lee ManufacturerData: [FFFF] + 'CMD:<letra><seq>'"));
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
        // ignora CR/LF
      } else {
        if (c >= 'A' && c <= 'Z') c = char(c - 'A' + 'a');

        bool bumpSeq = false;

        switch (c) {
          case 'a': pushHistory(); pointToA(score); bumpSeq = true; break;
          case 'b': pushHistory(); pointToB(score); bumpSeq = true; break;
          case 'u': popHistory();                        bumpSeq = true; break;
          case 'g': pushHistory(); resetGame(score);     bumpSeq = true; break;
          case 'm': pushHistory(); resetMatch(score);    bumpSeq = true; break;
          case 's': default: break; // 's' = no-op (estado)
        }

        if (bumpSeq) {
          gSeq = (gSeq == 255) ? 1 : (uint8_t)(gSeq + 1); // 1..255, evita 0
        }

        applyAdvPayload(c);
        printScoreboard(score);
      }
    }
  }

  // Reemite periódicamente el último comando para oyentes que llegan tarde
  const unsigned long now = millis();
  if (now - lastReTx > RE_TX_MS) {
    lastReTx = now;
    // NO cambia gSeq aquí; se re-emite el último estado tal cual
    applyAdvPayload(lastCmd);
  }
}
