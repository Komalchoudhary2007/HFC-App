import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hc20/hc20.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'background_service.dart';
import 'package:hc20/src/raw/config.dart' as config;

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _S();
}

class _MetricButtonConfig {
  final String label;
  final Hc20HistoryType type;
  final bool includeSummary;

  const _MetricButtonConfig(this.label, this.type,
      {this.includeSummary = false});
}

class _ConsoleLogEntry {
  final String message;
  final DateTime timestamp;
  final _LogType type;

  _ConsoleLogEntry(this.message, this.type)
      : timestamp = DateTime.now();

  Color get color {
    switch (type) {
      case _LogType.imu:
        return Colors.blue;
      case _LogType.ppg:
        return Colors.green;
      case _LogType.gsr:
        return Colors.orange;
      case _LogType.system:
        return Colors.grey;
    }
  }
}

enum _LogType { imu, ppg, gsr, system }

class _SensorDataRecord {
  final DateTime timestamp;
  final String sensorType;
  final int packetId;
  final int? timestampMs; // Device timestamp
  // IMU data
  final int? accelX, accelY, accelZ;
  final int? gyroX, gyroY, gyroZ;
  final int? magX, magY, magZ;
  // PPG data
  final int? ppgGreen, ppgRed, ppgIr;
  // GSR data
  final int? gsrI, gsrQ, gsrRaw;

  _SensorDataRecord({
    required this.timestamp,
    required this.sensorType,
    required this.packetId,
    this.timestampMs,
    this.accelX,
    this.accelY,
    this.accelZ,
    this.gyroX,
    this.gyroY,
    this.gyroZ,
    this.magX,
    this.magY,
    this.magZ,
    this.ppgGreen,
    this.ppgRed,
    this.ppgIr,
    this.gsrI,
    this.gsrQ,
    this.gsrRaw,
  });

  List<String> toCsvRow() {
    return [
      timestamp.toIso8601String(),
      sensorType,
      packetId.toString(),
      timestampMs?.toString() ?? '',
      accelX?.toString() ?? '',
      accelY?.toString() ?? '',
      accelZ?.toString() ?? '',
      gyroX?.toString() ?? '',
      gyroY?.toString() ?? '',
      gyroZ?.toString() ?? '',
      magX?.toString() ?? '',
      magY?.toString() ?? '',
      magZ?.toString() ?? '',
      ppgGreen?.toString() ?? '',
      ppgRed?.toString() ?? '',
      ppgIr?.toString() ?? '',
      gsrI?.toString() ?? '',
      gsrQ?.toString() ?? '',
      gsrRaw?.toString() ?? '',
    ];
  }

  static List<String> csvHeaders() {
    return [
      'Timestamp',
      'Sensor Type',
      'Packet ID',
      'Device Timestamp (ms)',
      'Accel X',
      'Accel Y',
      'Accel Z',
      'Gyro X',
      'Gyro Y',
      'Gyro Z',
      'Mag X',
      'Mag Y',
      'Mag Z',
      'PPG Green',
      'PPG Red',
      'PPG IR',
      'GSR I',
      'GSR Q',
      'GSR Raw',
    ];
  }
}

