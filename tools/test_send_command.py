"""
Script de prueba para enviar comandos RS-485 simulados
Simula una botonera ESP32 enviando comandos 'a' o 'b'
"""
import serial
import time
import sys

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

def send_command(ser, dev_id, cmd_char, seq):
    """Envía un comando simulando ESP32"""
    cmd = ord(cmd_char)
    
    packet = bytes([
        0x50, 0x53,           # 'P' 'S'
        0x01,                 # Versión
        dev_id & 0xFF,        # DevID bajo
        (dev_id >> 8) & 0xFF, # DevID alto
        0x43,                 # 'C'
        cmd,                  # Comando
        seq                   # Secuencia
    ])
    
    crc = crc16_ccitt(packet)
    packet += bytes([crc & 0xFF, (crc >> 8) & 0xFF])
    
    ser.write(packet)
    print(f"✅ Enviado: {cmd_char} (dev:{dev_id}, seq:{seq}) - {packet.hex(' ')}")
    return packet

def main():
    # Configuración
    PORT = 'COM3'  # Cambia según tu puerto
    BAUD = 115200
    DEVICE_ID = 0x0001  # Simulamos ESP32 #1
    
    print(f"🔌 Conectando a {PORT} @ {BAUD} baud...")
    
    try:
        ser = serial.Serial(PORT, BAUD, timeout=1)
        time.sleep(0.5)  # Esperar estabilización
        print("✅ Puerto abierto\n")
        
        seq = 0
        
        print("📝 Comandos disponibles:")
        print("  a - Punto para Team BLUE (botón A)")
        print("  b - Punto para Team RED (botón B)")
        print("  u - Undo (deshacer)")
        print("  g - Restart (reiniciar partido)")
        print("  q - Salir\n")
        
        while True:
            cmd = input("Comando [a/b/u/g/q]: ").strip().lower()
            
            if cmd == 'q':
                print("👋 Cerrando...")
                break
            
            if cmd in ['a', 'b', 'u', 'g']:
                send_command(ser, DEVICE_ID, cmd, seq % 256)
                seq += 1
                time.sleep(0.1)  # Pequeña pausa
            else:
                print("❌ Comando inválido")
        
        ser.close()
        print("✅ Puerto cerrado")
        
    except serial.SerialException as e:
        print(f"❌ Error abriendo puerto: {e}")
        print(f"\n💡 Sugerencias:")
        print(f"  - Verifica que {PORT} existe (usa test_serial_ports.dart)")
        print(f"  - Cierra otras apps que usen el puerto (Arduino IDE, etc.)")
        print(f"  - Verifica drivers USB-RS485 instalados")
        sys.exit(1)

if __name__ == "__main__":
    main()
