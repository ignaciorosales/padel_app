// ===========================================
// PadelMaster_RS485_USB_Serial
// ===========================================
//
// Compatible con:
//   - ESP32-WROOM (usa chip USB-UART externo: CH340, CP210X, etc.)
//   - ESP32-C3 (USB nativo CDC-ACM)
//   - ESP32-S2/S3 (USB nativo CDC-ACM)
//
// - Master RS-485 que polea esclavos 0x0201..0x0204
// - Envía comandos via USB Serial en texto plano
// - Compatible con la app Puntazo (Android)
//
// Comandos enviados al tablet via USB:
//   BTN:<idHex>:<P|U|G>   Ej: BTN:0201:P, BTN:0203:U, BTN:0204:G
//     P = Punto, U = Deshacer, G = Reiniciar (start/reset)
//   El master YA NO decide el equipo: solo reenvía el ID de la caja
//   y el comando en bruto. La app Puntazo empareja cada caja con un
//   equipo (Ajustes > Mandos) y decide qué hacer.
//
// Frame MASTER -> SLAVE:
//   [0xA0, devLo, devHi, 0x01, crcLo, crcHi, 0x55]
// Frame SLAVE -> MASTER:
//   [0xAA, devLo, devHi, cmd, crcLo, crcHi, 0x55]
//
// Comandos del esclavo:
//   'p' = Punto
//   'u' = Undo
//   'g' = Reset (cambio de lado?)

#include <Arduino.h>
#include "driver/uart.h"

// ===== Detectar tipo de ESP32 para USB =====
#if CONFIG_IDF_TARGET_ESP32C3 || CONFIG_IDF_TARGET_ESP32S2 || CONFIG_IDF_TARGET_ESP32S3
  #define HAS_NATIVE_USB 1
  #define USB_SERIAL Serial
#else
  // ESP32-WROOM usa Serial normal (va al chip USB-UART externo)
  #define HAS_NATIVE_USB 0
  #define USB_SERIAL Serial
#endif

// ===== RS-485 MASTER =====
// Pines dependen del tipo de ESP32:
// - ESP32-WROOM: usa UART2 en pines 16/17
// - ESP32-C3/S2/S3: usa UART1 en pines 4/5 (o los que tengas disponibles)
#if CONFIG_IDF_TARGET_ESP32C3 || CONFIG_IDF_TARGET_ESP32S2 || CONFIG_IDF_TARGET_ESP32S3
  // ESP32-C3/S2/S3: UART1 con pines personalizados
  #define RS485_TX_PIN   4    // GPIO4 -> DI del MAX3485
  #define RS485_RX_PIN   10   // GPIO10 <- RO del MAX3485
  #define RS485_EN_PIN   1    // GPIO1 -> DE y ~RE del MAX3485
  HardwareSerial RS485(1);   // UART1 para ESP32-C3
#else
  // ESP32-WROOM: UART2 con pines estándar
  #define RS485_TX_PIN   17   // GPIO17 (TX2) -> DI del módulo RS-485
  #define RS485_RX_PIN   16   // GPIO16 (RX2) <- RO del módulo RS-485
  HardwareSerial RS485(2);   // UART2 para ESP32-WROOM
#endif
#define RS485_BAUD     9600
#define RS485_RX_INVERT 0
static const uint32_t RS485_POST_TX_US = 200;

// Esclavos configurados (0x02XX)
// 0x0201 = Botón A1 (Team A player 1)
// 0x0202 = Botón A2 (Team A player 2)
// 0x0203 = Botón B1 (Team B player 1)
// 0x0204 = Botón B2 (Team B player 2)
static const uint16_t slaveList[] = { 0x0201, 0x0202, 0x0203, 0x0204 };
static const size_t   slaveCount  = sizeof(slaveList) / sizeof(slaveList[0]);

// ===== USB SERIAL (al tablet Android) =====
#define USB_BAUD       115200

// ===== TIMING =====
static const uint32_t COMMAND_DEBOUNCE_MS = 200;  // Evitar comandos duplicados
static uint32_t lastCommandTimeBySlave[slaveCount] = { 0 };
static uint32_t lastRs485DebugLogMs = 0;
static uint32_t rs485Polls = 0;
static uint32_t rs485RxBytes = 0;
static uint32_t rs485StartBytes = 0;
static uint32_t rs485Frames = 0;
static uint32_t rs485CrcErrors = 0;
static uint32_t rs485WrongId = 0;
static uint32_t rs485Valid = 0;
static uint8_t lastRs485Byte = 0;

