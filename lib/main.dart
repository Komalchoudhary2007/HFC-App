import 'package:flutter/material.dart';
import 'package:hc20/hc20.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HFC App - HC20 Integration',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HC20HomePage(title: 'HFC App - HC20 Wearable'),
    );
  }
}

class HC20HomePage extends StatefulWidget {
  const HC20HomePage({super.key, required this.title});

  final String title;

  @override
  State<HC20HomePage> createState() => _HC20HomePageState();
}

class _HC20HomePageState extends State<HC20HomePage> {
  Hc20Client? _client;
  Hc20Device? _connectedDevice;
  bool _isScanning = false;
  bool _isConnected = false;
  List<Hc20Device> _discoveredDevices = [];
  String _statusMessage = 'Ready to scan for HC20 devices';
  
  // Real-time data
  int? _heartRate;
  int? _spo2;
  List<int>? _bloodPressure;
  double? _temperature;
  int? _batteryLevel;
  int? _steps;

  @override
  void initState() {
    super.initState();
    _initializeHC20Client();
  }

  Future<void> _initializeHC20Client() async {
    try {
      setState(() {
        _statusMessage = 'Initializing HC20 client...';
      });

      // Request Bluetooth permissions
      await _requestPermissions();

      // Create HC20 client with OAuth credentials
      _client = await Hc20Client.create(
        config: Hc20Config(
          clientId: 'your-client-id',  // Replace with actual client ID
          clientSecret: 'your-client-secret',  // Replace with actual client secret
        ),
      );

      setState(() {
        _statusMessage = 'HC20 client initialized. Ready to scan!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error initializing client: $e';
      });
    }
  }

  Future<void> _requestPermissions() async {
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ];

