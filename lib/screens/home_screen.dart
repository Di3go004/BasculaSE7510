import 'package:flutter/material.dart';
import '../models/weight_reading.dart';
import '../services/bluetooth_service.dart';
import 'connect_screen.dart';

/// Pantalla principal — muestra el peso en tiempo real del SE7510.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScaleBluetoothService _btService = ScaleBluetoothService();
  WeightReading? _lastReading;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();

    // Escuchar cambios de conexión
    _btService.connectionStream.listen((connected) {
      setState(() => _isConnected = connected);
      if (!connected && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se perdió la conexión con la báscula'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });

    // Escuchar lecturas de peso en tiempo real
    _btService.weightStream.listen((reading) {
      setState(() => _lastReading = reading);
    });
  }

  @override
  void dispose() {
    _btService.dispose();
    super.dispose();
  }

  Future<void> _goToConnect() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ConnectScreen(btService: _btService),
      ),
    );
    if (result == true) {
      setState(() => _isConnected = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'Báscula SE7510',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          // Indicador de conexión
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isConnected
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isConnected ? Colors.green : Colors.red,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: _isConnected ? Colors.green : Colors.red,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isConnected ? 'Conectado' : 'Sin conexión',
                      style: TextStyle(
                        color: _isConnected ? Colors.green : Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── DISPLAY PRINCIPAL DE PESO ──
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F3460),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _lastReading?.isStable == true
                      ? Colors.green.withOpacity(0.5)
                      : Colors.orange.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Modo (BRUTO / NETO) y estabilidad
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _lastReading?.modeLabel ?? 'BRUTO',
                          style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              letterSpacing: 2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _lastReading?.stabilityLabel ?? '',
                        style: TextStyle(
                          color: _lastReading?.isStable == true
                              ? Colors.green
                              : Colors.orange,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Valor del peso — el display principal
                  _isConnected
                      ? Text(
                          _lastReading?.displayValue ?? '---',
                          style: TextStyle(
                            fontSize: _lastReading?.isOverload == true ? 36 : 56,
                            fontWeight: FontWeight.w300,
                            color: _lastReading?.isOverload == true
                                ? Colors.red
                                : Colors.white,
                            letterSpacing: 2,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        )
                      : const Text(
                          '- - - . - -',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w300,
                            color: Colors.white24,
                            letterSpacing: 4,
                          ),
                        ),

                  const SizedBox(height: 8),

                  // Timestamp
                  if (_lastReading != null)
                    Text(
                      'Última lectura: ${_formatTime(_lastReading!.timestamp)}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),

                  if (!_isConnected)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Conéctate a la báscula para ver el peso',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── BOTONES DE CONTROL ──
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  // Fila 1: Tare y Zero
                  Expanded(
                    child: Row(
                      children: [
                        _ControlButton(
                          label: 'Tarar',
                          icon: Icons.exposure_zero,
                          color: Colors.blue,
                          onPressed: _isConnected ? _btService.tare : null,
                        ),
                        const SizedBox(width: 12),
                        _ControlButton(
                          label: 'Cero',
                          icon: Icons.refresh,
                          color: Colors.teal,
                          onPressed: _isConnected ? _btService.zero : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Fila 2: Cambiar unidad y conectar
                  Expanded(
                    child: Row(
                      children: [
                        _ControlButton(
                          label: 'kg / lb',
                          icon: Icons.swap_horiz,
                          color: Colors.purple,
                          onPressed: _isConnected ? _btService.toggleUnit : null,
                        ),
                        const SizedBox(width: 12),
                        _ControlButton(
                          label: _isConnected ? 'Desconectar' : 'Conectar',
                          icon: _isConnected
                              ? Icons.bluetooth_disabled
                              : Icons.bluetooth,
                          color: _isConnected ? Colors.red : Colors.green,
                          onPressed: _isConnected
                              ? () async {
                                  await _btService.disconnect();
                                  setState(() => _isConnected = false);
                                }
                              : _goToConnect,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}

class _ControlButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _ControlButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Expanded(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              enabled ? color.withOpacity(0.15) : Colors.white.withOpacity(0.04),
          foregroundColor: enabled ? color : Colors.white24,
          side: BorderSide(
              color: enabled ? color.withOpacity(0.5) : Colors.transparent),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