// ===== TELEMETRIA POR ESCLAVO =====
// El maestro ya sabia que esclavo respondia, pero solo publicaba contadores
// globales. Sin esto es imposible saber DESDE LA APP cual de las 4 cajas
// falla, que es justo lo que hace falta al instalar el sistema en pista.
static const uint8_t FW_VERSION = 2;

// Fallos seguidos tras los cuales se considera la caja desconectada.
static const uint8_t OFFLINE_AFTER_FAILS = 3;
// Cuando una caja esta offline no se poleA en cada ciclo: esperar el timeout
// completo de una caja ausente ralentiza el poleo de las que SI estan vivas.
// Se reintenta 1 de cada OFFLINE_RETRY_EVERY ciclos (~0.3 s de redeteccion).
static const uint8_t OFFLINE_RETRY_EVERY = 8;

struct SlaveHealth {
  bool     online;
  uint8_t  consecutiveFails;
  uint8_t  retrySkips;      // ciclos que quedan por saltar (si esta offline)
  uint32_t replies;         // respuestas validas acumuladas
  uint32_t timeouts;        // polls sin respuesta
  uint32_t crcErrors;       // tramas suyas con CRC malo
  uint32_t commands;        // comandos reales (p/u/g) reenviados a la app
  uint32_t lastReplyMs;     // millis() de la ultima respuesta valida
  uint16_t lastRttMs;       // ida y vuelta de la ultima respuesta
};
static SlaveHealth health[slaveCount];

static uint32_t lastStatusEmitMs = 0;
static const uint32_t STATUS_INTERVAL_MS = 2000;
static uint32_t cycleStartMs = 0;
static uint16_t lastCycleMs = 0;

// ===== CRC16-CCITT (poly=0x1021, init=0xFFFF) =====
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

// Descarta el primer byte del buffer y busca la siguiente cabecera 0xAA
// dentro de lo ya leido, sin tirar el resto. Devuelve el nuevo indice de
// escritura. Evita perder la trama que venga pegada detras de una mala.
static uint8_t resyncFrame(uint8_t* buf, uint8_t len) {
  uint8_t n = len;
  do {
    for (uint8_t i = 1; i < n; ++i) buf[i - 1] = buf[i];
    n--;
  } while (n > 0 && buf[0] != 0xAA);
  return n;
}

#ifdef RS485_EN_PIN
static inline void rs485ReceiveMode() {
  digitalWrite(RS485_EN_PIN, LOW);
  delayMicroseconds(50);
}

static inline void rs485TransmitMode() {
  digitalWrite(RS485_EN_PIN, HIGH);
  delayMicroseconds(50);
}
#endif

static void rs485WriteFrame(const uint8_t* data, size_t len) {
#ifdef RS485_EN_PIN
  rs485TransmitMode();
#endif
  RS485.write(data, len);
  RS485.flush();
  delayMicroseconds(RS485_POST_TX_US);
#ifdef RS485_EN_PIN
  rs485ReceiveMode();
#endif
}

static void logRs485Debug() {
  uint32_t now = millis();
  if (now - lastRs485DebugLogMs < 2000) return;
  lastRs485DebugLogMs = now;
  USB_SERIAL.printf("[RS485 DBG] polls=%lu rxBytes=%lu startAA=%lu frames=%lu crcErr=%lu wrongId=%lu valid=%lu last=0x%02X\n",
                    (unsigned long)rs485Polls,
                    (unsigned long)rs485RxBytes,
                    (unsigned long)rs485StartBytes,
                    (unsigned long)rs485Frames,
                    (unsigned long)rs485CrcErrors,
                    (unsigned long)rs485WrongId,
                    (unsigned long)rs485Valid,
                    lastRs485Byte);
}

