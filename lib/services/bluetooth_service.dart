import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/weight_reading.dart';

/// Maneja la conexión BLE con el indicador de peso.
class ScaleBluetoothService {
  // UUID de la característica de peso (capturado del dispositivo)
  static const String _weightCharUuid = '00002af0-0000-1000-8000-00805f9b34fb';

  final StreamController<WeightReading> _weightController =
      StreamController<WeightReading>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _weightChar; // Para leer (Notify/Read)
  BluetoothCharacteristic? _writeChar;  // Para escribir (Write)
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamSubscription<List<int>>? _dataSub;
  String _buffer = '';
  bool _isConnected = false;

  Stream<WeightReading> get weightStream => _weightController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  bool get isConnected => _isConnected;

  /// Devuelve la lista de dispositivos BLE ya emparejados/conocidos
  Future<List<Map<String, String>>> getPairedDevices() async {
    final bonded = await FlutterBluePlus.bondedDevices;
    final connected = FlutterBluePlus.connectedDevices;
    final all = <BluetoothDevice>{...bonded, ...connected};

    if (all.isEmpty) {
      final sys = await FlutterBluePlus.systemDevices([]);
      all.addAll(sys);
    }

    return all.map((d) => {
      'name': d.platformName.isNotEmpty ? d.platformName : 'Dispositivo BLE',
      'address': d.remoteId.str,
    }).toList();
  }

  /// Alias para compatibilidad con connect_screen.dart
  Future<List<Map<String, String>>> scanAndGetDevices() async {
    final result = <String, Map<String, String>>{};

    // Agregar dispositivos ya conocidos
    try {
      final bonded = await FlutterBluePlus.bondedDevices;
      for (final d in bonded) {
        result[d.remoteId.str] = {
          'name': d.platformName.isNotEmpty ? d.platformName : 'Dispositivo BLE',
          'address': d.remoteId.str,
        };
      }
    } catch (_) {}

    // Escanear brevemente
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
      await Future.delayed(const Duration(seconds: 4));
      await FlutterBluePlus.stopScan();
      for (final r in FlutterBluePlus.lastScanResults) {
        result[r.device.remoteId.str] = {
          'name': r.device.platformName.isNotEmpty
              ? r.device.platformName
              : r.advertisementData.advName.isNotEmpty
                  ? r.advertisementData.advName
                  : 'BLE ${r.device.remoteId.str}',
          'address': r.device.remoteId.str,
        };
      }
    } catch (_) {}

    return result.values.toList();
  }

  /// Conecta a un dispositivo BLE por su MAC/ID
  Future<bool> connect(String address) async {
    try {
      final device = BluetoothDevice(remoteId: DeviceIdentifier(address));
      _device = device;

      // Escuchar estado de conexión
      _connectionSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _isConnected = false;
          _connectionController.add(false);
          _buffer = '';
        }
      });

      await device.connect(timeout: const Duration(seconds: 10));

      // Descubrir servicios
      final services = await device.discoverServices();

      // Buscar la característica de lectura y escritura
      BluetoothCharacteristic? weightChar;
      BluetoothCharacteristic? writeChar;

      print('---- SERVICIOS DESCUBIERTOS ----');
      for (final service in services) {
        print('Servicio: ${service.uuid}');
        for (final char in service.characteristics) {
          final u = char.uuid.toString().toLowerCase();
          final props = char.properties;
          print('  - Char: $u (notify:${props.notify} read:${props.read} write:${props.write})');

          if (u.contains('2af0') || u == _weightCharUuid) {
            weightChar = char;
            print('  *** PESO 2AF0 encontrada ***');
          }
          if ((props.write || props.writeWithoutResponse) && writeChar == null) {
            writeChar = char;
            print('  *** ESCRITURA encontrada: $u ***');
          }
        }
      }

      // Fallback: cualquier característica con notify
      if (weightChar == null) {
        for (final service in services) {
          for (final char in service.characteristics) {
            final u = char.uuid.toString().toLowerCase();
            if (u.contains('2a05')) continue;
            if (char.properties.notify || char.properties.indicate) {
              weightChar = char;
              print('  *** FALLBACK lectura: $u ***');
              break;
            }
          }
          if (weightChar != null) break;
        }
      }
      print('--------------------------------');

      if (weightChar == null) {
        await device.disconnect();
        _isConnected = false;
        _connectionController.add(false);
        return false;
      }

      _weightChar = weightChar;
      _writeChar = writeChar ?? weightChar;

      // Activar notificaciones
      await weightChar.setNotifyValue(true);
      _dataSub = weightChar.onValueReceived.listen(_onDataReceived);

      _isConnected = true;
      _connectionController.add(true);
      return true;
    } catch (e) {
      print('BLE CONNECT ERROR: $e');
      _isConnected = false;
      _connectionController.add(false);
      return false;
    }
  }

  /// Procesa los bytes recibidos y los convierte en lecturas de peso
  void _onDataReceived(List<int> data) {
    try {
      _buffer += String.fromCharCodes(data);

      while (_buffer.contains('\n')) {
        final idx = _buffer.indexOf('\n');
        final line = _buffer.substring(0, idx).trim();
        _buffer = _buffer.substring(idx + 1);

        if (line.isNotEmpty) {
          print('BLE RAW: $line');
          final reading = WeightReading.parse(line);
          if (reading != null) {
            print('BLE PARSEADO: ${reading.value} ${reading.unit}');
            _weightController.add(reading);
          }
        }
      }

      // Evitar acumulación infinita
      if (_buffer.length > 200) _buffer = '';
    } catch (e) {
      print('BLE PARSE ERROR: $e');
    }
  }

  /// Envía un comando a la báscula
  Future<void> sendCommand(String command) async {
    if (!_isConnected || _writeChar == null) return;
    try {
      final char = _writeChar!;
      if (char.properties.write || char.properties.writeWithoutResponse) {
        await char.write(command.codeUnits,
            withoutResponse: char.properties.writeWithoutResponse);
      }
    } catch (_) {}
  }

  Future<void> tare()       => sendCommand('T\r\n');
  Future<void> zero()       => sendCommand('Z\r\n');
  Future<void> toggleUnit() => sendCommand('C\r\n');
  Future<void> readWeight() => sendCommand('R\r\n');

  /// Desconecta del dispositivo BLE
  Future<void> disconnect() async {
    _dataSub?.cancel();
    _dataSub = null;
    _connectionSub?.cancel();
    _connectionSub = null;
    try { await _device?.disconnect(); } catch (_) {}
    _device = null;
    _weightChar = null;
    _writeChar = null;
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