class _S extends State<MyApp> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Hc20Client? client;
  Hc20Device? selected;
  Hc20DeviceInfo? info;
  Hc20Time? deviceTime;
  Stream<Hc20RealtimeV2>? rtStream;
  Hc20RealtimeV2? lastRt;
  bool rtOn = false;
  String lastParams = '';
  String allDaySummary = '';
  String allDayAll = '';
  List<String> allDayLines = [];
  DateTime _histDate = DateTime.now();
  final List<Hc20Device> _scanResults = [];
  bool _isScanning = false;
  StreamSubscription<Hc20Device>? _scanSub;
  Timer? _scanTimer;
  String _status = '';
  
  // Raw sensor data console
  final List<_ConsoleLogEntry> _consoleLogs = [];
  StreamSubscription<Hc20ImuData>? _imuSub;
  StreamSubscription<Hc20PpgData>? _ppgSub;
  StreamSubscription<Hc20GsrData>? _gsrSub;
  bool _sensorsEnabled = false;
  final ScrollController _consoleScrollController = ScrollController();
  
  // Data recording for CSV export
  final List<_SensorDataRecord> _recordedData = [];
  bool _isRecording = false;
  
  // Background service
  bool _backgroundServiceEnabled = false;
  
  // App version info
  String? _appVersion;
  String? _appBuildNumber;
  
  // Development mode
  bool _isDevelopmentMode = false;
  
  // Connection state tracking
  StreamSubscription<Hc20ConnectionStateUpdate>? _connectionStateSub;
  Hc20ConnectionState? _currentConnectionState;
  DateTime? _lastConnectionStateUpdate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _createClient();
  }
  
  /// Get client credentials based on development mode
  Map<String, String> _getClientCredentials() {
      return {
        'clientId': 'your_client_id',
        'clientSecret': 'your_client_secret',
      };
    
  }
  
  /// Create or recreate the HC20 client with current configuration
  Future<void> _createClient() async {
    // Disconnect existing client if any
    if (client != null && selected != null) {
      try {
        await _disconnectDevice();
      } catch (e) {
        // Ignore errors during disconnect
      }
    }
    
    // Set development mode in config
    config.Hc20CloudConfig.isDevelopment = _isDevelopmentMode;
    
    // Get credentials based on mode
    final credentials = _getClientCredentials();
    
    // Create client with OAuth credentials
    final c = await Hc20Client.create(
      config: Hc20Config(
        clientId: credentials['clientId']!,
        clientSecret: credentials['clientSecret']!,
      ),
    );
    
    if (!mounted) return;
    
    setState(() => client = c);
    
    // Set up connection state listener
    _setupConnectionStateListener();
    
    await _ensurePermissions();
    // Initialize background service
    await BackgroundServiceManager.instance.initialize();
    // Check if background service was previously enabled
    final wasEnabled = await BackgroundServiceManager.instance.isEnabled();
    // Load app version info
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _backgroundServiceEnabled = wasEnabled;
      _appVersion = packageInfo.version;
      _appBuildNumber = packageInfo.buildNumber;
    });
  }
  
  /// Set up connection state listener
  void _setupConnectionStateListener() {
    // Cancel existing subscription if any
    _connectionStateSub?.cancel();
    
    if (client == null) return;
    
    // Listen to connection state changes
    _connectionStateSub = client!.connectionState.listen((update) {
      if (!mounted) return;
      
      setState(() {
        _currentConnectionState = update.state;
        _lastConnectionStateUpdate = update.timestamp;
        
        // Update selected device when connected or reconnected
        // This enables UI buttons (Read Device Info, Set Params, Get Params, Sync Time, etc.)
        if (update.state == Hc20ConnectionState.connected || 
            update.state == Hc20ConnectionState.reconnected) {
          selected = update.device;
        }
      });
      
      // Update status based on connection state
      String statusMessage = '';
      switch (update.state) {
        case Hc20ConnectionState.connected:
          statusMessage = 'Device connected: ${update.device.name}';
          break;
        case Hc20ConnectionState.reconnected:
          statusMessage = 'Device reconnected: ${update.device.name}';
          // Automatically enable background service on reconnection
          _enableBackgroundServiceOnConnection();
          break;
        case Hc20ConnectionState.disconnected:
          statusMessage = 'Device disconnected: ${update.device.name}';
          break;
      }
      
      if (statusMessage.isNotEmpty) {
        setState(() {
          _status = statusMessage;
        });
      }
    }, onError: (error) {
      if (!mounted) return;
      setState(() {
        _status = 'Connection state error: $error';
      });
    });
  }
  
  /// Toggle development mode and recreate client
  Future<void> _toggleDevelopmentMode(bool value) async {
    if (_isDevelopmentMode == value) return;
    
    setState(() {
      _isDevelopmentMode = value;
      _status = 'Switching to ${value ? "development" : "production"} mode...';
    });
    
    try {
      await _createClient();
      if (!mounted) return;
      setState(() {
        _status = 'Switched to ${value ? "development" : "production"} mode';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Error switching mode: $e';
      });
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _imuSub?.cancel();
    _ppgSub?.cancel();
    _gsrSub?.cancel();
    _consoleScrollController.dispose();
    _scanSub?.cancel();
    _scanTimer?.cancel();
    _connectionStateSub?.cancel();
    super.dispose();
  }
  
  /// Get human-readable connection state text
  String _getConnectionStateText(Hc20ConnectionState state) {
    switch (state) {
      case Hc20ConnectionState.connected:
        return 'Connected';
      case Hc20ConnectionState.reconnected:
        return 'Reconnected';
      case Hc20ConnectionState.disconnected:
        return 'Disconnected';
    }
  }
  
  /// Format DateTime for display
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App is going to background
      if (_backgroundServiceEnabled && _sensorsEnabled) {
        print('[AppLifecycle] App going to background, background service should keep running');
      }
    } else if (state == AppLifecycleState.resumed) {
      // App is coming to foreground
      if (_backgroundServiceEnabled && _sensorsEnabled) {
        print('[AppLifecycle] App resumed, background service is still running');
      }
    } else if (state == AppLifecycleState.detached) {
      // App is being terminated
      print('[AppLifecycle] App detached');
    }
  }

  Future<void> _ensurePermissions() async {
    final perms = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];
    for (final p in perms) {
      if (await p.status.isDenied || await p.status.isRestricted) {
        await p.request();
      }
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  List<String> _valueLines(Hc20AllDayRow row) {
    if (row.values.isEmpty) {
      return const ['• (no values)'];
    }
    return row.values.entries
        .map((e) => '• ${e.key}: ${e.value ?? '-'}')
        .toList();
  }

  String _formatRow(Hc20AllDayRow row) {
    final values =
        row.values.entries.map((e) => '${e.key}=${e.value ?? '-'}').join(', ');
    final valueText = values.isEmpty ? '(no values)' : values;
    final validity = row.valid ? '' : ' (invalid)';
    return '${row.dateTime}$validity  $valueText';
  }

  Future<void> _loadAllDayRows(Hc20HistoryType type, String label,
      {bool includeSummary = false}) async {
    final c = client;
    final device = selected;
    if (c == null || device == null) return;
    final yy = _histDate.year - 2000;
    final mm = _histDate.month;
    final dd = _histDate.day;
    print('HC20 DEBUG UI: _loadAllDayRows type=0x${type.typeId.toRadixString(16)} label=$label date=${_formatDate(_histDate)} (yy=$yy mm=$mm dd=$dd)');
    setState(() {
      allDayAll = '$label: loading...';
      allDayLines = const <String>[];
    });
    try {
      // Pre-check A: storage info dates list
      try {
        print('HC20 DEBUG UI: reading storage info...');
        final storageJson = await c.readStorageInfo(device);
        print('HC20 DEBUG UI: storage info JSON: $storageJson');
        if (storageJson.isNotEmpty) {
          final map = json.decode(storageJson) as Map<String, dynamic>;
          final dates = (map['dates'] as List?)?.cast<String>() ?? const <String>[];
          final sel = _formatDate(_histDate);
          print('HC20 DEBUG UI: storage dates=${dates.join(', ')} contains($sel)=${dates.contains(sel)}');
          if (!dates.contains(sel)) {
            setState(() {
              allDayAll = '$label: No data recorded for $sel on device';
              allDayLines = const <String>[];
            });
            return;
          }
        }
      } catch (_) {
        // ignore storage info errors; proceed to packet status
        print('HC20 DEBUG UI: storage info check failed/unsupported, continuing...');
      }

      // Pre-check B: packet statuses for the metric (skip for summary which is index 0)
      if (type != Hc20HistoryType.allDaySummary) {
        print('HC20 DEBUG UI: reading packet statuses for type=0x${type.typeId.toRadixString(16)} yy=$yy mm=$mm dd=$dd');
        final statuses = await _safeReadPacketStatuses(
          c,
          device,
          type.typeId,
          yy,
          mm,
          dd,
        );
        if (statuses != null) {
          final hex = statuses.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
          print('HC20 DEBUG UI: packet statuses len=${statuses.length} bytes=[$hex]');
          final hasAny = statuses.any((s) => s != 0);
          if (!hasAny) {
            final sel = _formatDate(_histDate);
            setState(() {
              allDayAll = '$label: No samples for $sel';
              allDayLines = const <String>[];
            });
            return;
          }
        } else {
          print('HC20 DEBUG UI: packet status read failed/unsupported, continuing to fetch...');
        }
      }

      print('HC20 DEBUG UI: fetching rows type=0x${type.typeId.toRadixString(16)}...');
      final rows = await _rowsForType(
        c,
        device,
        type,
        yy,
        mm,
        dd,
        includeSummary: includeSummary,
      );
      print('HC20 DEBUG UI: fetched ${rows.length} row(s)');
      if (!mounted) return;
      setState(() {
        final count = rows.length;
        final suffix = count == 1 ? '' : 's';
        allDayAll = '$label: $count row$suffix';
        allDayLines = rows.isEmpty
            ? const ['(no rows returned)']
            : rows.map(_formatRow).toList();
      });
    } catch (e) {
      if (!mounted) return;
      final friendly = _friendlyError(e);
      print('HC20 DEBUG UI: fetch error: $e  (friendly="$friendly")');
      setState(() {
        allDayAll = '$label: $friendly';
        allDayLines = const <String>[];
      });
    }
  }

  Future<void> _fetchDailySummary() async {
    final c = client;
    final device = selected;
    if (c == null || device == null) return;
    final yy = _histDate.year - 2000;
    final mm = _histDate.month;
    final dd = _histDate.day;
    print('HC20 DEBUG UI: _fetchDailySummary date=${_formatDate(_histDate)} (yy=$yy mm=$mm dd=$dd)');
    setState(() => allDaySummary = 'Loading summary...');
    try {
      // Pre-check: ensure selected date exists on device
      try {
        print('HC20 DEBUG UI: reading storage info (for summary)...');
        final storageJson = await c.readStorageInfo(device);
        print('HC20 DEBUG UI: storage info JSON: $storageJson');
        if (storageJson.isNotEmpty) {
          final map = json.decode(storageJson) as Map<String, dynamic>;
          final dates = (map['dates'] as List?)?.cast<String>() ?? const <String>[];
          final sel = _formatDate(_histDate);
          print('HC20 DEBUG UI: storage dates=${dates.join(', ')} contains($sel)=${dates.contains(sel)}');
          if (!dates.contains(sel)) {
            setState(() {
              allDaySummary = 'No data recorded for $sel on device.';
            });
            return;
          }
        }
      } catch (_) {
        // ignore storage info errors
        print('HC20 DEBUG UI: storage info read failed/unsupported for summary');
      }

      print('HC20 DEBUG UI: fetching daily summary rows...');
      final summaryRows = await c.getAllDaySummaryRows(
        device,
        yy: yy,
        mm: mm,
        dd: dd,
      );
    
      if (!mounted) return;
      final sb = StringBuffer();
      final dateLabel = _formatDate(_histDate);
      if (summaryRows.isEmpty) {
        sb.writeln('No daily summary data for $dateLabel.');
      } else {
        final row = summaryRows.first;
        sb.writeln(
            'Daily summary (${row.dateTime}) ${row.valid ? 'valid' : 'invalid'}');
        for (final line in _valueLines(row)) {
          sb.writeln(line);
        }
      }
     
      setState(() => allDaySummary = sb.toString());
    } catch (e) {
      if (!mounted) return;
      final friendly = _friendlyError(e);
      print('HC20 DEBUG UI: summary fetch error: $e  (friendly="$friendly")');
      setState(() => allDaySummary = 'Error loading summary: $friendly');
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    // Map 0xE2 specifically to a user-friendly message
    if (s.contains('Hc20Exception') && s.contains('code=0xe2')) {
      final dateLabel = _formatDate(_histDate);
      return 'No historical data for $dateLabel (device reported none).';
    }
    return s;
  }

  Future<List<int>?> _safeReadPacketStatuses(
    Hc20Client c,
    Hc20Device device,
    int typeId,
    int yy,
    int mm,
    int dd,
  ) async {
    try {
      final statuses = await c.readPacketStatuses(
        device,
        dataType: typeId,
        yy: yy,
        mm: mm,
        dd: dd,
      );
      return statuses;
    } catch (e) {
      final isE2 = e.toString().contains('Hc20Exception') && e.toString().contains('code=0xe2');
      print('HC20 DEBUG UI: readPacketStatuses error: $e  e2=$isE2');
      // Swallow errors; return null to signal unsupported/failure so we can fallback to direct fetch
      return null;
    }
  }

  Future<List<Hc20AllDayRow>> _rowsForType(
    Hc20Client c,
    Hc20Device device,
    Hc20HistoryType type,
    int yy,
    int mm,
    int dd, {
    bool includeSummary = false,
  }) {
    switch (type) {
      case Hc20HistoryType.allDaySummary:
        return c.getAllDaySummaryRows(device, yy: yy, mm: mm, dd: dd);
      case Hc20HistoryType.heart5s:
        return c.getAllDayHeartRows(
          device,
          yy: yy,
          mm: mm,
          dd: dd,
        );
      case Hc20HistoryType.steps5m:
        return c.getAllDayStepsRows(device, yy: yy, mm: mm, dd: dd);
      case Hc20HistoryType.spo25m:
        return c.getAllDaySpo2Rows(device, yy: yy, mm: mm, dd: dd);
      case Hc20HistoryType.rri5s:
        return c.getAllDayRriRows(device, yy: yy, mm: mm, dd: dd);
      case Hc20HistoryType.temperature1m:
        return c.getAllDayTemperatureRows(device, yy: yy, mm: mm, dd: dd);
      case Hc20HistoryType.baro1m:
        return c.getAllDayBaroRows(device, yy: yy, mm: mm, dd: dd);
      case Hc20HistoryType.bp5m:
        return c.getAllDayBpRows(device, yy: yy, mm: mm, dd: dd);
      case Hc20HistoryType.hrv5m:
        return c.getAllDayHrvRows(device, yy: yy, mm: mm, dd: dd);
      case Hc20HistoryType.gnss1m:
        return c.getAllDayGnssRows(device, yy: yy, mm: mm, dd: dd);
      case Hc20HistoryType.sleep:
        return c.getAllDaySleepRows(
          device,
          yy: yy,
          mm: mm,
          dd: dd,
          includeSummary: includeSummary,
        );
      case Hc20HistoryType.calories5m:
        return c.getAllDayCaloriesRows(device, yy: yy, mm: mm, dd: dd);
      case Hc20HistoryType.hrv2_5m:
        return c.getAllDayHrv2Rows(device, yy: yy, mm: mm, dd: dd);
      case Hc20HistoryType.packetStatus:
      case Hc20HistoryType.storageInfo:
        return Future.value(const <Hc20AllDayRow>[]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
      ],
      home: DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('HC20 Demo'),
            bottom: const TabBar(tabs: [
              Tab(text: 'Device'),
              Tab(text: 'Realtime'),
              Tab(text: 'All Day'),
              Tab(text: 'Raw Data'),
            ]),
          ),
          body: client == null
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(children: [
                  _buildDeviceTab(),
                  _buildRealtimeTab(),
                  _buildAllDayTab(),
                  _buildRawDataTab(),
                ]),
        ),
      ),
    );
  }

  Widget _buildDeviceTab() {
    return Row(children: [
      Expanded(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: client == null || _isScanning ? null : _startScan,
                  child: Text(_isScanning ? 'Scanning…' : 'Scan 10s'),
                ),
              ),
              const SizedBox(width: 8),
              if (_isScanning)
                TextButton(onPressed: _stopScan, child: const Text('Stop')),
            ]),
          ),
          Expanded(
            child: _scanResults.isEmpty
                ? Center(child: Text(_isScanning ? 'Scanning…' : 'No devices'))
                : ListView.builder(
                    itemCount: _scanResults.length,
                    itemBuilder: (ctx, i) {
                      final d = _scanResults[i];
                      return Card(
                        child: ListTile(
                          title: Text(d.name.isEmpty ? 'Unknown' : d.name),
                          subtitle: Text(d.id),
                          trailing: const Icon(Icons.bluetooth_connected),
                          onTap: () async {
                            _stopScan();
                            setState(() {
                              _status = 'Connecting…';
                            });
                            try {
                              await client!.connect(d);
                              if (!mounted) return;
                              setState(() {
                                selected = d;
                                info = null;
                                _status = 'Connected';
                              });
                              // Automatically enable background sync when device is connected
                              await _enableBackgroundServiceOnConnection();
                            } catch (e) {
                              if (!mounted) return;
                              setState(() {
                                _status = 'Connect failed: $e';
                              });
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(12), children: [
          Card(
              child: ListTile(
                  title: const Text('Device Info'),
                  subtitle: Text(
                      'Name: ${info?.name ?? '-'}\nMAC: ${info?.mac ?? '-'}\nFW: ${info?.version ?? '-'}'))),
          // Connection State Card
          Card(
            child: ListTile(
              title: const Text('Connection State'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_currentConnectionState != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _currentConnectionState == Hc20ConnectionState.connected ||
                                  _currentConnectionState == Hc20ConnectionState.reconnected
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth_disabled,
                          color: _currentConnectionState == Hc20ConnectionState.connected ||
                                  _currentConnectionState == Hc20ConnectionState.reconnected
                              ? Colors.green
                              : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getConnectionStateText(_currentConnectionState!),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _currentConnectionState == Hc20ConnectionState.connected ||
                                    _currentConnectionState == Hc20ConnectionState.reconnected
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    if (_lastConnectionStateUpdate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Last update: ${_formatDateTime(_lastConnectionStateUpdate!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ] else
                    const Text(
                      'Not connected',
                      style: TextStyle(color: Colors.grey),
                    ),
                ],
              ),
            ),
          ),
          if (_status.isNotEmpty)
            Card(
                child: ListTile(
                    title: const Text('Status'), subtitle: Text(_status))),
          // Development mode toggle
          Card(
            color: _isDevelopmentMode ? Colors.orange.shade50 : Colors.grey.shade100,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isDevelopmentMode ? 'Development' : 'Production',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        _isDevelopmentMode ? Icons.developer_mode : Icons.verified_user,
                        color: _isDevelopmentMode ? Colors.orange : Colors.grey,
                      ),
                      Switch(
                        value: _isDevelopmentMode,
                        onChanged: (value) {
                          _toggleDevelopmentMode(value);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ElevatedButton(
              onPressed: selected == null
                  ? null
                  : () async {
                      try {
                        print('HC20 DEBUG: Calling readDeviceInfo...');
                        final di = await client!.readDeviceInfo(selected!);
                        print('HC20 DEBUG: Received device info: $di');
                        setState(() {
                          info = di;
                          _status = 'Device info read';
                        });
                      } catch (e) {
                        print('HC20 DEBUG: Error reading device info: $e');
                        setState(() {
                          _status = 'Error: $e';
                        });
                      }
                    },
              child: const Text('Read Device Info'),
            ),
            ElevatedButton(
              onPressed: selected == null
                  ? null
                  : () async {
                      await client!.setParameters(selected!, {
                        'user_info': {
                          'name': 'Test',
                          'gender': 1,
                          'height': 170,
                          'weight': 65
                        },
                        'health_monitor': {
                          'spo2_monitor': '5,1',
                          'bp_monitor': '5,1',
                          'hrv_monitor': '5,1'
                        }
                      });
                      setState(() {
                        _status = 'Parameters set';
                      });
                    },
              child: const Text('Set Params'),
            ),
            ElevatedButton(
              onPressed: selected == null
                  ? null
                  : () async {
                      final res = await client!
                          .getParameters(selected!, {'request': 'user_info'});
                      setState(() => lastParams = res.toString());
                    },
              child: const Text('Get Params'),
            ),
            ElevatedButton(
              onPressed: selected == null
                  ? null
                  : () async {
                      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                      await client!
                          .setTime(selected!, timestamp: ts, timezone: 8);
                      final t = await client!.getTime(selected!);
                      setState(() => deviceTime = t);
                    },
              child: const Text('Sync Time'),
            ),
            ElevatedButton(
              onPressed: selected == null
                  ? null
                  : () async {
                      await _disconnectDevice();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Disconnect'),
            ),
            ElevatedButton(
              onPressed: selected == null
                  ? null
                  : () async {
                      try {
                        await client!.factoryReset(selected!);
                        setState(() {
                          _status = 'Factory reset completed';
                        });
                      } catch (e) {
                        setState(() {
                          _status = 'Factory reset error: $e';
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Factory Reset'),
            ),
          ]),
          if (_appVersion != null && _appBuildNumber != null)
            Card(
                child: ListTile(
                    title: const Text('App Version & Build'),
                    subtitle: Text(
                        'Version: $_appVersion\nBuild: $_appBuildNumber'))),
          if (deviceTime != null)
            Card(
                child: ListTile(
                    title: const Text('Device Time'),
                    subtitle: Text(
                        'ts=${deviceTime!.timestamp} tz=${deviceTime!.timezone}'))),
          if (lastParams.isNotEmpty)
            Card(
                child: ListTile(
                    title: const Text('Parameters'),
                    subtitle: Text(lastParams))),
        ]),
      ),
    ]);
  }

  void _startScan() {
    setState(() {
      _isScanning = true;
      _scanResults.clear();
    });
    _scanSub = client!.scan().listen((d) {
      final exists = _scanResults.indexWhere((x) => x.id == d.id) >= 0;
      if (!exists) {
        setState(() {
          _scanResults.add(d);
        });
      }
    });
    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(seconds: 10), _stopScan);
  }

  void _stopScan() {
    _scanTimer?.cancel();
    _scanTimer = null;
    _scanSub?.cancel();
    _scanSub = null;
    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _disconnectDevice() async {
    final device = selected;
    if (device == null || client == null) return;

    try {
      setState(() {
        _status = 'Disconnecting...';
      });

      // Stop sensors if they're running
      if (_sensorsEnabled) {
        await _stopSensors();
      }

      // Stop realtime stream if it's running
      if (rtOn) {
        setState(() {
          rtStream = null;
          rtOn = false;
          lastRt = null;
        });
      }

      // Disconnect from the device (manual disconnect - forget device to prevent auto-reconnect)
      await client!.disconnect(device, forgetDevice: true);

      // Clear device-related state
      setState(() {
        selected = null;
        info = null;
        deviceTime = null;
        lastParams = '';
        _status = 'Disconnected';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Disconnect error: $e';
      });
    }
  }

  Widget _buildRealtimeTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: ElevatedButton(
            onPressed: selected == null
                ? null
                : () {
                    if (!rtOn) {
                      final s = client!.realtimeV2(selected!);
                      setState(() {
                        rtStream = s;
                        rtOn = true;
                      });
                    } else {
                      setState(() {
                        rtStream = null;
                        rtOn = false;
                        lastRt = null;
                      });
                    }
                  },
            child: Text(rtOn ? 'Stop' : 'Start'),
          )),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: rtStream == null
              ? const Center(child: Text('Realtime is off'))
              : StreamBuilder<Hc20RealtimeV2>(
                  stream: rtStream,
                  builder: (c, s) {
                    lastRt = s.data ?? lastRt;
                    final v = lastRt;
                    if (v == null)
                      return const Center(child: Text('Waiting data...'));
                    return ListView(children: [
                      Card(
                          child: ListTile(
                              title: const Text('Heart & Wear'),
                              subtitle: Text(
                                  'Heart: ${v.heart ?? '-'} bpm\nRRI: ${v.rri ?? '-'} ms\nWear: ${v.wear == 1 ? 'Worn' : 'Off'}'))),
                      if (v.hrvMetrics != null)
                        Card(
                            child: ListTile(
                                title: const Text(
                                    'HRV (x1000 already normalized in history, raw here)'),
                                subtitle: Text(
                                    'SDNN: ${v.hrvMetrics!.sdnn}\nTP: ${v.hrvMetrics!.tp}\nLF: ${v.hrvMetrics!.lf}\nHF: ${v.hrvMetrics!.hf}\nVLF: ${v.hrvMetrics!.vlf}'))),
                      if (v.hrv2Metrics != null)
                        Card(
                            child: ListTile(
                                title: const Text('HRV2'),
                                subtitle: Text(
                                    'Mental stress: ${v.hrv2Metrics!.mentStress}\nFatigue: ${v.hrv2Metrics!.fatigueLevel}\nStress resistance: ${v.hrv2Metrics!.stressResistance}\nRegulation ability: ${v.hrv2Metrics!.regulationAbility}'))),
                    ]);
                  },
                ),
        ),
      ]),
    );
  }

  Widget _buildAllDayTab() {
    return Builder(builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(children: [
          Row(children: [
            Expanded(child: Text('Selected date: ${_formatDate(_histDate)}')),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: _histDate,
                  firstDate: DateTime(1950, 1, 1),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    _histDate = picked;
                  });
                }
              },
              child: const Text('Pick Date'),
            ),
          ]),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: selected == null ? null : _fetchDailySummary,
            child: const Text('Fetch Summary + HRV2 Sample'),
          ),
          if (allDaySummary.isNotEmpty)
            Card(
                child: ListTile(
                    title: const Text('Today Overview'),
                    subtitle: Text(allDaySummary))),
          const SizedBox(height: 12),
          Text('All-day (aggregated for date)',
              style: Theme.of(ctx).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const <_MetricButtonConfig>[
              _MetricButtonConfig('Steps (5m)', Hc20HistoryType.steps5m),
              _MetricButtonConfig('Heart (5s)', Hc20HistoryType.heart5s),
              _MetricButtonConfig('SpO2 (5m)', Hc20HistoryType.spo25m),
              _MetricButtonConfig('RRI (5s)', Hc20HistoryType.rri5s),
              _MetricButtonConfig('Temp (1m)', Hc20HistoryType.temperature1m),
              _MetricButtonConfig('Baro (1m)', Hc20HistoryType.baro1m),
              _MetricButtonConfig('Blood Pressure (5m)', Hc20HistoryType.bp5m),
              _MetricButtonConfig('HRV (5m)', Hc20HistoryType.hrv5m),
              _MetricButtonConfig('GNSS (1m)', Hc20HistoryType.gnss1m),
              _MetricButtonConfig(
                  'Sleep (timeline + summary)', Hc20HistoryType.sleep,
                  includeSummary: true),
              _MetricButtonConfig('Calories (5m)', Hc20HistoryType.calories5m),
              _MetricButtonConfig('HRV2 (5m)', Hc20HistoryType.hrv2_5m),
            ]
                .map((meta) => ElevatedButton(
                      onPressed: selected == null
                          ? null
                          : () => _loadAllDayRows(
                                meta.type,
                                meta.label,
                                includeSummary: meta.includeSummary,
                              ),
                      child: Text(meta.label),
                    ))
                .toList(),
          ),
          if (allDayAll.isNotEmpty)
            Card(
                child: ListTile(
                    title: const Text('All-day Result'),
                    subtitle: Text(allDayAll))),
          if (allDayLines.isNotEmpty)
            Card(
                child: Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                height: 260,
                child: ListView.builder(
                  itemCount: allDayLines.length,
                  itemBuilder: (c, i) => Text(allDayLines[i],
                      style: const TextStyle(fontFamily: 'monospace')),
                ),
              ),
            )),
        ]),
      );
    });
  }

  Widget _buildRawDataTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: selected == null || client == null
                      ? null
                      : _sensorsEnabled
                          ? _stopSensors
                          : _startSensors,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _sensorsEnabled ? Colors.red : Colors.green,
                  ),
                  child: Text(_sensorsEnabled ? 'Stop Sensors' : 'Start Sensors'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _clearConsole,
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Get Sensor Configuration and State buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: selected == null || client == null
                      ? null
                      : _getSensorConfig,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Get Sensor Config'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: selected == null || client == null
                      ? null
                      : _getSensorState,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Get Sensor State'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Background Service toggle
          Card(
            color: _backgroundServiceEnabled ? Colors.green.shade50 : Colors.grey.shade100,
            child: SwitchListTile(
              title: const Text('Background Service'),
              subtitle: Text(
                _backgroundServiceEnabled
                    ? 'Service is running - sensors will continue streaming in background'
                        + (Platform.isIOS ? '\nNote: iOS has limited background execution time (~30s)' : '')
                    : 'Service is stopped - sensors will stop when app goes to background',
              ),
              value: _backgroundServiceEnabled,
              onChanged: selected == null || client == null
                  ? null
                  : (value) {
                      if (value) {
                        _enableBackgroundService();
                      } else {
                        _disableBackgroundService();
                      }
                    },
              secondary: Icon(
                _backgroundServiceEnabled ? Icons.cloud_upload : Icons.cloud_off,
                color: _backgroundServiceEnabled ? Colors.green : Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _recordedData.isEmpty ? null : _exportToCsv,
                  icon: const Icon(Icons.file_download),
                  label: Text('Export CSV (${_recordedData.length} records)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _recordedData.isEmpty ? null : _clearRecordedData,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Clear Recorded Data',
                color: Colors.red,
              ),
            ],
          ),
          if (_isRecording)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Recording... (${_recordedData.length} samples)',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Raw Sensor Data Console',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade700),
              ),
              child: _consoleLogs.isEmpty
                  ? Center(
                      child: Text(
                        'No data yet. Press "Start Sensors" to begin.',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    )
                  : ListView.builder(
                      controller: _consoleScrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: _consoleLogs.length,
                      itemBuilder: (context, index) {
                        final entry = _consoleLogs[index];
                        final timeStr =
                            '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
                            '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
                            '${entry.timestamp.second.toString().padLeft(2, '0')}.'
                            '${(entry.timestamp.millisecond ~/ 100).toString()}';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: Colors.white,
                              ),
                              children: [
                                TextSpan(
                                  text: '[$timeStr] ',
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                                TextSpan(
                                  text: entry.message,
                                  style: TextStyle(color: entry.color),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startSensors() async {
    final c = client;
    final device = selected;
    if (c == null || device == null) return;

    try {
      _addLog('Enabling sensors...', _LogType.system);
      await c.setSensorState(device);
      _addLog('Sensors enabled successfully', _LogType.system);

      // Subscribe to IMU data
      _imuSub = c.streamImu(device).listen((data) {
        if (!mounted) return;
        final accel = data.accelerometer;
        final gyro = data.gyroscope;
        final mag = data.magnetometer;
        final parts = <String>[];
        if (accel != null) {
          parts.add('Accel: x=${accel.x}, y=${accel.y}, z=${accel.z}');
        }
        if (gyro != null) {
          parts.add('Gyro: x=${gyro.x}, y=${gyro.y}, z=${gyro.z}');
        }
        if (mag != null) {
          parts.add('Mag: x=${mag.x}, y=${mag.y}, z=${mag.z}');
        }
        _addLog('IMU [Pkt:${data.packetId}] ${parts.join(' | ')}', _LogType.imu);
        
        // Record data for CSV export
        if (_isRecording) {
          _recordData(_SensorDataRecord(
            timestamp: DateTime.now(),
            sensorType: 'IMU',
            packetId: data.packetId,
            timestampMs: data.timestampMs,
            accelX: accel?.x,
            accelY: accel?.y,
            accelZ: accel?.z,
            gyroX: gyro?.x,
            gyroY: gyro?.y,
            gyroZ: gyro?.z,
            magX: mag?.x,
            magY: mag?.y,
            magZ: mag?.z,
          ));
        }
      }, onError: (e) {
        if (!mounted) return;
        _addLog('IMU Error: $e', _LogType.system);
      });

      // Subscribe to PPG data
      _ppgSub = c.streamPpg(device).listen((data) {
        if (!mounted) return;
        final parts = <String>[];
        if (data.green != null) parts.add('Green: ${data.green}');
        if (data.red != null) parts.add('Red: ${data.red}');
        if (data.ir != null) parts.add('IR: ${data.ir}');
        _addLog('PPG [Pkt:${data.packetId}] ${parts.join(' | ')}', _LogType.ppg);
        
        // Record data for CSV export
        if (_isRecording) {
          _recordData(_SensorDataRecord(
            timestamp: DateTime.now(),
            sensorType: 'PPG',
            packetId: data.packetId,
            timestampMs: data.timestampMs,
            ppgGreen: data.green,
            ppgRed: data.red,
            ppgIr: data.ir,
          ));
        }
      }, onError: (e) {
        if (!mounted) return;
        _addLog('PPG Error: $e', _LogType.system);
      });

      // Subscribe to GSR data
      _gsrSub = c.streamGsr(device).listen((data) {
        if (!mounted) return;
        _addLog(
            'GSR [Pkt:${data.packetId}] I: ${data.i}, Q: ${data.q}, Raw: ${data.raw}',
            _LogType.gsr);
        
        // Record data for CSV export
        if (_isRecording) {
          _recordData(_SensorDataRecord(
            timestamp: DateTime.now(),
            sensorType: 'GSR',
            packetId: data.packetId,
            timestampMs: data.timestampMs,
            gsrI: data.i,
            gsrQ: data.q,
            gsrRaw: data.raw,
          ));
        }
      }, onError: (e) {
        if (!mounted) return;
        _addLog('GSR Error: $e', _LogType.system);
      });

      setState(() {
        _sensorsEnabled = true;
        _isRecording = true;
      });
      _addLog('All sensor streams started', _LogType.system);
      _addLog('Recording started - data will be saved for CSV export', _LogType.system);
      
      // Background service is automatically enabled when device is connected
      // If it's not already enabled, enable it now when sensors start
      if (!_backgroundServiceEnabled) {
        await _enableBackgroundServiceOnConnection();
      }
    } catch (e) {
      if (!mounted) return;
      _addLog('Error starting sensors: $e', _LogType.system);
      setState(() {
        _sensorsEnabled = false;
      });
    }
  }

  Future<void> _stopSensors() async {
    // Cancel stream subscriptions first
    await _imuSub?.cancel();
    await _ppgSub?.cancel();
    await _gsrSub?.cancel();
    _imuSub = null;
    _ppgSub = null;
    _gsrSub = null;

    // Disable sensors on the device
    final c = client;
    final device = selected;
    if (c != null && device != null) {
      try {
        await c.disableSensorState(device);
        _addLog('Sensors disabled on device', _LogType.system);
      } catch (e) {
        _addLog('Error disabling sensors: $e', _LogType.system);
      }
    }

    setState(() {
      _sensorsEnabled = false;
      _isRecording = false;
    });
    
    // Stop background service if it's running
    if (_backgroundServiceEnabled) {
      await BackgroundServiceManager.instance.stop();
      setState(() {
        _backgroundServiceEnabled = false;
      });
      _addLog('Background service stopped', _LogType.system);
    }
    
    _addLog('Sensors stopped', _LogType.system);
    if (_recordedData.isNotEmpty) {
      _addLog('Recorded ${_recordedData.length} data samples. Ready for export.', _LogType.system);
    }
  }
  
  /// Enable background service automatically when device is connected
  /// This doesn't require sensors to be enabled yet - it will be ready for when sensors start
  Future<void> _enableBackgroundServiceOnConnection() async {
    if (selected == null || client == null) {
      return;
    }
    
    // Don't enable if already enabled
    if (_backgroundServiceEnabled) {
      // Even if already enabled, ensure battery optimization is disabled
      // This is important when device reconnects
      try {
        await BackgroundServiceManager.instance.ensureBatteryOptimizationDisabled();
      } catch (e) {
        print('[BackgroundService] Error checking battery optimization: $e');
      }
      return;
    }
    
    // Request battery optimization exemption FIRST, before starting service
    // This is critical to prevent Android from killing the app after 15 minutes
    // Do this early so the user can grant permission before the service starts
    try {
      await BackgroundServiceManager.instance.ensureBatteryOptimizationDisabled();
    } catch (e) {
      print('[BackgroundService] Error requesting battery optimization: $e (will continue anyway)');
    }
    
    // Update UI immediately to show toggle is on
    // If service fails to start, we'll update it back
    setState(() {
      _backgroundServiceEnabled = true;
    });
    
    // Start the service asynchronously with delays to avoid crashes
    // The crash happens in native code when starting foreground service too quickly
    Future.delayed(const Duration(milliseconds: 500), () async {
      // Wait for UI to fully settle
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Start in post-frame callback to ensure everything is ready
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await BackgroundServiceManager.instance.start();
          
          // Only log success if we got here without crashing
          // The start() method handles errors internally
          if (mounted) {
            print('[BackgroundService] Enabled automatically on device connection');
          }
        } catch (e) {
          // This catch is a safety net - start() shouldn't throw, but just in case
          if (mounted) {
            print('[BackgroundService] Error enabling on connection: $e (app will continue)');
            setState(() {
              _backgroundServiceEnabled = false;
            });
          }
        }
      });
    });
  }
  
  Future<void> _enableBackgroundService() async {
    if (selected == null || client == null) {
      _addLog('Cannot enable background service: device not connected', _LogType.system);
      return;
    }
    
    // Update UI immediately to show toggle is on
    // If service fails to start, we'll update it back
    setState(() {
      _backgroundServiceEnabled = true;
    });
    _addLog('Starting background service...', _LogType.system);
    
    // Start the service asynchronously with delays to avoid crashes
    // The crash happens in native code when starting foreground service too quickly
    Future.delayed(const Duration(milliseconds: 500), () async {
      // Wait for UI to fully settle
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Start in post-frame callback to ensure everything is ready
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await BackgroundServiceManager.instance.start();
          
          // Only log success if we got here without crashing
          // The start() method handles errors internally
          if (mounted) {
            _addLog('Background service enabled - sensors will continue streaming in background', _LogType.system);
          }
        } catch (e) {
          // This catch is a safety net - start() shouldn't throw, but just in case
          if (mounted) {
            _addLog('Error enabling background service: $e (app will continue)', _LogType.system);
            setState(() {
              _backgroundServiceEnabled = false;
            });
          }
        }
      });
    });
  }
  
  Future<void> _disableBackgroundService() async {
    try {
      await BackgroundServiceManager.instance.stop();
      setState(() {
        _backgroundServiceEnabled = false;
      });
      _addLog('Background service disabled', _LogType.system);
    } catch (e) {
      _addLog('Error disabling background service: $e', _LogType.system);
    }
  }

  Future<void> _getSensorConfig() async {
    final c = client;
    final device = selected;
    if (c == null || device == null) return;

    try {
      _addLog('Getting sensor configuration...', _LogType.system);
      
      final config = await c.getSensorConfig(device);
      
      _addLog('Sensor Configuration:', _LogType.system);
      
      if (config.imu != null) {
        final imu = config.imu!;
        _addLog('  IMU:', _LogType.system);
        _addLog('    Rate: ${imu.rate} Hz', _LogType.system);
        _addLog('    Depth: ${imu.depth} bits', _LogType.system);
        _addLog('    Accelerometer: ${imu.acceSupported ? "Supported" : "Not supported"} (Range: ${imu.acceRange} G)', _LogType.system);
        _addLog('    Gyroscope: ${imu.gyroSupported ? "Supported" : "Not supported"} (Range: ${imu.gyroRange} DPS)', _LogType.system);
        _addLog('    Magnetometer: ${imu.magSupported ? "Supported" : "Not supported"}', _LogType.system);
      }
      
      if (config.ppg != null) {
        final ppg = config.ppg!;
        _addLog('  PPG:', _LogType.system);
        _addLog('    Rate: ${ppg.rate} Hz', _LogType.system);
        _addLog('    Depth: ${ppg.depth} bits', _LogType.system);
        _addLog('    Green LED: ${ppg.greenSupported ? "Supported" : "Not supported"}', _LogType.system);
        _addLog('    Red LED: ${ppg.redSupported ? "Supported" : "Not supported"}', _LogType.system);
        _addLog('    IR LED: ${ppg.irSupported ? "Supported" : "Not supported"}', _LogType.system);
      }
      
      if (config.gsr != null) {
        final gsr = config.gsr!;
        _addLog('  GSR:', _LogType.system);
        _addLog('    Rate: ${gsr.rate} Hz', _LogType.system);
        _addLog('    Depth: ${gsr.depth} bits', _LogType.system);
      }
      
      if (config.ecg != null) {
        final ecg = config.ecg!;
        _addLog('  ECG:', _LogType.system);
        _addLog('    Rate: ${ecg.rate} Hz', _LogType.system);
        _addLog('    Depth: ${ecg.depth} bits', _LogType.system);
      }
      
      _addLog('Sensor configuration retrieved successfully', _LogType.system);
    } catch (e) {
      _addLog('Error getting sensor configuration: $e', _LogType.system);
    }
  }

  Future<void> _getSensorState() async {
    final c = client;
    final device = selected;
    if (c == null || device == null) return;

    try {
      _addLog('Getting sensor state...', _LogType.system);
      
      final state = await c.readSensorState(device);
      
      _addLog('Sensor State:', _LogType.system);
      
      if (state.imu != null) {
        final imu = state.imu!;
        _addLog('  IMU:', _LogType.system);
        _addLog('    Accelerometer: ${imu.accelerometerEnabled ? "Enabled" : "Disabled"}', _LogType.system);
        _addLog('    Gyroscope: ${imu.gyroscopeEnabled ? "Enabled" : "Disabled"}', _LogType.system);
        _addLog('    Magnetometer: ${imu.magnetometerEnabled ? "Enabled" : "Disabled"}', _LogType.system);
      }
      
      if (state.ppg != null) {
        final ppg = state.ppg!;
        _addLog('  PPG:', _LogType.system);
        _addLog('    Green LED: ${ppg.greenEnabled ? "Enabled" : "Disabled"}', _LogType.system);
        _addLog('    Red LED: ${ppg.redEnabled ? "Enabled" : "Disabled"}', _LogType.system);
        _addLog('    IR LED: ${ppg.irEnabled ? "Enabled" : "Disabled"}', _LogType.system);
      }
      
      if (state.gsr != null) {
        final gsr = state.gsr!;
        _addLog('  GSR:', _LogType.system);
        _addLog('    GSR: ${gsr.enabled ? "Enabled" : "Disabled"}', _LogType.system);
      }
      
      if (state.ecg != null) {
        final ecg = state.ecg!;
        _addLog('  ECG:', _LogType.system);
        _addLog('    ECG: ${ecg.enabled ? "Enabled" : "Disabled"}', _LogType.system);
      }
      
      _addLog('Sensor state retrieved successfully', _LogType.system);
    } catch (e) {
      _addLog('Error getting sensor state: $e', _LogType.system);
    }
  }

  void _addLog(String message, _LogType type) {
    if (!mounted) return;
    setState(() {
      _consoleLogs.add(_ConsoleLogEntry(message, type));
      // Keep only last 500 entries to prevent memory issues
      if (_consoleLogs.length > 500) {
        _consoleLogs.removeAt(0);
      }
    });
    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_consoleScrollController.hasClients) {
        _consoleScrollController.animateTo(
          _consoleScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearConsole() {
    setState(() {
      _consoleLogs.clear();
    });
  }

  void _recordData(_SensorDataRecord record) {
    if (!mounted) return;
    setState(() {
      _recordedData.add(record);
      // Keep a reasonable limit to prevent memory issues (e.g., 100k records)
      if (_recordedData.length > 100000) {
        _recordedData.removeAt(0);
      }
    });
  }

  void _clearRecordedData() {
    setState(() {
      _recordedData.clear();
    });
    _addLog('Recorded data cleared', _LogType.system);
  }

  Future<void> _exportToCsv() async {
    if (_recordedData.isEmpty) {
      _addLog('No data to export', _LogType.system);
      return;
    }

    try {
      _addLog('Generating CSV file...', _LogType.system);
      
      // Generate CSV content
      final csv = StringBuffer();
      
      // Write headers
      csv.writeln(_SensorDataRecord.csvHeaders().join(','));
      
      // Write data rows
      for (final record in _recordedData) {
        csv.writeln(record.toCsvRow().join(','));
      }
      
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = 'hc20_sensor_data_$timestamp.csv';
      final file = File('${tempDir.path}/$fileName');
      
      // Write file
      await file.writeAsString(csv.toString());
      
      _addLog('CSV file created: $fileName', _LogType.system);
      _addLog('Total records: ${_recordedData.length}', _LogType.system);
      
      // Share the file
      final xFile = XFile(file.path);
      await Share.shareXFiles(
        [xFile],
        text: 'HC20 Sensor Data Export',
        subject: 'HC20 Raw Sensor Data',
      );
      
      _addLog('File shared successfully', _LogType.system);
    } catch (e) {
      _addLog('Error exporting CSV: $e', _LogType.system);
    }
  }

}
