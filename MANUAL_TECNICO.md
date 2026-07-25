#  Manual Técnico — App Báscula SE7510
### Soluciones Exactas S.A. | Versión 1.0.0

---

## 1. Descripción General

La aplicación **Báscula SE7510** es una aplicación móvil desarrollada en **Flutter** para Android. Su propósito es recibir en tiempo real las lecturas de peso de la báscula industrial **SE7510** a través de una conexión **Bluetooth Low Energy (BLE/GATT)**, mostrarlas en pantalla y guardar un historial de pesajes que puede ser exportado y compartido.

---

## 2. Tecnología Utilizada

| Componente        | Tecnología / Versión               |
|-------------------|------------------------------------|
| Framework         | Flutter / Dart ^3.12.2             |
| Plataforma        | Android (API 21+)                  |
| Bluetooth         | BLE (GATT) via `flutter_blue_plus` |
| Estado UI         | StatefulWidget (Flutter nativo)    |
| Compartir         | `share_plus`                       |
| Archivos temp.    | `path_provider`                    |
| Links / WhatsApp  | `url_launcher`                     |
| Permisos          | `permission_handler`               |

---

## 3. Estructura del Proyecto

```
lib/
├── main.dart                    ← Punto de entrada de la app
├── models/
│   └── weight_reading.dart      ← Modelo de datos de una lectura de peso
├── screens/
│   ├── home_screen.dart         ← Pantalla principal (monitor de peso)
│   └── connect_screen.dart      ← Pantalla de búsqueda y conexión BLE
└── services/
    └── bluetooth_service.dart   ← Toda la lógica de Bluetooth BLE
```

---

## 4. Arquitectura de la Aplicación

```
                ┌─────────────────────┐
                │      main.dart      │
                │  Solicita permisos  │
                │  Inicia HomeScreen  │
                └────────┬────────────┘
                         │
                         ▼
          ┌──────────────────────────────┐
          │        HomeScreen            │
          │  ┌────────────────────────┐  │
          │  │  ScaleBluetoothService │  │
          │  │  (bluetooth_service)   │  │
          │  └───────────┬────────────┘  │
          │              │ Stream        │
          │              ▼               │
          │  ┌────────────────────────┐  │
          │  │    WeightReading       │  │
          │  │    (modelo de datos)   │  │
          │  └────────────────────────┘  │
          └──────────────────────────────┘
                         │
                         │ Navigator.push
                         ▼
          ┌──────────────────────────────┐
          │       ConnectScreen          │
          │  Muestra dispositivos BLE    │
          │  El usuario selecciona uno   │
          └──────────────────────────────┘
```

---

## 5. Archivos — Descripción Detallada

### 5.1 `main.dart`

**Función:** Punto de entrada de la aplicación.

**¿Qué hace exactamente?**
1. Llama a `WidgetsFlutterBinding.ensureInitialized()` para inicializar el framework antes de hacer cualquier cosa.
2. Solicita los permisos de Android **antes** de mostrar la pantalla:
   - `bluetooth` (Android 11 e inferior)
   - `bluetoothConnect` (para conectarse)
   - `bluetoothScan` (para escanear)
   - `location` (requerido por Android para BT)
3. Lanza `Se7510App`, que configura el tema oscuro y carga `HomeScreen`.

---

### 5.2 `models/weight_reading.dart`

**Función:** Define el modelo de datos `WeightReading`. Es la "plantilla" que describe cómo se ve una lectura de peso dentro de la app.

**Propiedades del modelo:**

| Propiedad       | Tipo       | Descripción                                       |
|-----------------|------------|---------------------------------------------------|
| `value`         | `double`   | Valor numérico del peso (ej: `40.0`)              |
| `unit`          | `String`   | Unidad: `"kg"` o `"lb"`                           |
| `decimalPlaces` | `int`      | Decimales dinámicos según lo que mande la báscula |
| `isStable`      | `bool`     | `true` si la báscula envía `ST` (Stable)          |
| `isGross`       | `bool`     | `true` si es peso bruto (GS), `false` si es neto  |
| `isOverload`    | `bool`     | `true` si la báscula envía `OL` (sobrecarga)      |
| `isNegative`    | `bool`     | `true` si el peso es negativo                     |
| `timestamp`     | `DateTime` | Fecha y hora exacta en que se recibió la lectura  |

