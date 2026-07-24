import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/bluetooth_service.dart';

/// Pantalla para buscar y conectarse a la báscula L250920 por BLE GATT.
class ConnectScreen extends StatefulWidget {
  final ScaleBluetoothService btService;

  const ConnectScreen({super.key, required this.btService});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  List<Map<String, String>> _devices = [];
  bool _loading = false;
  String? _connectingAddress;

  @override
  void initState() {
    super.initState();
    _checkAndLoad();
  }

  Future<void> _checkAndLoad() async {
    // Pedir permisos de Bluetooth y ubicación
    await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _loading = true);
    try {
      final devices = await widget.btService.scanAndGetDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connect(Map<String, String> device) async {
    final address = device['address']!;
    setState(() => _connectingAddress = address);

    final error = await widget.btService.connect(address);

    if (!mounted) return;
    setState(() => _connectingAddress = null);

    if (error == null) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'Conectar Báscula (BLE)',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDevices,
            tooltip: 'Buscar dispositivos',
          ),
        ],
      ),
      body: Column(
        children: [
          // Instrucción
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F3460),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.bluetooth_searching, color: Colors.blue, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Buscando dispositivos BLE... '
                    'Selecciona L250920 de la lista.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Lista de dispositivos
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(color: Colors.blue),
                        SizedBox(height: 16),
                        Text(
                          'Buscando dispositivos BLE...',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  )
                : _devices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bluetooth_disabled,
                                color: Colors.white38, size: 60),
                            const SizedBox(height: 16),
                            const Text(
                              'No se encontraron dispositivos BLE',
                              style: TextStyle(color: Colors.white54),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Asegúrate que la báscula está encendida',
                              style: TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadDevices,
                              icon: const Icon(Icons.search),
                              label: const Text('Buscar de nuevo'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _devices.length,
                        itemBuilder: (ctx, i) {
                          final device = _devices[i];
                          final address = device['address'] ?? '';
                          final name = device['name']?.isNotEmpty == true
                              ? device['name']!
                              : 'Dispositivo BLE';
                          final isConnecting = _connectingAddress == address;
                          final isScale = name.toLowerCase().contains('l250') ||
                              name.toLowerCase().contains('weigh') ||
                              name.toLowerCase().contains('scale');

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: isScale
                                ? const Color(0xFF0D2137)
                                : const Color(0xFF16213E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isConnecting
                                    ? Colors.blue
                                    : isScale
                                        ? Colors.blue.withOpacity(0.4)
                                        : Colors.transparent,
                                width: isScale ? 1.5 : 1,
                              ),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (isScale ? Colors.blue : Colors.white)
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isScale
                                      ? Icons.monitor_weight
                                      : Icons.bluetooth,
                                  color: isScale ? Colors.blue : Colors.white54,
                                ),
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  color: isScale ? Colors.white : Colors.white70,
                                  fontWeight: isScale
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                address,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 12),
                              ),
                              trailing: isConnecting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.blue,
                                      ),
                                    )
                                  : const Icon(Icons.chevron_right,
                                      color: Colors.white38),
                              onTap: isConnecting ? null : () => _connect(device),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
