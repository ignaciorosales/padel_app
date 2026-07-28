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
static uint32_t lastOnlineLogBySlave[slaveCount] = { 0 };
static const uint32_t ONLINE_LOG_INTERVAL_MS = 2000;
static uint32_t lastRs485DebugLogMs = 0;
static uint32_t rs485Polls = 0;
static uint32_t rs485RxBytes = 0;
static uint32_t rs485StartBytes = 0;
static uint32_t rs485Frames = 0;
static uint32_t rs485CrcErrors = 0;
static uint32_t rs485WrongId = 0;
static uint32_t rs485Valid = 0;
static uint8_t lastRs485Byte = 0;

// ===== WATCHDOG / HEARTBEAT =====
static uint32_t lastHeartbeat = 0;
static const uint32_t HEARTBEAT_INTERVAL_MS = 30000;  // Cada 30 segundos

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

static void handleTabletLine(const char* line) {
  if (line[0] == '\0') return;
  USB_SERIAL.printf("[RX] Recibido del tablet: %s\n", line);
  if (strcmp(line, "STATUS") == 0) {
    USB_SERIAL.println("[STATUS] OK - ESP32 Master activo");
  } else if (strcmp(line, "PING") == 0) {
    USB_SERIAL.println("PONG");
  }
}

// ===== pollOneSlave =====
// Devuelve true si recibió respuesta válida
static bool pollOneSlave(uint16_t slaveId, char &outCmd) {
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

    // Si encontramos otro 0xAA, reiniciar
    if (b == 0xAA) {
      rs485StartBytes++;
      buf[0] = 0xAA;
      idx = 1;
      continue;
    }

    buf[idx++] = b;
    if (idx < 7) continue;

    // Frame completo
    idx = 0;
    rs485Frames++;

    // Verificar estructura del frame
    if (buf[0] != 0xAA || buf[6] != 0x55) continue;

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
      continue;
    }
    if (rDevId != slaveId) {
      rs485WrongId++;
      continue;
    }

    outCmd = cmd;
    rs485Valid++;
    
    // Log si es comando real (con prefijo [xxx] para que app lo filtre)
    if (cmd == 'p' || cmd == 'u' || cmd == 'g') {
      uint32_t t_rx = millis();
      USB_SERIAL.printf("[RS485] dev=0x%04X cmd='%c' rtt=%lu ms\n", 
                    slaveId, cmd, (unsigned long)(t_rx - t_tx));
    }

    return true;
  }

  // Sin respuesta
  return false;
}

// ===== Procesar comando recibido del esclavo =====
// Nuevo protocolo: el master NO decide el equipo. Solo reenvía el ID de la
// caja y el comando en bruto. La app empareja caja -> equipo.
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
  
  lastHeartbeat = millis();
}

// ===== Loop principal =====
void loop() {
  // === Polear todos los esclavos ===
  for (size_t i = 0; i < slaveCount; ++i) {
    char cmd = 'n';
    if (pollOneSlave(slaveList[i], cmd)) {
      if (cmd == 'p' || cmd == 'u' || cmd == 'g') {
        processSlaveCommand(i, slaveList[i], cmd);
      } else {
        uint32_t now = millis();
        if (now - lastOnlineLogBySlave[i] >= ONLINE_LOG_INTERVAL_MS) {
          lastOnlineLogBySlave[i] = now;
          USB_SERIAL.printf("[RS485] dev=0x%04X ok cmd='%c'\n", slaveList[i], cmd);
        }
      }
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
  
  logRs485Debug();
  delay(5);  // Pausa principal del loop (igual que versión BLE)
}
