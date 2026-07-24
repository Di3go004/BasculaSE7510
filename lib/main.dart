import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();
  runApp(const Se7510App());
}

/// Solicita los permisos necesarios para Bluetooth en Android 12+
Future<void> _requestPermissions() async {
  await [
    Permission.bluetooth,
    Permission.bluetoothConnect,
    Permission.bluetoothScan,
    Permission.location, // Requerido por Android para BT clásico
  ].request();
}

class Se7510App extends StatelessWidget {
  const Se7510App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Báscula SE7510',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}
