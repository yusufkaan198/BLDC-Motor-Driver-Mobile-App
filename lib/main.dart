import 'package:bldc_ui/telemetry.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bluetooth_classic/models/device.dart';
import 'bluetooth_service.dart';
import 'dart:async';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

enum ConnectionState {
  disconnected,
  connecting,
  connected,
}

void main() {
  runApp(const BldcApp());
}

class BldcApp extends StatelessWidget {
  const BldcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLDC Controller',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black38),
        scaffoldBackgroundColor: const Color(0xFF001524),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _permissionsGranted = false;
  bool _checkingPermissions = true;
  final BluetoothService _btService = BluetoothService();
  List<Device> _pairedDevices = [];
  bool _loadingDevices = false;
  ConnectionState _connectionState = ConnectionState.disconnected;
  Device? _connectedDevice;

  double _targetRpm = 0;
  int _lastSentRpm = -1;
  DateTime? _lastSendTime;
  Timer? _pendingSendTimer;

  static const int _throttleMs = 200;
  static const double _maxRpm = 11000;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
  }

  Future<void> _checkAndRequestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    final allGranted = statuses.values.every((s) => s.isGranted);

    setState(() {
      _permissionsGranted = allGranted;
      _checkingPermissions = false;
    });

    if (allGranted) {
      await _loadPairedDevices();
    }
  }

  Future<void> _loadPairedDevices() async {
    setState(() {
      _loadingDevices = true;
    });

    final devices = await _btService.getPairedDevices();

    setState(() {
      _pairedDevices = devices;
      _loadingDevices = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF001524),
      appBar: AppBar(
        title: const Text('BLDC Controller', style: TextStyle(color: Colors.white),),
        backgroundColor: Color(0xFF001524),
        actions: [
          if (_connectionState == ConnectionState.connected)
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled, color: Colors.white,),
              tooltip: 'Bağlantıyı kes',
              onPressed: _disconnect,
            )
        ],
      ),
      body: Center(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_checkingPermissions) {
      return const CircularProgressIndicator();
    }

    if (!_permissionsGranted) {
      return Padding(padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bluetooth_disabled, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Bluetooth izinleri reddedildi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8,),
          const Text(
            'Bu uygulama BLDC sürücünüze bağlanmak için Bluetooth izinlerine ihtiyaç duyuyor. '
            'Lütfen telefon ayarlarından izinleri verin.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24,),
          ElevatedButton.icon(
            icon: const Icon(Icons.settings),
            label: const Text('Ayarları Aç'),
            onPressed: () => openAppSettings(),
          ),
          const SizedBox(height: 8,),
          TextButton(
            onPressed: _checkAndRequestPermissions,
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
      );
    }

    if (_connectionState == ConnectionState.connected) {
      return _buildConnectedView();
    }

    if (_connectionState == ConnectionState.connecting) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.white,),
          const SizedBox(height: 16,),
          Text('${_connectedDevice?.name ?? "Cihaz"} cihazına bağlanılıyor...', style: TextStyle(color: Colors.grey),),
        ],
      );
    }

    return _buildDeviceList();
  }

  Widget _buildDeviceList() {
    if (_loadingDevices) {
      return const CircularProgressIndicator();
    }

    if (_pairedDevices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bluetooth_searching, size: 64,),
            const SizedBox(height: 16,),
            const Text(
              'Eşleştirilmiş cihaz yok',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8,),
            const Text(
              'HC-05 modülünü telefon Bluetooth ayarlarından eşleştirin,'
              'sonra bu sayfayı yenileyin.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24,),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Yenile'),
              onPressed: _loadPairedDevices,
            ),
          ],
        ),
      );
    }

    //Sadece ekranda görünen elemanları çizer, Column ise tüm elemanları aynı anda
    //çizer. Performans açısından daha uygun.
    return ListView.builder(
      itemCount: _pairedDevices.length,
      itemBuilder: (context, index) {
        final device = _pairedDevices[index];
        return ListTile(
          leading: const Icon(Icons.bluetooth, color: Colors.indigoAccent,),
          title: Text(device.name ?? 'İsimsiz Cihaz', style: TextStyle(color: Colors.white),),
          subtitle: Text(device.address, style: TextStyle(color: Colors.grey),),
          trailing: const Icon(Icons.chevron_right, color: Colors.white,),
          onTap: () => _connectToDevice(device),
        );
      },
    );
  }

  Future<void> _connectToDevice(Device device) async {
    setState(() {
      _connectionState = ConnectionState.connecting;
      _connectedDevice = device;
    });

    final success = await _btService.connect(device.address);

    if (success) {
      setState(() {
        _connectionState = ConnectionState.connected;
        _connectedDevice = device;
      });
      _showMessage('${device.name} cihazına bağlanıldı');
    }
    else {
      setState(() {
        _connectionState = ConnectionState.disconnected;
        _connectedDevice = null;
      });
      _showMessage('Bağlantı başarısız', isError: true);
    }
  }

  Future<void> _disconnect() async {
    _pendingSendTimer?.cancel();
    _pendingSendTimer = null;

    await _btService.disconnect();
    setState(() {
      _connectionState = ConnectionState.disconnected;
      _connectedDevice = null;
      _targetRpm = 0;
      _lastSentRpm = -1;
      _lastSendTime = null;
    });
    _showMessage('Bağlantı kesildi');
  }
  
  Future<void> _onRpmChanged(double newValue) async {
    setState(() {
      _targetRpm = newValue;
    });

    final rpmInt = newValue.round();

    if (rpmInt == _lastSentRpm) return;

    final now = DateTime.now();
    final elapsed = _lastSendTime == null ? const Duration(days: 1) : now.difference(_lastSendTime!);

    if (elapsed.inMilliseconds >= _throttleMs) {
      _sendRpmNow(rpmInt);
    }
    else {
      _pendingSendTimer?.cancel();
      final remaining = _throttleMs - elapsed.inMilliseconds;
      _pendingSendTimer = Timer(Duration(milliseconds: remaining), () {
        _sendRpmNow(_targetRpm.round());
      });
    }
  }

  void _onRpmChangeEnd(double finalValue) {
    _pendingSendTimer?.cancel();
    _pendingSendTimer = null;

    final rpmInt = finalValue.round();

    if (rpmInt != _lastSentRpm) {
      _sendRpmNow(rpmInt);
    }
  }

  Future<void> _sendRpmNow(int rpm) async {
    _lastSentRpm = rpm;
    _lastSendTime = DateTime.now();

    final success = await _btService.sendRpm(rpm);

    if (!success) {
      _showMessage('RPM gönderilemedi: $rpm', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        duration: const Duration(seconds: 2),
      )
    );
  }
  
  Widget _buildConnectedView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: const Color(0xFF001845),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 32,),
                  const SizedBox(width: 12,),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _connectedDevice?.name ?? 'Cihaz',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _connectedDevice?.address ?? '',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20,),

          const Text(
            'Hedef RPM',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16,),

          Center(
            child: SleekCircularSlider(
              min: 0,
              max: _maxRpm,
              initialValue: _targetRpm,
              appearance: CircularSliderAppearance(
                size: 250,
                startAngle: 150,
                angleRange: 240,
                customWidths: CustomSliderWidths(
                  trackWidth: 8,
                  progressBarWidth: 16,
                  handlerSize: 12,
                ),
                customColors: CustomSliderColors(
                  trackColor: Colors.white,
                  progressBarColor: Colors.blueAccent,
                  dotColor: Colors.blue.shade900,
                ),
                infoProperties: InfoProperties(
                  bottomLabelText: 'RPM',
                  bottomLabelStyle: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  mainLabelStyle: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white
                  ),
                  modifier: (value) => value.round().toString(),
                ),
              ),
              onChange: _onRpmChanged,
              onChangeEnd: _onRpmChangeEnd,
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickButton('DUR', 0),
              _buildQuickButton('2000', 2000),
              _buildQuickButton('6000', 6000),
              _buildQuickButton('10000', 10000),
            ],
          ),

          const SizedBox(height: 24,),

          StreamBuilder<TelemetryData>(
            stream: _btService.telemetryStream,
            builder: (context, snapshot) {
              final data = snapshot.data;
              return Column(
                children: [
                  Card(
                    color: Color(0xFF001845),
                    child: SizedBox(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          const Text(
                            'Mevcut RPM',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            data?.rpm.toString() ?? '---',
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12,),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.electric_bolt,
                              color: Colors.grey,
                            ),
                             const Text(
                              'Akım',
                               style: TextStyle(color: Colors.grey,),
                            ),
                            Text(
                              data != null ? '${data.current.toStringAsFixed(2)} A' : '---',
                              style: TextStyle(color: Colors.white,),
                            ),
                          ]
                        ),
                      ),
                      const SizedBox(width: 8,),
                      Expanded(
                        child: Column(
                            children: [
                              const Icon(
                                Icons.percent,
                                color: Colors.grey,
                              ),
                              const Text(
                                'Duty',
                                style: TextStyle(color: Colors.grey,),
                              ),
                              Text(
                                data != null ? '${data.duty}%' : '---',
                                style: TextStyle(color: Colors.white,),
                              ),
                            ]
                        ),
                      ),
                      const SizedBox(width: 8,),
                      Expanded(
                        child: Column(
                            children: [
                              const Icon(
                                Icons.thermostat,
                                color: Colors.grey,
                              ),
                              const Text(
                                'Sıcaklık',
                                style: TextStyle(color: Colors.grey,),
                              ),
                              Text(
                                data != null ? '${data.temperature.toStringAsFixed(1)}°C' : '---',
                                style: TextStyle(color: Colors.white,),
                              ),
                            ]
                        ),
                      ),
                    ],
                  )
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pendingSendTimer?.cancel();
    super.dispose();
  }

  Widget _buildQuickButton(String label, int rpm) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF001845), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))
      ),
      onPressed: () {
        setState(() {
          _targetRpm = rpm.toDouble();
        });
        _sendRpmNow(rpm);
      },
      child: Text(
        label,
        style: TextStyle(color: Colors.grey.shade200),
      ),
    );
  }
}