    for (final permission in permissions) {
      final status = await permission.request();
      if (status != PermissionStatus.granted) {
        setState(() {
          _statusMessage = 'Permission ${permission.toString()} not granted';
        });
      }
    }
  }

  void _startScanning() {
    if (_client == null) return;

    setState(() {
      _isScanning = true;
      _discoveredDevices.clear();
      _statusMessage = 'Scanning for HC20 devices...';
    });

    _client!.scan().listen(
      (device) {
        if (!_discoveredDevices.any((d) => d.id == device.id)) {
          setState(() {
            _discoveredDevices.add(device);
            _statusMessage = 'Found ${_discoveredDevices.length} device(s)';
          });
        }
      },
      onError: (error) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'Scan error: $error';
        });
      },
    );

    // Auto-stop scanning after 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (_isScanning) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'Scan completed. Found ${_discoveredDevices.length} device(s)';
        });
      }
    });
  }

  Future<void> _connectToDevice(Hc20Device device) async {
    if (_client == null) return;

    try {
      setState(() {
        _statusMessage = 'Connecting to ${device.name}...';
      });

      // Connect to device
      await _client!.connect(device);
      
      // Read device info
      final info = await _client!.readDeviceInfo(device);
      
      // Set time
      final now = DateTime.now();
      await _client!.setTime(
        device,
        timestamp: now.millisecondsSinceEpoch ~/ 1000,
        timezone: 8,
      );

      // Set user parameters
      await _client!.setParameters(device, {
        'user_info': {
          'name': 'HFC User',
          'gender': 1,
          'height': 175,
          'weight': 70,
        },
      });

      setState(() {
        _connectedDevice = device;
        _isConnected = true;
        _statusMessage = 'Connected to ${info.name} v${info.version}';
      });

      // Start listening to real-time data
      _startRealtimeDataStream(device);

    } catch (e) {
      setState(() {
        _statusMessage = 'Connection failed: $e';
      });
    }
  }

  void _startRealtimeDataStream(Hc20Device device) {
    _client!.realtimeV2(device).listen(
      (data) {
        setState(() {
          if (data.heart != null) _heartRate = data.heart;
          if (data.spo2 != null) _spo2 = data.spo2;
          if (data.bp != null) _bloodPressure = data.bp;
          if (data.temperature != null && data.temperature!.isNotEmpty) {
            _temperature = data.temperature![0] / 100.0;
          }
          if (data.battery != null) _batteryLevel = data.battery!.percent;
          if (data.basicData != null && data.basicData!.isNotEmpty) {
            _steps = data.basicData![0];
          }
        });
      },
      onError: (error) {
        setState(() {
          _statusMessage = 'Real-time data error: $error';
        });
      },
    );
  }

  Future<void> _disconnect() async {
    if (_client == null || _connectedDevice == null) return;

    try {
      await _client!.disconnect(_connectedDevice!);
      setState(() {
        _connectedDevice = null;
        _isConnected = false;
        _statusMessage = 'Disconnected';
        // Clear real-time data
        _heartRate = null;
        _spo2 = null;
        _bloodPressure = null;
        _temperature = null;
        _batteryLevel = null;
        _steps = null;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Disconnect error: $e';
      });
    }
  }

  Future<void> _getHistoryData() async {
    if (_client == null || _connectedDevice == null) return;

    try {
      setState(() {
        _statusMessage = 'Fetching history data...';
      });

      final now = DateTime.now();
      
      // Get today's summary
      final summaryRows = await _client!.getAllDaySummaryRows(
        _connectedDevice!,
        yy: now.year % 100,
        mm: now.month,
        dd: now.day,
      );

      // Get heart rate data
      final heartRows = await _client!.getAllDayHeartRows(
        _connectedDevice!,
        yy: now.year % 100,
        mm: now.month,
        dd: now.day,
      );

      // Get HRV data (includes auto cloud upload)
      final hrvRows = await _client!.getAllDayHrvRows(
        _connectedDevice!,
        yy: now.year % 100,
        mm: now.month,
        dd: now.day,
      );

      setState(() {
        _statusMessage = 'History: ${summaryRows.length} summary, ${heartRows.length} heart, ${hrvRows.length} HRV records';
      });

    } catch (e) {
      setState(() {
        _statusMessage = 'History fetch error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(_statusMessage),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                          color: _isConnected ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(_isConnected ? 'Connected' : 'Disconnected'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),

            // Control buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isScanning || _isConnected ? null : _startScanning,
                    child: Text(_isScanning ? 'Scanning...' : 'Scan Devices'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isConnected ? _disconnect : null,
                    child: const Text('Disconnect'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            ElevatedButton(
              onPressed: _isConnected ? _getHistoryData : null,
              child: const Text('Get History Data'),
            ),

            const SizedBox(height: 16),

            // Real-time data section
            if (_isConnected) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Real-time Data',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      _buildDataRow('Heart Rate', _heartRate?.toString(), 'bpm'),
                      _buildDataRow('SpO2', _spo2?.toString(), '%'),
                      _buildDataRow('Blood Pressure', 
                          _bloodPressure != null ? '${_bloodPressure![0]}/${_bloodPressure![1]}' : null, 
                          'mmHg'),
                      _buildDataRow('Temperature', _temperature?.toStringAsFixed(1), '°C'),
                      _buildDataRow('Steps', _steps?.toString(), ''),
                      _buildDataRow('Battery', _batteryLevel?.toString(), '%'),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Discovered devices
            if (_discoveredDevices.isNotEmpty) ...[
              Text(
                'Discovered Devices',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _discoveredDevices.length,
                  itemBuilder: (context, index) {
                    final device = _discoveredDevices[index];
                    return Card(
                      child: ListTile(
                        title: Text(device.name),
                        subtitle: Text(device.id),
                        trailing: ElevatedButton(
                          onPressed: _isConnected ? null : () => _connectToDevice(device),
                          child: const Text('Connect'),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String? value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value != null ? '$value $unit' : 'N/A',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: value != null ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (_isConnected && _connectedDevice != null) {
      _client?.disconnect(_connectedDevice!);
    }
    super.dispose();
  }
}
