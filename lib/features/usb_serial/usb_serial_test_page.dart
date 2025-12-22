import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

/// Pantalla de prueba USB Serial - RECEPTOR
/// Muestra datos recibidos de forma clara
class UsbSerialTestPage extends StatefulWidget {
  const UsbSerialTestPage({super.key});

  @override
  State<UsbSerialTestPage> createState() => _UsbSerialTestPageState();
}

class _UsbSerialTestPageState extends State<UsbSerialTestPage> {
  static const _methodChannel = MethodChannel('com.padelapp/usb_serial');
  static const _eventChannel = EventChannel('com.padelapp/usb_serial_events');

  StreamSubscription? _subscription;
  
  final List<String> _logs = [];
  final List<Map<String, dynamic>> _devices = [];
  final ScrollController _scrollController = ScrollController();
  
  bool _isConnected = false;
  int _selectedDeviceId = -1;
  int _bytesRx = 0;
  String _lastReceived = '';
  String _lastReceivedHex = '';
  int _packetsReceived = 0;

  @override
  void initState() {
    super.initState();
    _setupEventChannel();
    _refreshDevices();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupEventChannel() {
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final type = event['type'] as String?;
          
          switch (type) {
            case 'debug':
              _addLog('📋 ${event['data']}');
              break;
              
            case 'rx':
              final data = event['data'] as String? ?? '';
              final hex = event['hex'] as String? ?? '';
              final len = event['length'] as int? ?? 0;
              setState(() {
                _bytesRx += len;
                _lastReceived = data;
                _lastReceivedHex = hex;
                _packetsReceived++;
              });
              _addLog('📥 RX($len): $data');
              _addLog('   HEX: $hex');
              break;
              
            case 'tx':
              final data = event['data'] as String? ?? '';
              final len = event['length'] as int? ?? 0;
              _addLog('📤 TX($len): $data');
              break;
              
            case 'status':
              setState(() {
                _isConnected = event['connected'] as bool? ?? false;
              });
              _addLog(_isConnected ? '✅ CONECTADO' : '🔌 DESCONECTADO');
              break;
              
            case 'devices':
              final devices = event['devices'] as List?;
              if (devices != null) {
                setState(() {
                  _devices.clear();
                  for (var d in devices) {
                    if (d is Map) {
                      _devices.add(Map<String, dynamic>.from(d));
                    }
                  }
                });
              }
              break;
          }
        }
      },
      onError: (e) {
        _addLog('❌ Error: $e');
      },
    );
  }

  void _addLog(String msg) {
    setState(() {
      final time = DateTime.now().toString().substring(11, 19);
      _logs.add('[$time] $msg');
      // Limitar logs
      if (_logs.length > 200) {
        _logs.removeRange(0, 50);
      }
    });
    
    // Scroll al final
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _refreshDevices() async {
    try {
      final result = await _methodChannel.invokeMethod('getDevices');
      if (result is List) {
        setState(() {
          _devices.clear();
          for (var d in result) {
            if (d is Map) {
              _devices.add(Map<String, dynamic>.from(d));
            }
          }
        });
        _addLog('📋 ${_devices.length} dispositivos encontrados');
      }
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  Future<void> _connect() async {
    if (_selectedDeviceId < 0) {
      _addLog('⚠️ Selecciona un dispositivo primero');
      return;
    }
    
    try {
      await _methodChannel.invokeMethod('connect', {'deviceId': _selectedDeviceId});
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  Future<void> _disconnect() async {
    try {
      await _methodChannel.invokeMethod('disconnect');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔌 USB Serial RECEPTOR'),
        backgroundColor: _isConnected ? Colors.green.shade700 : Colors.grey.shade800,
        actions: [
          // Stats
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'RX: $_bytesRx bytes | $_packetsReceived paquetes',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDevices,
            tooltip: 'Actualizar dispositivos',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => setState(() => _logs.clear()),
            tooltip: 'Limpiar logs',
          ),
        ],
      ),
      body: Row(
        children: [
          // Panel izquierdo: Dispositivos y controles
          Container(
            width: 280,
            color: Colors.grey.shade900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Lista de dispositivos
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '📱 Dispositivos USB (${_devices.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                
                Expanded(
                  child: _devices.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay dispositivos USB\n\nConecta un Arduino, ESP32\no adaptador USB-Serial',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _devices.length,
                          itemBuilder: (context, index) {
                            final device = _devices[index];
                            final deviceId = device['deviceId'] as int;
                            final isSelected = deviceId == _selectedDeviceId;
                            
                            return Card(
                              color: isSelected ? Colors.blue.shade800 : null,
                              child: ListTile(
                                dense: true,
                                selected: isSelected,
                                leading: Icon(
                                  Icons.usb,
                                  color: isSelected ? Colors.white : Colors.grey,
                                ),
                                title: Text(
                                  device['productName']?.toString() ?? 'USB Device',
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : null,
                                  ),
                                ),
                                subtitle: Text(
                                  'VID:${device['vendorId']} PID:${device['productId']}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onTap: () {
                                  setState(() {
                                    _selectedDeviceId = deviceId;
                                  });
                                },
                              ),
                            );
                          },
                        ),
                ),
                
                const Divider(),
                
                // Botones de conexión
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isConnected ? null : _connect,
                          icon: const Icon(Icons.link),
                          label: const Text('Conectar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isConnected ? _disconnect : null,
                          icon: const Icon(Icons.link_off),
                          label: const Text('Desconectar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Estado
                Container(
                  padding: const EdgeInsets.all(16),
                  color: _isConnected ? Colors.green.shade900 : Colors.red.shade900,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isConnected ? Icons.check_circle : Icons.cancel,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isConnected ? 'CONECTADO' : 'DESCONECTADO',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Panel central: ÚLTIMO COMANDO RECIBIDO (grande y visible)
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.black,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.blue.shade900,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download, color: Colors.white, size: 24),
                        SizedBox(width: 8),
                        Text(
                          '📥 ÚLTIMO DATO RECIBIDO',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Último dato recibido - GRANDE
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _lastReceived.isEmpty 
                            ? Colors.grey.shade900 
                            : Colors.green.shade900,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _lastReceived.isEmpty 
                              ? Colors.grey.shade700 
                              : Colors.green,
                          width: 3,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Contador de paquetes
                          Text(
                            'Paquetes: $_packetsReceived',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Texto recibido
                          Text(
                            _lastReceived.isEmpty 
                                ? 'Esperando datos...' 
                                : _lastReceived,
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: _lastReceived.isEmpty 
                                  ? Colors.grey 
                                  : Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // HEX
                          if (_lastReceivedHex.isNotEmpty) ...[
                            const Text(
                              'HEX:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _lastReceivedHex,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'monospace',
                                  color: Colors.cyan,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Panel derecho: Logs
          Container(
            width: 350,
            color: Colors.grey.shade900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey.shade800,
                  child: Text(
                    '📜 Log (${_logs.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      Color color = Colors.white70;
                      
                      if (log.contains('📥') || log.contains('RX')) {
                        color = Colors.green.shade300;
                      } else if (log.contains('📤') || log.contains('TX')) {
                        color = Colors.blue.shade300;
                      } else if (log.contains('❌') || log.contains('Error')) {
                        color = Colors.red.shade300;
                      } else if (log.contains('✅') || log.contains('CONECTADO')) {
                        color = Colors.green;
                      } else if (log.contains('⚠️')) {
                        color = Colors.orange;
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: color,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
