/// Representa una lectura de peso del indicador SE7510.
/// Formato recibido: "ST,GS,+,  12.50,kg\r\n"
class WeightReading {
  final double value;
  final String unit;       // "kg" o "lb"
  final bool isStable;     // ST = estable, US = inestable
  final bool isGross;      // GS = bruto, NT = neto
  final bool isOverload;   // OL = sobrecarga
  final bool isNegative;
  final DateTime timestamp;

  WeightReading({
    required this.value,
    required this.unit,
    required this.isStable,
    required this.isGross,
    required this.isOverload,
    required this.isNegative,
    required this.timestamp,
  });

  /// Parsea la cadena que envía el SE7510 en modo PC continuo (C18=4)
  /// Ejemplo: "ST,GS,+,  12.50,kg"
  static WeightReading? parse(String raw) {
    try {
      final line = raw.trim();
      if (line.isEmpty) return null;

      // 1. Intentar parseo clásico por comas (Ej: ST,GS,+,  12.50,kg)
      if (line.contains(',')) {
        final parts = line.split(',');
        if (parts.length >= 5) {
          final statusStr = parts[0].trim().toUpperCase();
          final modeStr = parts[1].trim().toUpperCase();
          final signStr = parts[2].trim();
          final valueStr = parts[3].trim();
          final unitStr = parts[4].trim().toLowerCase();

          return WeightReading(
            value: double.tryParse(valueStr) ?? 0.0,
            unit: unitStr.isNotEmpty ? unitStr : 'kg',
            isStable: statusStr == 'ST',
            isGross: modeStr == 'GS',
            isOverload: statusStr == 'OL',
            isNegative: signStr == '-',
            timestamp: DateTime.now(),
          );
        }
      }

      // 2. Parseo flexible mediante Regex para atrapar cosas como "+   35.0 kg" o "=12.34lb"
      // Busca un signo opcional, seguido de números y un punto decimal, y luego una unidad opcional
      final reg = RegExp(r'([+\-]?)[\s=]*([0-9]+\.?[0-9]*)\s*(kg|lb|g)?', caseSensitive: false);
      final match = reg.firstMatch(line);
      
      if (match != null) {
        final sign = match.group(1) ?? '';
        final valStr = match.group(2) ?? '0';
        final unitStr = (match.group(3) ?? 'kg').toLowerCase();
        
        return WeightReading(
          value: double.tryParse(valStr) ?? 0.0,
          unit: unitStr,
          isStable: true, // Asumimos estable si nos mandó el dato directo
          isGross: true,
          isOverload: false,
          isNegative: sign == '-',
          timestamp: DateTime.now(),
        );
      }
      
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Valor con signo
  double get signedValue => isNegative ? -value : value;

  /// Texto para mostrar en la UI
  String get displayValue {
    if (isOverload) return 'SOBRECARGA';
    return '${isNegative ? "-" : ""}${value.toStringAsFixed(2)} $unit';
  }

  String get modeLabel => isGross ? 'BRUTO' : 'NETO';
  String get stabilityLabel => isStable ? '● Estable' : '○ Inestable';
}