static bool debounceSlaveCommand(size_t slaveIndex, uint16_t slaveId, char cmd) {
  uint32_t now = millis();
  if (now - lastCommandTimeBySlave[slaveIndex] < COMMAND_DEBOUNCE_MS) {
    USB_SERIAL.printf("[DBG] Ignorado (debounce): dev=0x%04X cmd='%c'\n", slaveId, cmd);
    return false;
  }
  lastCommandTimeBySlave[slaveIndex] = now;
  return true;
}

// Publica el estado de cada caja y del propio maestro. Todas las lineas van
// con prefijo "[" para que la app las trate como diagnostico y nunca como
// comando de puntuacion.
//
//   [PS] dev=0201 on=1 rep=412 to=0 crc=0 cmd=7 rtt=18 age=31
//   [MS] fw=2 up=125340 cyc=34 on=4/4 polls=2010 ...
//
// age = ms desde la ultima respuesta valida, o -1 si nunca respondio.
static void emitStatus() {
  uint32_t now = millis();
  lastStatusEmitMs = now;

  uint8_t onlineCount = 0;
  for (size_t i = 0; i < slaveCount; ++i) {
    if (health[i].online) onlineCount++;
    long age = (health[i].lastReplyMs == 0)
                 ? -1L
                 : (long)(now - health[i].lastReplyMs);
    USB_SERIAL.printf(
      "[PS] dev=%04X on=%u rep=%lu to=%lu crc=%lu cmd=%lu rtt=%u age=%ld\n",
      slaveList[i],
      health[i].online ? 1u : 0u,
      (unsigned long)health[i].replies,
      (unsigned long)health[i].timeouts,
      (unsigned long)health[i].crcErrors,
      (unsigned long)health[i].commands,
      (unsigned)health[i].lastRttMs,
      age);
  }

  USB_SERIAL.printf(
    "[MS] fw=%u up=%lu cyc=%u on=%u/%u polls=%lu rxb=%lu frm=%lu crc=%lu wid=%lu rs485=%d usb=%d\n",
    (unsigned)FW_VERSION,
    (unsigned long)now,
    (unsigned)lastCycleMs,
    (unsigned)onlineCount, (unsigned)slaveCount,
    (unsigned long)rs485Polls,
    (unsigned long)rs485RxBytes,
    (unsigned long)rs485Frames,
    (unsigned long)rs485CrcErrors,
    (unsigned long)rs485WrongId,
    RS485_BAUD, USB_BAUD);
}

static void handleTabletLine(const char* line) {
  if (line[0] == '\0') return;
  if (strcmp(line, "STATUS") == 0) {
    // Informe completo inmediato: lo pide la pantalla de diagnostico de la
    // app para no esperar al siguiente envio periodico.
    emitStatus();
  } else if (strcmp(line, "PING") == 0) {
    USB_SERIAL.println("PONG");
  } else {
    USB_SERIAL.printf("[RX] Recibido del tablet: %s\n", line);
  }
}

