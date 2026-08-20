import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:bluetooth_classic/models/device.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'telemetry.dart';

class BluetoothService {
  //final => bir kez atandıktan sonra değiştirilemeyen referans
  final BluetoothClassic  _bt = BluetoothClassic();

  //Telemetri yayını için broadcast stream
  final StreamController<TelemetryData> _telemetryController = StreamController<TelemetryData>.broadcast();

  //Dışarıdan dinlemek için kullanılan stream
  Stream<TelemetryData> get telemetryStream => _telemetryController.stream;

  //Yarım kalan satırları biriktirmek için buffer
  String _readBuffer = '';
  bool _isConnected = false;

  //Bluetooth paketinden gelen veri stream'inin aboneliği
  StreamSubscription<Uint8List>? _dataSubscription;
  //Telefonla eşleştirilmiş cihazları getirme
  //Future => bu fonksiyon hemen değil gelecekte sonuç verecek
  Future<List<Device>> getPairedDevices() async {
    try {
      final devices = await _bt.getPairedDevices();
      return devices;
    } catch (e) {
      return [];
    }
  }
  // HC-05 ve benzeri SPP cihazları için standart UUID
  static const String _sppUuid = "00001101-0000-1000-8000-00805f9b34fb";

  //Verilen MAC adresine sahip cihaza bağlanır.
  //Başarılıysa true, hatalıysa false döner.
  Future<bool> connect(String address) async {
    try {
      await _bt.connect(address, _sppUuid);
      _isConnected = true;
      _startListening(); //Bağlantı kurulduktan sonra data stream'ini dinlemeye başla
      return true;
    } catch (e) {
      return false;
    }
  }

  void _startListening() {
    _dataSubscription?.cancel();
    _readBuffer = '';

    _dataSubscription = _bt.onDeviceDataReceived().listen(
      _onDataReceived,
      onError: (error) {
      },
    );
  }

  void _onDataReceived(Uint8List bytes) {
    if (!_isConnected) return;
    //Byte'ları string'e çevirme
    final chunk = String.fromCharCodes(bytes);
    _readBuffer += chunk;

    while (true) {
      int newLineIndex = -1;
      for (int i = 0; i < _readBuffer.length; i++) {
        final c = _readBuffer[i];
        if (c == '\n' || c == '\r') {
          newLineIndex = i;
          break;
        }
      }

      if (newLineIndex == -1) break;

      final line = _readBuffer.substring(0, newLineIndex);
      _readBuffer = _readBuffer.substring(newLineIndex + 1);

      if (line.isEmpty) continue;

      final telemetry = TelemetryData.parse(line);
      if (telemetry != null) {
        _telemetryController.add(telemetry);
      }
    }
  }

  //Aktif bağlantıyı kapatır.
  Future<void> disconnect() async {
    _isConnected = false;
    _dataSubscription?.cancel();
    _dataSubscription = null;
    _readBuffer = '';
    TelemetryData.reset();
    await _bt.disconnect();
  }

  Future<bool> sendRpm(int rpm) async {
    try {
      final command = '$rpm\r';

      final success = await _bt.write(command);
      return success ?? false;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _dataSubscription?.cancel();
    _telemetryController.close();
  }
/*
  Future<bool> isBluetoothEnabled() async {
    return await _blueClassic.isEnabled;
  }

  Future<void> turnOnBluetooth() async {
    _blueClassic.turnOn();
  }
  */
}