**Método clave: `WeightReading.parse(String raw)`**

Este es el corazón del modelo. Recibe el texto crudo de la báscula y lo convierte en un objeto `WeightReading`. Tiene **dos estrategias de parseo**:

**Estrategia 1 — Formato por comas** (Modo C18=2 del SE7510):
```
Texto recibido:  "ST,GS,+,  40.00,kg"
                  ─┬─  ─┬─  ┬  ──┬──  ─┬─
                   │    │   │    │      └── Unidad
                   │    │   │    └───────── Valor numérico
                   │    │   └────────────── Signo (+ o -)
                   │    └────────────────── Modo (GS=bruto, NT=neto)
                   └─────────────────────── Estado (ST=estable, US=inestable, OL=sobrecarga)
```

**Estrategia 2 — Formato Regex flexible** (para formatos no estándar):
Si el texto no tiene comas, intenta reconocer patrones como:
- `"+   35.0 kg"`
- `"=12.34lb"`
- `"ST 100.5 kg"`

---

### 5.3 `services/bluetooth_service.dart`

**Función:** Contiene TODA la lógica de comunicación Bluetooth.

> **Protocolo:** BLE (Bluetooth Low Energy / GATT)
> UUID de la característica de datos: `00002af0-0000-1000-8000-00805f9b34fb`

**Flujo de conexión paso a paso:**

```
1. Usuario toca "Conectar"
        │
        ▼
2. scanAndGetDevices()
   ├── Lee dispositivos ya emparejados (bondedDevices)
   └── Escanea BLE por 4 segundos
        │
        ▼
3. Usuario selecciona su báscula de la lista
        │
        ▼
4. connect(address)
   ├── Crea BluetoothDevice con la dirección MAC
   ├── device.connect() — timeout de 10 segundos
   ├── discoverServices() — explora canales del módulo BT
   ├── Busca característica de LECTURA (UUID 2af0 o la que tenga notify)
   ├── Busca característica de ESCRITURA (write/writeWithoutResponse)
   └── weightChar.setNotifyValue(true) — activa notificaciones automáticas
        │
        ▼
5. La báscula envía datos en Modo Continuo (C18=2)
        │
        ▼
6. _onDataReceived(data)
   ├── Acumula bytes en buffer
   ├── Cuando encuentra "\n", extrae la línea completa
   └── WeightReading.parse(line) → envía al Stream
        │
        ▼
7. HomeScreen recibe dato por Stream → actualiza pantalla
```

**Streams (canales de datos reactivos):**

| Stream             | Tipo            | Descripción                                       |
|--------------------|-----------------|---------------------------------------------------|
| `weightStream`     | `WeightReading` | Emite una lectura nueva cada vez que llega dato   |
| `connectionStream` | `bool`          | Emite `true` al conectar, `false` al desconectar  |

**Comandos disponibles (solo en Modo C18=3):**

| Método          | Comando enviado | Función                  |
|-----------------|-----------------|--------------------------|
| `tare()`        | `T\r\n`         | Guarda y borra la tara   |
| `zero()`        | `Z\r\n`         | Pone a cero el peso bruto|
| `toggleUnit()`  | `C\r\n`         | Cambia entre kg y lb     |
| `readWeight()`  | `R\r\n`         | Solicita lectura puntual |

> **Nota:** En Modo Continuo (C18=2) la báscula ignora los comandos, pero envía datos automáticamente. Los botones de comando funcionan solo en C18=3 con cable RX conectado.

---

### 5.4 `screens/connect_screen.dart`

**Función:** Pantalla de búsqueda y selección de dispositivos BLE.