// ===== pollOneSlave =====
// Devuelve true si recibió respuesta válida
static bool pollOneSlave(size_t slaveIndex, uint16_t slaveId, char &outCmd) {
  rs485Polls++;
  const uint8_t devLo = (uint8_t)(slaveId & 0xFF);
  const uint8_t devHi = (uint8_t)(slaveId >> 8);
  const uint8_t req   = 0x01;

  uint8_t crcData[3] = { devLo, devHi, req };
  uint16_t crc       = crc16_ccitt(crcData, 3);

  uint8_t tx[7] = {
    0xA0, devLo, devHi, req,
    (uint8_t)(crc & 0xFF),
    (uint8_t)(crc >> 8),
    0x55
  };

  // Limpiar buffer de entrada
  while (RS485.available()) RS485.read();

  uint32_t t_tx = millis();
  rs485WriteFrame(tx, 7);

  const uint32_t WAIT_MS = 70;
  uint32_t t0 = millis();

  uint8_t buf[7];
  uint8_t idx = 0;

  while (millis() - t0 < WAIT_MS) {
    if (!RS485.available()) {
      delay(1);
      continue;
    }

    uint8_t b = RS485.read();
    rs485RxBytes++;
    lastRs485Byte = b;

    // Buscar inicio de frame
    if (idx == 0) {
      if (b != 0xAA) continue;
      rs485StartBytes++;
      buf[0] = b;
      idx = 1;
      continue;
    }

    // OJO: aqui NO se puede resincronizar con "si es 0xAA, empezar de nuevo".
    // Los dos bytes de CRC son pseudoaleatorios, asi que ~1 de cada 128
    // respuestas VALIDAS lleva un 0xAA dentro y se perdia entera, dejando
    // ademas el parser desalineado para la siguiente. Se acumulan los 7 bytes
    // y, si la trama no valida, se descarta solo el primer byte y se vuelve a
    // buscar cabecera dentro de lo ya leido.
    buf[idx++] = b;
    if (idx < 7) continue;

    // Frame completo
    rs485Frames++;

    if (buf[0] != 0xAA || buf[6] != 0x55) {
      idx = resyncFrame(buf, 7);
      continue;
    }

    uint8_t  rDevLo = buf[1];
    uint8_t  rDevHi = buf[2];
    uint16_t rDevId = (uint16_t)((rDevHi << 8) | rDevLo);
    char     cmd    = (char)buf[3];
    uint16_t crcRx  = (uint16_t)buf[4] | ((uint16_t)buf[5] << 8);

    // Verificar CRC
    uint8_t crcData2[3] = { buf[1], buf[2], buf[3] };
    uint16_t crcCalc    = crc16_ccitt(crcData2, 3);

    if (crcCalc != crcRx) {
      rs485CrcErrors++;
      health[slaveIndex].crcErrors++;
      idx = resyncFrame(buf, 7);
      continue;
    }
    if (rDevId != slaveId) {
      rs485WrongId++;
      idx = resyncFrame(buf, 7);
      continue;
    }

    idx = 0;
    outCmd = cmd;
    rs485Valid++;

    // Salud de esta caja: respondio, con su tiempo de ida y vuelta.
    uint32_t nowMs = millis();
    health[slaveIndex].replies++;
    health[slaveIndex].lastReplyMs = nowMs;
    health[slaveIndex].lastRttMs = (uint16_t)(nowMs - t_tx);
    health[slaveIndex].consecutiveFails = 0;
    if (!health[slaveIndex].online) {
      health[slaveIndex].online = true;
      USB_SERIAL.printf("[EVT] dev=%04X online\n", slaveId);
    }
    
    // Log si es comando real (con prefijo [xxx] para que app lo filtre)
    if (cmd == 'p' || cmd == 'u' || cmd == 'g') {
      uint32_t t_rx = millis();
      USB_SERIAL.printf("[RS485] dev=0x%04X cmd='%c' rtt=%lu ms\n", 
                    slaveId, cmd, (unsigned long)(t_rx - t_tx));
    }

    return true;
  }

  // Sin respuesta dentro del timeout
  health[slaveIndex].timeouts++;
  if (health[slaveIndex].consecutiveFails < 255) {
    health[slaveIndex].consecutiveFails++;
  }
  if (health[slaveIndex].online &&
      health[slaveIndex].consecutiveFails >= OFFLINE_AFTER_FAILS) {
    health[slaveIndex].online = false;
    USB_SERIAL.printf("[EVT] dev=%04X offline\n", slaveId);
  }
  return false;
}

// ===== Procesar comando recibido del esclavo =====
// El master NO decide el equipo: solo reenvía el ID de la caja y el
// comando en bruto. La app empareja caja -> equipo (Ajustes > Mandos).
// Formato: BTN:<idHex>:<P|U|G>
void processSlaveCommand(size_t slaveIndex, uint16_t slaveId, char cmd) {
  if (!debounceSlaveCommand(slaveIndex, slaveId, cmd)) return;

  char letter;
  switch (cmd) {
    case 'p': letter = 'P'; break;  // Punto
    case 'u': letter = 'U'; break;  // Deshacer
    case 'g': letter = 'G'; break;  // Reiniciar (start/reset)
    default:  return;               // 'n' u otros: ignorar
  }

  // La app espera exactamente esta línea (sin prefijo de debug).
  health[slaveIndex].commands++;
  USB_SERIAL.printf("BTN:%04X:%c\n", slaveId, letter);
}

