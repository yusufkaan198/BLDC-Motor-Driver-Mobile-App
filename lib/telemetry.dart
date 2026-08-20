class TelemetryData {
  final int rpm;
  final double current;
  final int duty;
  final double temperature;
  final DateTime timestamp;
  TelemetryData({
    required this.rpm,
    required this.current,
    required this.duty,
    required this.temperature,
    required this.timestamp,
  });

  static TelemetryData? _lastValid;

  static const int _maxRpmJump = 2000;
  static const int _maxConsecutiveRejections = 2;
  static int _consecutiveRejections = 0;

  static TelemetryData? parse(String line) {
    try {
      final cleaned = line.trim().replaceAll(RegExp(r'[^\x20-\x7E]'), '');

      if (cleaned.isEmpty) return null;

      final parts = cleaned.split(',');
      if (parts.length != 4) return null;

      final rpm = int.tryParse(parts[0]);
      final current = double.tryParse(parts[1]);
      final duty = int.tryParse(parts[2]);
      final temperature = double.tryParse(parts[3]);

      if (rpm == null || current == null || duty == null || temperature == null) return null;

      if (rpm < 0 || rpm > 15000) return null;
      if (current < 0 || current > 20) return null;
      if (duty < 0 || duty > 100) return null;
      if (temperature < 0 || temperature > 100) return null;
      if (_lastValid != null) {
        final rpmDiff = (rpm - _lastValid!.rpm).abs();
        if (rpmDiff > _maxRpmJump) {
          _consecutiveRejections++;
          if (_consecutiveRejections < _maxConsecutiveRejections) {
            return null;
          }
        }
      }

      _consecutiveRejections = 0;
      final data = TelemetryData(rpm: rpm, current: current, duty: duty, temperature: temperature, timestamp: DateTime.now());
      _lastValid = data;
      return data;
    } catch (e) {
      return null;
    }
  }

  static void reset() {
    _lastValid = null;
    _consecutiveRejections = 0;
  }

  @override
  String toString() => 'RPM=$rpm I=${current}A duty=$duty T=$temperature°C';
}