**¿Qué hace exactamente?**
1. Al abrirse, pide los permisos de Bluetooth y ubicación.
2. Muestra dispositivos ya emparejados + escanea 4 segundos.
3. Resalta en azul dispositivos cuyo nombre contenga "l250", "weigh" o "scale".
4. Al tocar un dispositivo, muestra spinner de carga mientras conecta.
5. Si conecta exitosamente → cierra y regresa `true` a `HomeScreen`.
6. Si falla → muestra mensaje de error en rojo.

---

### 5.5 `screens/home_screen.dart`

**Función:** Pantalla principal. Lo que el operador ve todo el tiempo.

**Mapa visual de la pantalla:**

```
┌─────────────────────────────────────────┐
│  SOLUCIONES EXACTAS S.A.     [● verde]  │  ← AppBar (título clickable → sitio web)
├─────────────────────────────────────────┤
│                                         │
│     ┌─────────────────────────────┐     │
│     │ BRUTO    ● Estable          │     │  ← Display LCD
│     │                             │     │    (borde VERDE = estable)
│     │       60.00 kg              │     │    (borde AZUL  = inestable)
│     │  Última lectura: 17:23:00   │     │
│     └─────────────────────────────┘     │
│                                         │
│     [ ↓  GUARDAR PESAJE ]               │  ← Activo solo si hay conexión
│                                         │
│  ┌─────────────────────────────────┐    │
│  │ 3  60.00 kg  2026-07-24  [🗑] │    │
│  │ 2  100.00 kg 2026-07-24  [🗑] │    │  ← Lista de pesajes guardados
│  │ 1  100.00 kg 2026-07-24  [🗑] │    │
│  └─────────────────────────────────┘    │
│                                         │
│  [  Desconectar ]  [  Exportar ]   │  ← Fila de acciones
├─────────────────────────────────────────┤
│  SOLUCIONES EXACTAS S.A.                │
│       [ 💬 +502 5968-5590 ]             │  ← Footer (toca para WhatsApp)
│  © 2026 Soluciones Exactas S.A.         │
└─────────────────────────────────────────┘
```

**Estados del display LCD:**
- **Borde Verde + "● Estable":** La báscula reporta `ST` — el peso es estable.
- **Borde Azul + "○ Inestable":** La báscula reporta `US` — el peso se está moviendo.
- **Texto "SOBRECARGA":** La báscula reporta `OL` — el peso supera la capacidad.

**Función Exportar:**
1. Abre diálogo para escribir el nombre del archivo.
2. Elegir formato: **Excel (.csv)** o **Texto (.txt)**.
3. Genera el archivo en memoria temporal del teléfono.
4. Abre menú nativo de Android para compartir (WhatsApp, correo, Drive, etc.).

**Formato del CSV generado:**
```csv
#,Peso,Unidad,Estado,Modo,Fecha,Hora
1,60.00,kg,Estable,Bruto,2026-07-24,17:23:00
2,100.00,kg,Estable,Bruto,2026-07-24,17:22:30
```

---

## 6. Comunicación con la Báscula SE7510

### Configuración recomendada de la báscula

| Parámetro | Valor | Descripción                                 |
|-----------|-------|---------------------------------------------|
| C18       | 2     | Modo Continuo (envía datos automáticamente) |

En este modo la báscula envía una línea de texto cada ciertos milisegundos:
```
ST,GS,+,  40.00,kg\r\n
```

### Comandos del SE7510 (Sección 5.3 del manual)

Solo disponibles en **Modo Comando (C18=3)**:

| Comando | Nombre  | Función                    |
|---------|---------|----------------------------|
| `T`     | TARE    | Guarda y borra la tara     |
| `Z`     | ZERO    | Pone a cero el peso bruto  |
| `P`     | PRINT   | Imprime el peso            |
| `R`     | G.W/N.W | Lee el peso bruto o neto  |
| `C`     | Kg/lb   | Cambia la unidad de medida |
| `G`     | G.W     | Verifica peso bruto/neto   |

---