// ===== Setup =====
void setup() {
  // USB Serial para comunicación con el tablet
  USB_SERIAL.begin(USB_BAUD);
  
  delay(1000);  // Esperar a que el USB se estabilice (importante para ESP32-C3)
  
  USB_SERIAL.println();
  USB_SERIAL.println("[INFO] ================================");
  USB_SERIAL.println("[INFO]   PadelMaster RS485 -> USB");
  USB_SERIAL.println("[INFO]   Puntazo App Compatible");
  USB_SERIAL.println("[INFO] ================================");
  USB_SERIAL.printf("[INFO] USB Serial: %d baud\n", USB_BAUD);
  
  // RS-485 para comunicación con los esclavos
#ifdef RS485_EN_PIN
  pinMode(RS485_EN_PIN, OUTPUT);
  rs485ReceiveMode();
#endif
  RS485.begin(RS485_BAUD, SERIAL_8N1, RS485_RX_PIN, RS485_TX_PIN);
#if RS485_RX_INVERT
  uart_set_line_inverse(UART_NUM_1, UART_SIGNAL_RXD_INV);
#endif
  USB_SERIAL.printf("[INFO] RS-485: %d baud (TX=%d, RX=%d", RS485_BAUD, RS485_TX_PIN, RS485_RX_PIN);
#ifdef RS485_EN_PIN
  USB_SERIAL.printf(", EN=%d", RS485_EN_PIN);
#endif
  USB_SERIAL.println(")");
#if RS485_RX_INVERT
  USB_SERIAL.println("[INFO] RS-485 RX invertido: prueba para A/B cruzados.");
#endif
  
  // Limpiar buffers
  while (USB_SERIAL.available()) USB_SERIAL.read();
  while (RS485.available()) RS485.read();
  
  USB_SERIAL.println("[READY] Esperando comandos...");
  USB_SERIAL.printf("[INFO] Esclavos: 0x0201-0x0202 (Team A), 0x0203-0x0204 (Team B)\n");
  
  #if HAS_NATIVE_USB
    USB_SERIAL.println("[INFO] Modo: ESP32-C3/S2/S3 USB nativo");
  #else
    USB_SERIAL.println("[INFO] Modo: ESP32-WROOM (chip USB externo)");
  #endif
  
  lastStatusEmitMs = millis();
}

// ===== Loop principal =====
void loop() {
  cycleStartMs = millis();

  // === Polear todos los esclavos ===
  for (size_t i = 0; i < slaveCount; ++i) {
    // Una caja ausente cuesta el timeout entero (70 ms) en cada vuelta, lo
    // que ralentiza el poleo de las que SI responden: con una caja muerta el
    // ciclo pasa de ~30 ms a ~100 ms y en pista se nota como "va lento".
    // Estando ya offline se saltan ciclos y se reintenta cada
    // OFFLINE_RETRY_EVERY vueltas, asi que si vuelve se detecta en ~0.3 s.
    if (!health[i].online && health[i].retrySkips > 0) {
      health[i].retrySkips--;
      continue;
    }

    char cmd = 'n';
    if (pollOneSlave(i, slaveList[i], cmd)) {
      if (cmd == 'p' || cmd == 'u' || cmd == 'g') {
        processSlaveCommand(i, slaveList[i], cmd);
      }
    } else if (!health[i].online) {
      health[i].retrySkips = OFFLINE_RETRY_EVERY;
    }
    delay(2);  // Pausa entre esclavos (igual que versión BLE)
  }
  
  // === Procesar comandos desde el tablet (opcional) ===
  static char usbLineBuf[64];
  static size_t usbLineLen = 0;
  while (USB_SERIAL.available()) {
    char c = (char)USB_SERIAL.read();
    if (c == '\r') continue;
    if (c == '\n') {
      usbLineBuf[usbLineLen] = '\0';
      handleTabletLine(usbLineBuf);
      usbLineLen = 0;
      continue;
    }
    if (usbLineLen < sizeof(usbLineBuf) - 1) {
      usbLineBuf[usbLineLen++] = c;
    } else {
      usbLineLen = 0;  // linea demasiado larga, resetear
    }
  }
  
  lastCycleMs = (uint16_t)(millis() - cycleStartMs);

  if (millis() - lastStatusEmitMs >= STATUS_INTERVAL_MS) {
    emitStatus();
  }

  logRs485Debug();
  delay(5);  // Pausa principal del loop (igual que versión BLE)
}
