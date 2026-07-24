import 'package:flutter/material.dart';
import '../models/weight_reading.dart';
import '../services/bluetooth_service.dart';
import 'connect_screen.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

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

  // Lista para guardar pesajes
  final List<WeightReading> _savedReadings = [];

  void _saveCurrentReading() {
    if (_lastReading != null && _isConnected) {
      setState(() {
        _savedReadings.insert(0, _lastReading!);
      });
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

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
    const brandDarkBlue = Color(0xFF0c1527);
    const brandLightBlue = Color(0xFF5AB4E5);
    const panelColor = Color(0xFF16213E);

    return Scaffold(
      backgroundColor: brandDarkBlue,
      resizeToAvoidBottomInset: false, // Evita que la pantalla se apriete cuando sale el teclado
      appBar: AppBar(
        backgroundColor: brandDarkBlue,
        elevation: 0,
        title: const Text(
          'SOLUCIONES EXACTAS S.A.',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
        ),
        actions: [
          // Indicador de conexión (Punto de estado minimalista)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Tooltip(
                message: _isConnected ? 'Conectado a la báscula' : 'Sin conexión',
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isConnected ? Colors.greenAccent : Colors.redAccent,
                    boxShadow: [
                      BoxShadow(
                        color: _isConnected 
                            ? Colors.greenAccent.withOpacity(0.6) 
                            : Colors.redAccent.withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── DISPLAY PRINCIPAL DE PESO (Rectangular) ──
          Container(
            width: double.infinity,
            height: 200, // Altura fija para que parezca una pantalla LCD
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: panelColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _lastReading?.isStable == true
                    ? Colors.green.withOpacity(0.8)
                    : brandLightBlue.withOpacity(0.5),
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: brandLightBlue.withOpacity(0.05),
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

          // ── BOTONES DE CONTROL Y LISTA ──
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  // Fila 1: Botones principales de báscula
                  Row(
                    children: [
                      _ControlButton(
                        label: 'Tarar',
                        icon: Icons.exposure_zero,
                        color: brandLightBlue,
                        onPressed: _isConnected ? _btService.tare : null,
                      ),
                      const SizedBox(width: 8),
                      _ControlButton(
                        label: 'Cero',
                        icon: Icons.refresh,
                        color: brandLightBlue,
                        onPressed: _isConnected ? _btService.zero : null,
                      ),
                      const SizedBox(width: 8),
                      _ControlButton(
                        label: 'kg / lb',
                        icon: Icons.swap_horiz,
                        color: brandLightBlue,
                        onPressed: _isConnected ? _btService.toggleUnit : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Botón GUARDAR a ancho completo
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _isConnected && _lastReading != null ? _saveCurrentReading : null,
                      icon: const Icon(Icons.save_alt, size: 22),
                      label: const Text('GUARDAR PESAJE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandLightBlue.withOpacity(0.2),
                        foregroundColor: brandLightBlue,
                        side: BorderSide(color: brandLightBlue.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Lista de pesajes guardados
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: _savedReadings.isEmpty
                          ? const Center(
                              child: Text(
                                'Aún no hay pesajes guardados',
                                style: TextStyle(color: Colors.white38),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(8),
                              itemCount: _savedReadings.length,
                              separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
                              itemBuilder: (context, index) {
                                final r = _savedReadings[index];
                                // Indice invertido para que el más nuevo salga primero con el número mayor
                                final displayIndex = _savedReadings.length - index;
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 12,
                                    backgroundColor: brandLightBlue.withOpacity(0.2),
                                    child: Text('$displayIndex', style: const TextStyle(color: brandLightBlue, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  title: Text(
                                    r.displayValue,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFeatures: [FontFeature.tabularFigures()]),
                                  ),
                                  subtitle: Text(
                                    '${_formatDate(r.timestamp)} ${_formatTime(r.timestamp)}',
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                                    onPressed: () {
                                      setState(() => _savedReadings.removeAt(index));
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Botones inferiores (Conectar y Exportar)
                  Row(
                    children: [
                      // Botón Conectar/Desconectar
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _isConnected
                                ? () async {
                                    await _btService.disconnect();
                                    setState(() => _isConnected = false);
                                  }
                                : _goToConnect,
                            icon: Icon(_isConnected ? Icons.bluetooth_disabled : Icons.bluetooth, size: 20),
                            label: Text(_isConnected ? 'Desconectar' : 'Conectar', style: const TextStyle(fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (_isConnected ? Colors.red : Colors.green).withOpacity(0.15),
                              foregroundColor: _isConnected ? Colors.red : Colors.green,
                              side: BorderSide(color: (_isConnected ? Colors.red : Colors.green).withOpacity(0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Botón Exportar
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _savedReadings.isEmpty ? null : _showExportDialog,
                            icon: const Icon(Icons.share, size: 20),
                            label: const Text('Exportar', style: TextStyle(fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.withOpacity(0.15),
                              foregroundColor: Colors.blue,
                              side: BorderSide(color: Colors.blue.withOpacity(0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                    ],
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

  Future<void> _showExportDialog() async {
    if (_savedReadings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay pesajes guardados para exportar.')),
      );
      return;
    }

    String fileName = 'Pesajes_SE7510';
    String fileExt = '.csv'; // .csv (Excel) o .txt

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF16213E),
              title: const Text('Exportar Pesajes', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Nombre del archivo',
                      labelStyle: TextStyle(color: Colors.white54),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                    ),
                    onChanged: (val) => fileName = val.isEmpty ? 'Pesajes_SE7510' : val,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ChoiceChip(
                        label: const Text('Excel (.csv)'),
                        selected: fileExt == '.csv',
                        onSelected: (val) => setStateDialog(() => fileExt = '.csv'),
                        selectedColor: Colors.blue.withOpacity(0.3),
                        labelStyle: TextStyle(color: fileExt == '.csv' ? Colors.blue : Colors.white),
                        backgroundColor: Colors.transparent,
                      ),
                      ChoiceChip(
                        label: const Text('Texto (.txt)'),
                        selected: fileExt == '.txt',
                        onSelected: (val) => setStateDialog(() => fileExt = '.txt'),
                        selectedColor: Colors.blue.withOpacity(0.3),
                        labelStyle: TextStyle(color: fileExt == '.txt' ? Colors.blue : Colors.white),
                        backgroundColor: Colors.transparent,
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _exportAndShare(fileName, fileExt);
                  },
                  child: const Text('Compartir'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _exportAndShare(String name, String ext) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$name$ext');

      StringBuffer buffer = StringBuffer();
      
      // Encabezados
      if (ext == '.csv') {
        buffer.writeln('No.,Fecha,Hora,Peso,Unidad,Modo,Estado');
      } else {
        buffer.writeln('--- REPORTE DE PESAJES ---');
        buffer.writeln('Fecha de exportación: ${_formatDate(DateTime.now())} ${_formatTime(DateTime.now())}\n');
      }

      // Datos
      for (int i = 0; i < _savedReadings.length; i++) {
        final r = _savedReadings[i];
        final index = _savedReadings.length - i;
        final date = _formatDate(r.timestamp);
        final time = _formatTime(r.timestamp);
        
        if (ext == '.csv') {
          buffer.writeln('$index,$date,$time,${r.value},${r.unit},${r.modeLabel},${r.stabilityLabel}');
        } else {
          buffer.writeln('$index. $date $time | Peso: ${r.value} ${r.unit} (${r.modeLabel})');
        }
      }

      await file.writeAsString(buffer.toString());

      // Compartir archivo
      await Share.shareXFiles([XFile(file.path)], text: 'Aquí están los pesajes exportados de SOLUCIONES EXACTAS.');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
      }
    }
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
        child: Center(
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
        ),
      ),
    );
  }
}