## 7. Permisos de Android (`AndroidManifest.xml`)

| Permiso                 | Propósito                               |
|-------------------------|-----------------------------------------|
| `BLUETOOTH`             | BT básico (Android ≤ 11)               |
| `BLUETOOTH_ADMIN`       | Administración BT (Android ≤ 11)       |
| `BLUETOOTH_SCAN`        | Escanear dispositivos (Android 12+)    |
| `BLUETOOTH_CONNECT`     | Conectarse a dispositivos (Android 12+)|
| `ACCESS_FINE_LOCATION`  | Requerido por Android para usar BT     |
| `ACCESS_COARSE_LOCATION`| Requerido por Android para usar BT     |
| Intent `https/http`     | Abrir navegador (Android 11+)          |
| Intent `whatsapp`       | Abrir WhatsApp (Android 11+)           |

---

## 8. Dependencias (`pubspec.yaml`)

| Paquete                  | Versión   | Uso                                       |
|--------------------------|-----------|-------------------------------------------|
| `flutter_blue_plus`      | ^1.35.5   | Comunicación Bluetooth BLE con la báscula |
| `permission_handler`     | ^11.0.1   | Solicitar permisos en ejecución           |
| `share_plus`             | ^10.1.0   | Menú nativo de Android para compartir     |
| `path_provider`          | ^2.1.4    | Crear archivos temporales para exportar   |
| `url_launcher`           | ^6.3.2    | Abrir navegador y WhatsApp                |
| `shared_preferences`     | ^2.2.2    | Guardar configuraciones locales           |
| `flutter_launcher_icons` | ^0.13.1   | (Dev) Genera íconos de la app             |
| `flutter_native_splash`  | ^2.4.1    | (Dev) Genera pantalla de carga            |

---

## 9. Comandos de Compilación y Despliegue

```powershell
# Instalar dependencias
flutter pub get

# Regenerar iconos (si se cambia assets/logo.png)
flutter pub run flutter_launcher_icons

# Regenerar pantalla de carga
flutter pub run flutter_native_splash:create

# Correr en modo debug con teléfono conectado
flutter run

# Compilar APK de producción
flutter build apk --release
# APK queda en: build\app\outputs\flutter-apk\app-release.apk
```

### Instalar APK en otro teléfono
1. Ejecutar `flutter build apk --release`
2. Copiar `app-release.apk` al teléfono (USB, WhatsApp, Drive…)
3. Activar "Fuentes desconocidas" en el teléfono destino
4. Abrir el APK e instalar

---

## 10. Solución de Problemas Comunes

| Problema                                  | Causa probable                     | Solución                                                          |
|-------------------------------------------|------------------------------------|-------------------------------------------------------------------|
| App no encuentra la báscula               | BT del celular apagado             | Encender Bluetooth y verificar que la báscula esté emparejada     |
| "Sin conexión" aunque esté cerca          | Módulo BT de la báscula apagado    | Verificar que el LED del módulo BT esté activo                    |
| El peso no se actualiza en pantalla       | UUID del módulo BT no reconocido   | En Android Studio buscar "SERVICIOS DESCUBIERTOS" en los logs     |
| Dice "SOBRECARGA"                         | Peso supera la capacidad máxima    | Retirar el exceso de peso                                         |
| El botón Exportar está desactivado        | No hay pesajes guardados           | Guardar al menos un pesaje primero                                |
| El link del título no abre el navegador   | Permisos no actualizados           | Reinstalar la app completa (Stop + Play, no Hot Reload)           |
| Pantalla de carga muestra cuadro blanco   | Imagen sin fondo transparente      | Reemplazar `assets/logo.png` con PNG de fondo transparente        |

---

## 11. Contacto Soporte Técnico

**Empresa:** Soluciones Exactas S.A.
**Sitio web:** [https://www.soluciones-exactas.com](https://www.soluciones-exactas.com)
**WhatsApp:** +502 5968-5590

---

*Manual generado el 2026-07-25 | Versión de la app: 1.0.0+1*
