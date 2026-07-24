import 'dart:async';
import 'dart:convert';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../models/weight_reading.dart';

/// Maneja toda la comunicación Bluetooth con el indicador SE7510.
/// El SE7510 usa Bluetooth SPP (Serial Port Profile / Bluetooth Clásico).
class ScaleBluetoothService {
  BluetoothConnection? _connection;
  final StreamController<WeightReading> _weightController =
      StreamController<WeightReading>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  String _buffer = '';
  bool _isConnected = false;

  // Stream público para escuchar lecturas de peso
  Stream<WeightReading> get weightStream => _weightController.stream;

  // Stream público para saber si está conectado
  Stream<bool> get connectionStream => _connectionController.stream;

  bool get isConnected => _isConnected;

  /// Escanea y devuelve los dispositivos Bluetooth pareados (emparejados)
  Future<List<BluetoothDevice>> getPairedDevices() async {
    return await FlutterBluetoothSerial.instance.getBondedDevices();
  }

  /// Conecta a un dispositivo por su dirección MAC
  Future<bool> connect(String address) async {
    try {
      _connection = await BluetoothConnection.toAddress(address);
      _isConnected = true;
      _connectionController.add(true);

      // Escuchar los datos que llegan de la báscula
      _connection!.input!.listen(
        _onDataReceived,
        onDone: _onDisconnected,
        onError: (_) => _onDisconnected(),
      );

      return true;
    } catch (e) {
      _isConnected = false;
      _connectionController.add(false);
      return false;
    }
  }

  /// Procesa los bytes recibidos y los convierte en lecturas de peso
  void _onDataReceived(List<int> data) {
    // Acumular en buffer (los datos pueden llegar fragmentados)
    _buffer += utf8.decode(data, allowMalformed: true);

    // Procesar líneas completas (terminan en \r\n)
    while (_buffer.contains('\n')) {
      final idx = _buffer.indexOf('\n');
      final line = _buffer.substring(0, idx).trim();
      _buffer = _buffer.substring(idx + 1);

      if (line.isNotEmpty) {
        final reading = WeightReading.parse(line);
        if (reading != null) {
          _weightController.add(reading);
        }
      }
    }
  }

  void _onDisconnected() {
    _isConnected = false;
    _connectionController.add(false);
    _buffer = '';
  }

  /// Envía un comando ASCII a la báscula
  /// Comandos disponibles: T (tare), Z (zero), P (print), R (read), G (gross), C (kg/lb)
  Future<void> sendCommand(String command) async {
    if (!_isConnected || _connection == null) return;
    try {
      _connection!.output.add(utf8.encode(command));
      await _connection!.output.allSent;
    } catch (_) {}
  }

  Future<void> tare() => sendCommand('T');
  Future<void> zero() => sendCommand('Z');
  Future<void> toggleUnit() => sendCommand('C');
  Future<void> readWeight() => sendCommand('R');

  /// Desconecta de la báscula
  Future<void> disconnect() async {
    await _connection?.close();
    _isConnected = false;
    _connectionController.add(false);
    _buffer = '';
  }

  void dispose() {
    disconnect();
    _weightController.close();
    _connectionController.close();
  }
}
