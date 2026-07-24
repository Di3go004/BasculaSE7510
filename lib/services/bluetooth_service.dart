import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/weight_reading.dart';

/// Maneja la conexión BLE con el indicador de peso.
/// La báscula L250920 usa Bluetooth Low Energy (GATT) con la característica
/// 00002af0-0000-1000-8000-00805f9b34fb para enviar datos de peso.
class ScaleBluetoothService {
  // UUID de la característica de peso (capturado del WeighingBluetooth)
  static const String _weightCharUuid = '00002af0-0000-1000-8000-00805f9b34fb';

  final StreamController<WeightReading> _weightController =
      StreamController<WeightReading>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _weightChar;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamSubscription<List<int>>? _dataSub;
  String _buffer = '';
  bool _isConnected = false;

  Stream<WeightReading> get weightStream => _weightController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  bool get isConnected => _isConnected;

  /// Devuelve la lista de dispositivos BLE ya emparejados/conocidos
  /// que coincidan con la dirección MAC del parámetro, o todos si está vacío.
  Future<List<Map<String, String>>> getPairedDevices() async {
    // Para BLE, usamos los dispositivos del sistema (bonded + conocidos)
    final bonded = await FlutterBluePlus.bondedDevices;
    final connected = FlutterBluePlus.connectedDevices;

    final all = <BluetoothDevice>{...bonded, ...connected};

    // Si la lista está vacía, intentar con system devices
    if (all.isEmpty) {
      final sys = await FlutterBluePlus.systemDevices([]);
      all.addAll(sys);
    }

    return all.map((d) => {
      'name':    d.platformName.isNotEmpty ? d.platformName : 'Dispositivo BLE',
      'address': d.remoteId.str,
    }).toList();
  }

  /// Escanea brevemente y devuelve dispositivos BLE + bonded.
  Future<List<Map<String, String>>> scanAndGetDevices() async {
    final result = <String, Map<String, String>>{};

    // Agregar dispositivos ya conocidos
    try {
      final bonded = await FlutterBluePlus.bondedDevices;
      for (final d in bonded) {
        result[d.remoteId.str] = {
          'name':    d.platformName.isNotEmpty ? d.platformName : 'Dispositivo BLE',
          'address': d.remoteId.str,
        };
      }
    } catch (_) {}

    // Escanear 4 segundos para encontrar dispositivos BLE activos
    try {
      if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on) {
        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
        // Usar listen en vez de await for para no colgar el hilo
        final sub = FlutterBluePlus.scanResults.listen((results) {
          for (final r in results) {
            final name = r.device.platformName.isNotEmpty
                ? r.device.platformName
                : (r.advertisementData.advName.isNotEmpty
                    ? r.advertisementData.advName
                    : 'Dispositivo BLE');
            result[r.device.remoteId.str] = {
              'name':    name,
              'address': r.device.remoteId.str,
            };
          }
        });
        
        await Future.delayed(const Duration(seconds: 4));
        await FlutterBluePlus.stopScan();
        await sub.cancel();
      }
    } catch (_) {}

    return result.values.toList();
  }

  /// Conecta a un dispositivo BLE por su dirección MAC.
  /// Devuelve null si tuvo éxito, o un String con el error.
  Future<String?> connect(String address) async {
    try {
      await disconnect();

      final device = BluetoothDevice(remoteId: DeviceIdentifier(address));
      _device = device;

      // Conectar con timeout
      await device.connect(timeout: const Duration(seconds: 15));
      _isConnected = true;
      _connectionController.add(true);

      // Escuchar desconexiones
      _connectionSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _isConnected = false;
          _connectionController.add(false);
          _buffer = '';
        }
      });

      // Descubrir servicios
      final services = await device.discoverServices();

      // Buscar la característica de peso
      BluetoothCharacteristic? weightChar;
      print("---- SERVICIOS DESCUBIERTOS ----");
      for (final service in services) {
        print("Servicio: ${service.uuid.toString()}");
        for (final char in service.characteristics) {
          final u = char.uuid.toString().toLowerCase();
          final props = char.properties;
          print("  - Característica: $u (notify: ${props.notify}, indicate: ${props.indicate}, read: ${props.read})");
          
          if (u.contains('2af0') || u == _weightCharUuid) {
            weightChar = char;
            print("  *** ¡ENCONTRADA CARACTERÍSTICA DE PESO 2AF0! ***");
          }
        }
      }
      print("--------------------------------");

      if (weightChar == null) {
        // Fallback inteligente: buscar una que tenga notify y NO sea la 2a05 (Service Changed)
        for (final service in services) {
          for (final char in service.characteristics) {
            final u = char.uuid.toString().toLowerCase();
            if (u.contains('2a05')) continue; // Saltar Service Changed
            
            if (char.properties.notify || char.properties.indicate) {
              weightChar = char;
              print("  *** USANDO FALLBACK: $u ***");
              break;
            }
          }
          if (weightChar != null) break;
        }
      }

      if (weightChar == null) {
        await device.disconnect();
        _isConnected = false;
        _connectionController.add(false);
        return 'No se encontró la característica de peso en el dispositivo BLE';
      }

      _weightChar = weightChar;

      // Activar notificaciones
      await weightChar.setNotifyValue(true);

      // Escuchar datos
      _dataSub = weightChar.lastValueStream.listen(_onData);

      return null;
    } catch (e) {
      _isConnected = false;
      _connectionController.add(false);
      return 'Error BLE: ${e.toString()}';
    }
  }

  void _onData(List<int> data) {
    if (data.isEmpty) return;
    
    // LOGS PARA DEPURAR EL FORMATO
    print("BLE RAW BYTES: $data");

    try {
      final str = utf8.decode(data, allowMalformed: true);
      print("BLE CHUNK: '$str'");

      _buffer += str;
      print("BLE BUFFER ACTUAL: '$_buffer'");

      // Intentar parsear el buffer
      final reading = WeightReading.parse(_buffer);
      if (reading != null) {
        print("BLE PARSEADO EXITOSO: ${reading.value} ${reading.unit}");
        _weightController.add(reading);
        _buffer = ''; // Limpiar buffer si fue exitoso
      } else if (_buffer.length > 200) {
        print("BLE BUFFER OVERFLOW, LIMPIANDO");
        _buffer = ''; // Evitar acumulación infinita
      }
    } catch (e) {
      print("BLE PARSE ERROR: $e");
    }
  }

  /// Envía un comando a la báscula (si soporta escritura)
  Future<void> sendCommand(String command) async {
    if (!_isConnected || _weightChar == null) return;
    try {
      final char = _weightChar!;
      if (char.properties.write || char.properties.writeWithoutResponse) {
        await char.write(command.codeUnits, withoutResponse: char.properties.writeWithoutResponse);
      }
    } catch (_) {}
  }

  Future<void> tare()        => sendCommand('T');
  Future<void> zero()        => sendCommand('Z');
  Future<void> toggleUnit()  => sendCommand('C');
  Future<void> readWeight()  => sendCommand('R');

  /// Desconecta del dispositivo BLE
  Future<void> disconnect() async {
    _dataSub?.cancel();
    _dataSub = null;
    _connectionSub?.cancel();
    _connectionSub = null;
    try { await _device?.disconnect(); } catch (_) {}
    _device = null;
    _weightChar = null;
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
