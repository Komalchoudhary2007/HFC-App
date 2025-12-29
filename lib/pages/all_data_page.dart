import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hc20/hc20.dart';

class AllDataPage extends StatefulWidget {
  final Hc20Client client;
  final Hc20Device device;

  const AllDataPage({
    super.key,
    required this.client,
    required this.device,
  });

  @override
  State<AllDataPage> createState() => _AllDataPageState();
}

class _AllDataPageState extends State<AllDataPage> {
  // Real-time data
  Hc20RealtimeV2? _realtimeData;
  
  // Timer for periodic data refresh
  Timer? _dataRefreshTimer;
  Timer? _hrvRefreshTimer; // Timer for 6-hour HRV data refresh
  
  // Historical data
  List<Hc20AllDayRow>? _summaryData;
  List<Hc20AllDayRow>? _heartData;
  List<Hc20AllDayRow>? _stepsData;
  List<Hc20AllDayRow>? _spo2Data;
  List<Hc20AllDayRow>? _rriData;
  List<Hc20AllDayRow>? _temperatureData;
  List<Hc20AllDayRow>? _baroData;
  List<Hc20AllDayRow>? _bpData;
  List<Hc20AllDayRow>? _hrvData;
  List<Hc20AllDayRow>? _sleepData;
  List<Hc20AllDayRow>? _caloriesData;
  List<Hc20AllDayRow>? _hrv2Data;
  
  // Error messages for each data type
  Map<String, String?> _dataErrors = {};
  
  bool _isLoadingHistory = false;
  bool _hasAttemptedLoad = false; // Track if we've attempted to load data at least once
  String _statusMessage = 'Streaming real-time data...';

  @override
  void initState() {
    super.initState();
    _startRealtimeStream();
    _startHrvAutoRefresh();
  }

  void _startRealtimeStream() {
    // Cancel any existing timer
    _dataRefreshTimer?.cancel();
    
    print('📊 [AllDataPage] Starting real-time stream with 60-second (1 minute) refresh');
    
    // Initial data request
    widget.client.realtimeV2(widget.device).listen(
      (data) {
        if (mounted) {
          setState(() {
            _realtimeData = data;
          });
          print('✓ [AllDataPage] Received real-time data update');
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _statusMessage = 'Error: $error';
          });
          print('❌ [AllDataPage] Stream error: $error');
        }
      },
    );
    
    // Set up periodic timer to refresh data every 60 seconds (1 minute)
    _dataRefreshTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) {
        print('⏰ [AllDataPage] Timer trigger - requesting fresh data...');
        // Trigger new data request (the stream above will receive it)
        widget.client.realtimeV2(widget.device).listen(
          (data) {
            if (mounted) {
              setState(() {
                _realtimeData = data;
              });
            }
          },
          onError: (_) {},
        );
      } else {
        print('⚠️ [AllDataPage] Widget unmounted, stopping timer');
        timer.cancel();
      }
    });
    
    print('✓ [AllDataPage] Timer started - will refresh every 60 seconds (1 minute)');
  }

  void _startHrvAutoRefresh() {
    print('📊 [AllDataPage] Starting HRV auto-refresh - every 6 hours');
    
    // Set up periodic timer to refresh HRV data every 6 hours (21600 seconds)
    _hrvRefreshTimer = Timer.periodic(const Duration(hours: 6), (timer) async {
      if (mounted) {
        print('⏰ [AllDataPage] 6-hour timer trigger - loading HRV data...');
        await _loadHrvData();
      } else {
        print('⚠️ [AllDataPage] Widget unmounted, stopping HRV timer');
        timer.cancel();
      }
    });
    
    print('✓ [AllDataPage] HRV auto-refresh started - will load every 6 hours');
  }

  Future<void> _loadHrvData() async {
    try {
      final now = DateTime.now();
      final yy = now.year % 100;
      final mm = now.month;
      final dd = now.day;
      final dateStr = '${now.year}-${mm.toString().padLeft(2, '0')}-${dd.toString().padLeft(2, '0')}';

      print('📊 [AllDataPage] Loading HRV data for $dateStr...');
      
      try {
        _hrvData = await widget.client.getAllDayHrvRows(widget.device, yy: yy, mm: mm, dd: dd);
        print('✓ HRV data loaded: ${_hrvData?.length ?? 0} records');
      } catch (e) {
        print('❌ Error loading HRV data: $e');
        _hrvData = [];
      }

      if (mounted) {
        setState(() {
          // Update UI with new HRV data
        });
      }
      
      print('✓ [AllDataPage] HRV data loaded successfully');
    } catch (e) {
      print('❌ [AllDataPage] Error loading HRV data: $e');
    }
  }

  @override
  void dispose() {
    _dataRefreshTimer?.cancel();
    _hrvRefreshTimer?.cancel();
    super.dispose();
  }

  // Helper function to handle errors and convert 0xE2 to specific message
  String? _handleError(dynamic error, String dateStr) {
    if (error is Exception) {
      final errorStr = error.toString();
      // Check for error code 0xE2 (request date does not exist)
      if (errorStr.contains('0xE2') || errorStr.contains('0xe2') || 
          errorStr.contains('code=226') || errorStr.contains('code=0xe2') ||
          errorStr.contains('request date does not exist')) {
        return 'No record found for $dateStr';
      }
      // Check for other common error patterns
      if (errorStr.contains('does not exist') || errorStr.contains('not found')) {
        return 'No record found for $dateStr';
      }
      return errorStr;
    }
    final errorStr = error.toString();
    if (errorStr.contains('0xE2') || errorStr.contains('0xe2') || 
        errorStr.contains('request date does not exist')) {
      return 'No record found for $dateStr';
    }
    return error.toString();
  }

  // Helper function to fetch one data type with all checks batched together
  // ✅ CRITICAL: Batches storage info + packet statuses + data retrieval together
  // This ensures sensors are disabled once and re-enabled once per data type
  // 
  // How the mutex system works:
  // 1. All three operations (readStorageInfo, readPacketStatuses, getDataFn) call _acquireHistoryMutex()
  // 2. When Future.wait() starts all three futures, they queue in the mutex system:
  //    - First operation acquires mutex → sensors disabled (mutex depth 0→1)
  //    - Second operation queues (mutex held)
  //    - Third operation queues (mutex held)
  // 3. Operations execute sequentially through the mutex queue
  // 4. When all three complete and queue is empty → sensors re-enabled
  // Result: Sensors toggle once per data type (1 disable + 1 enable)
  Future<List<Hc20AllDayRow>?> _fetchDataTypeWithAllChecks(
    String dataTypeName,
    int dataType,
    int yy,
    int mm,
    int dd,
    String dateStr,
    Future<List<Hc20AllDayRow>> Function() getDataFn,
  ) async {
    dynamic caughtError;
    
    try {
      // ✅ CRITICAL: Batch storage info + packet statuses + data retrieval together
      // All three operations will queue in the plugin's mutex system
      // Sensors will be disabled once and re-enabled once when all operations complete
      // Each operation (readStorageInfo, readPacketStatuses, getAllDayXRows) internally
      // calls _acquireHistoryMutex() and _releaseHistoryMutex() - the mutex system
      // handles sensor disable/enable automatically
      // ✅ ERROR HANDLING: Catch all errors and don't re-throw - handle them after Future.wait
      final batchResults = await Future.wait([
        widget.client.readStorageInfo(widget.device).catchError((e, stackTrace) {
          print('⚠️ [ERROR] DataType: $dataTypeName | Operation: readStorageInfo | Error: $e');
          if (caughtError == null) caughtError = e; // Store error for later handling
          return ''; // Return empty string on error
        }),  // Storage info check (acquires mutex)
        widget.client.readPacketStatuses(
          widget.device,
          dataType: dataType,
          yy: yy,
          mm: mm,
          dd: dd,
        ).catchError((e, stackTrace) {
          print('⚠️ [ERROR] DataType: $dataTypeName | Operation: readPacketStatuses | Error: $e');
          if (caughtError == null) caughtError = e; // Store error if not already set
          return <int>[]; // Return empty list on error
        }),  // Packet statuses check (acquires mutex)
        getDataFn().catchError((e, stackTrace) {
          print('⚠️ [ERROR] DataType: $dataTypeName | Operation: getDataFn | Error: $e');
          if (caughtError == null) caughtError = e; // Store error for later handling
          return <Hc20AllDayRow>[]; // Return empty list on error - don't re-throw
        }),  // Data retrieval (acquires mutex via getAllDayRows)
      ], eagerError: false);

      // Check if we caught any errors during the batch operations
      if (caughtError != null) {
        print('❌ [FINAL ERROR] DataType: $dataTypeName | Error: $caughtError');
        _dataErrors[dataTypeName] = _handleError(caughtError, dateStr);
        return null;
      }

      final statuses = batchResults[1] as List<int>;
      final data = batchResults[2] as List<Hc20AllDayRow>;

      // Check if data exists
      final hasData = statuses.any((s) => s != 0) && data.isNotEmpty;

      if (!hasData) {
        // No samples for this data type
        _dataErrors[dataTypeName] = 'No record found for $dateStr';
        return [];
      }

      // Empty result handling
      if (data.isEmpty) {
        _dataErrors[dataTypeName] = 'No record found for $dateStr';
        return data;
      }

      // Clear any previous errors
      _dataErrors[dataTypeName] = null;
      print('✓ $dataTypeName: ${data.length} rows');
      return data;
    } catch (e, stackTrace) {
      // Error handling - catch any exceptions that escape the catchError handlers
      print('❌ [UNHANDLED ERROR] DataType: $dataTypeName | Error: $e');
      print('❌ [UNHANDLED ERROR] DataType: $dataTypeName | Stack trace: $stackTrace');
      _dataErrors[dataTypeName] = _handleError(e, dateStr);
      return null;
    }
  }

  // Helper function to fetch sleep data (no packet status check, but still batch storage info + retrieval)
  // Sleep data doesn't use packet statuses, but we still batch operations to minimize sensor toggling
  // Both operations (readStorageInfo and getAllDaySleepRows) go through the mutex system
  Future<List<Hc20AllDayRow>?> _fetchSleepDataWithChecks(
    int yy,
    int mm,
    int dd,
    String dateStr,
    Future<List<Hc20AllDayRow>> Function() getDataFn,
  ) async {
    dynamic caughtError;
    
    try {
      // ✅ CRITICAL: Batch storage info + data retrieval together
      // Sleep data doesn't need packet status check, but still batch operations
      // Both operations acquire mutex internally - sensors toggle once for both operations
      // ✅ ERROR HANDLING: Catch all errors and don't re-throw - handle them after Future.wait
      final batchResults = await Future.wait([
        widget.client.readStorageInfo(widget.device).catchError((e, stackTrace) {
          print('⚠️ [ERROR] DataType: Sleep | Operation: readStorageInfo | Error: $e');
          if (caughtError == null) caughtError = e; // Store error for later handling
          return ''; // Return empty string on error
        }),  // Acquires mutex
        getDataFn().catchError((e, stackTrace) {
          print('⚠️ [ERROR] DataType: Sleep | Operation: getDataFn | Error: $e');
          if (caughtError == null) caughtError = e; // Store error for later handling
          return <Hc20AllDayRow>[]; // Return empty list on error - don't re-throw
        }),  // Acquires mutex via getAllDayRows
      ], eagerError: false);

      // Check if we caught any errors during the batch operations
      if (caughtError != null) {
        print('❌ [FINAL ERROR] DataType: Sleep | Error: $caughtError');
        _dataErrors['Sleep'] = _handleError(caughtError, dateStr);
        return null;
      }

      final data = batchResults[1] as List<Hc20AllDayRow>;

      // Check if data exists
      if (data.isEmpty) {
        _dataErrors['Sleep'] = 'No record found for $dateStr';
        return [];
      }

      // Clear any previous errors
      _dataErrors['Sleep'] = null;
      print('✓ Sleep: ${data.length} rows');
      return data;
    } catch (e, stackTrace) {
      // Error handling - catch any exceptions that escape the catchError handlers
      print('❌ [UNHANDLED ERROR] DataType: Sleep | Error: $e');
      print('❌ [UNHANDLED ERROR] DataType: Sleep | Stack trace: $stackTrace');
      _dataErrors['Sleep'] = _handleError(e, dateStr);
      return null;
    }
  }

  Future<void> _loadHistoricalData() async {
    setState(() {
      _isLoadingHistory = true;
      _statusMessage = 'Loading historical data...';
      _dataErrors.clear();
    });

    try {
      final now = DateTime.now();
      final yy = now.year % 100;
      final mm = now.month;
      final dd = now.day;
      final dateStr = '${now.year}-${mm.toString().padLeft(2, '0')}-${dd.toString().padLeft(2, '0')}';

      print('🚀 Starting historical data retrieval for date: $dateStr (yy=$yy, mm=$mm, dd=$dd)');
      
      // Process each data type sequentially in the requested order:
      // 1. HRV, 2. HRV2, 3. Temperature, 4. RRI, then the rest
      
      // HRV data (Priority 1)
      print('📊 [1/11] Processing HRV data...');
      try {
        _hrvData = await _fetchDataTypeWithAllChecks(
          'HRV',
          0x08,
          yy, mm, dd, dateStr,
          () => widget.client.getAllDayHrvRows(widget.device, yy: yy, mm: mm, dd: dd),
        );
      } catch (e, stackTrace) {
        print('❌ [FATAL ERROR] HRV data failed: $e');
        print('Stack trace: $stackTrace');
        _dataErrors['HRV'] = _handleError(e, dateStr);
        _hrvData = null;
      }
      
      // HRV2 data (Priority 2)
      print('📊 [2/11] Processing HRV2 data...');
      try {
        _hrv2Data = await _fetchDataTypeWithAllChecks(
          'HRV2',
          0x0C,
          yy, mm, dd, dateStr,
          () => widget.client.getAllDayHrv2Rows(widget.device, yy: yy, mm: mm, dd: dd),
        );
      } catch (e, stackTrace) {
        print('❌ [FATAL ERROR] HRV2 data failed: $e');
        print('Stack trace: $stackTrace');
        _dataErrors['HRV2'] = _handleError(e, dateStr);
        _hrv2Data = null;
      }
      
      // Temperature data (Priority 3)
      print('📊 [3/11] Processing Temperature data...');
      try {
        _temperatureData = await _fetchDataTypeWithAllChecks(
          'Temperature',
          0x05,
          yy, mm, dd, dateStr,
          () => widget.client.getAllDayTemperatureRows(widget.device, yy: yy, mm: mm, dd: dd),
        );
      } catch (e, stackTrace) {
        print('❌ [FATAL ERROR] Temperature data failed: $e');
        print('Stack trace: $stackTrace');
        _dataErrors['Temperature'] = _handleError(e, dateStr);
        _temperatureData = null;
      }
      
      // RRI data (Priority 4)
      print('📊 [4/11] Processing RRI data...');
      try {
        _rriData = await _fetchDataTypeWithAllChecks(
          'RRI',
          0x04,
          yy, mm, dd, dateStr,
          () => widget.client.getAllDayRriRows(widget.device, yy: yy, mm: mm, dd: dd),
        );
      } catch (e, stackTrace) {
        print('❌ [FATAL ERROR] RRI data failed: $e');
        print('Stack trace: $stackTrace');
        _dataErrors['RRI'] = _handleError(e, dateStr);
        _rriData = null;
      }
      
      // Heart data
      print('📊 [5/11] Processing Heart data...');
      try {
        _heartData = await _fetchDataTypeWithAllChecks(
          'Heart',
          0x01,
          yy, mm, dd, dateStr,
          () => widget.client.getAllDayHeartRows(widget.device, yy: yy, mm: mm, dd: dd),
        );
      } catch (e, stackTrace) {
        print('❌ [FATAL ERROR] Heart data failed: $e');
        print('Stack trace: $stackTrace');
        _dataErrors['Heart'] = _handleError(e, dateStr);
        _heartData = null;
      }
      
      // Steps data
      print('📊 [6/11] Processing Steps data...');
      try {
        _stepsData = await _fetchDataTypeWithAllChecks(
          'Steps',
          0x02,
          yy, mm, dd, dateStr,
          () => widget.client.getAllDayStepsRows(widget.device, yy: yy, mm: mm, dd: dd),
        );
      } catch (e, stackTrace) {
        print('❌ [FATAL ERROR] Steps data failed: $e');
        print('Stack trace: $stackTrace');
        _dataErrors['Steps'] = _handleError(e, dateStr);
        _stepsData = null;
      }
      
      // SpO2 data
      print('📊 [7/11] Processing SpO2 data...');
      try {
        _spo2Data = await _fetchDataTypeWithAllChecks(
          'SpO2',
          0x03,
          yy, mm, dd, dateStr,
          () => widget.client.getAllDaySpo2Rows(widget.device, yy: yy, mm: mm, dd: dd),
        );
      } catch (e, stackTrace) {
        print('❌ [FATAL ERROR] SpO2 data failed: $e');
        print('Stack trace: $stackTrace');
        _dataErrors['SpO2'] = _handleError(e, dateStr);
        _spo2Data = null;
      }
      
      // Baro data
      print('📊 [8/11] Processing Baro data...');
      try {
        _baroData = await _fetchDataTypeWithAllChecks(
          'Baro',
          0x06,
          yy, mm, dd, dateStr,
          () => widget.client.getAllDayBaroRows(widget.device, yy: yy, mm: mm, dd: dd),
        );
      } catch (e, stackTrace) {
        print('❌ [FATAL ERROR] Baro data failed: $e');
        print('Stack trace: $stackTrace');
        _dataErrors['Baro'] = _handleError(e, dateStr);
        _baroData = null;
      }
      
      // BP data
      print('📊 [9/11] Processing BP data...');
      try {
        _bpData = await _fetchDataTypeWithAllChecks(
          'BP',
          0x07,
          yy, mm, dd, dateStr,
          () => widget.client.getAllDayBpRows(widget.device, yy: yy, mm: mm, dd: dd),
        );
      } catch (e, stackTrace) {
        print('❌ [FATAL ERROR] BP data failed: $e');
        print('Stack trace: $stackTrace');
        _dataErrors['BP'] = _handleError(e, dateStr);
        _bpData = null;
      }
      
      // Calories data
      print('📊 [10/11] Processing Calories data...');
      try {
        _caloriesData = await _fetchDataTypeWithAllChecks(
          'Calories',
          0x09,
          yy, mm, dd, dateStr,
          () => widget.client.getAllDayCaloriesRows(widget.device, yy: yy, mm: mm, dd: dd),
        );
      } catch (e, stackTrace) {
        print('❌ [FATAL ERROR] Calories data failed: $e');
        print('Stack trace: $stackTrace');
        _dataErrors['Calories'] = _handleError(e, dateStr);
        _caloriesData = null;
      }

      // Sleep data (no packet status check)
      print('📊 [11/11] Processing Sleep data...');
      try {
        _sleepData = await _fetchSleepDataWithChecks(
          yy, mm, dd, dateStr,
          () => widget.client.getAllDaySleepRows(widget.device, yy: yy, mm: mm, dd: dd, includeSummary: true),
        );
      } catch (e, stackTrace) {
        print('❌ [FATAL ERROR] Sleep data failed: $e');
        print('Stack trace: $stackTrace');
        _dataErrors['Sleep'] = _handleError(e, dateStr);
        _sleepData = null;
      }

      print('✅ All historical data retrieval completed');

      // Summary data (currently disabled)
      _summaryData = null;

      print('✅ All operations completed - sensors re-enabled');

      setState(() {
        _isLoadingHistory = false;
        _hasAttemptedLoad = true; // Mark that we've attempted to load data
        final errorCount = _dataErrors.values.where((e) => e != null).length;
        if (errorCount > 0) {
          _statusMessage = 'Historical data loaded with $errorCount error(s). See details below.';
        } else {
          _statusMessage = 'Historical data loaded successfully!';
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingHistory = false;
        _hasAttemptedLoad = true; // Mark that we've attempted to load data (even if it failed)
        _statusMessage = 'Error loading historical data: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All HC20 Data'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistoricalData,
            tooltip: 'Load Historical Data',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Card
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),

          // Real-time Data Section
          _buildSectionHeader('🔴 Real-time Data', Icons.sensors),
          _buildRealtimeDataSection(),

          const SizedBox(height: 24),

          // Historical Data Section
          _buildSectionHeader('📊 Historical Data', Icons.history),
          if (_isLoadingHistory)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (!_hasAttemptedLoad)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_download, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Tap the refresh button to load today\'s historical data',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadHistoricalData,
                      icon: const Icon(Icons.download),
                      label: const Text('Load Historical Data'),
                    ),
                  ],
                ),
              ),
            )
          else
            _buildHistoricalDataSection(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealtimeDataSection() {
    if (_realtimeData == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text('Waiting for real-time data...'),
          ),
        ),
      );
    }

    final data = _realtimeData!;

    return Column(
      children: [
        // Battery & Basic Activity
        _buildDataCard(
          '🔋 Battery & Activity',
          [
            if (data.battery != null) ...[
              _buildDataRow('Battery', '${data.battery!.percent}%'),
              _buildDataRow('Charging', data.battery!.charge > 0 ? 'Yes' : 'No'),
            ],
            if (data.basicData != null && data.basicData!.length >= 3) ...[
              _buildDataRow('Steps', '${data.basicData![0]}'),
              _buildDataRow('Calories', '${data.basicData![1]} kcal'),
              _buildDataRow('Distance', '${data.basicData![2]} m'),
            ],
          ],
        ),

        // Vital Signs
        _buildDataCard(
          '❤️ Vital Signs',
          [
            if (data.heart != null) _buildDataRow('Heart Rate', '${data.heart} bpm'),
            if (data.rri != null) _buildDataRow('RR Interval', '${data.rri} ms'),
            if (data.spo2 != null) _buildDataRow('SpO2', '${data.spo2}%'),
            if (data.bp != null && data.bp!.length >= 2)
              _buildDataRow('Blood Pressure', '${data.bp![0]}/${data.bp![1]} mmHg'),
          ],
        ),

        // Temperature
        _buildDataCard(
          '🌡️ Temperature',
          [
            if (data.temperature != null && data.temperature!.isNotEmpty) ...[
              if (data.temperature!.length > 0)
                _buildDataRow('Hand Temp', '${(data.temperature![0] / 100).toStringAsFixed(2)}°C'),
              if (data.temperature!.length > 1)
                _buildDataRow('Env Temp', '${(data.temperature![1] / 100).toStringAsFixed(2)}°C'),
              if (data.temperature!.length > 2)
                _buildDataRow('Body Temp', '${(data.temperature![2] / 100).toStringAsFixed(2)}°C'),
            ],
          ],
        ),

        // Environmental
        _buildDataCard(
          '🌍 Environmental',
          [
            if (data.baro != null) _buildDataRow('Barometric Pressure', '${data.baro} Pa'),
            if (data.wear != null) _buildDataRow('Wear Status', data.wear == 1 ? 'Worn' : 'Not Worn'),
          ],
        ),

        // Sleep Data
        if (data.sleep != null && data.sleep!.length >= 5)
          _buildDataCard(
            '😴 Sleep Data',
            [
              _buildDataRow('Sleep Status', '${data.sleep![0]}'),
              _buildDataRow('Deep Sleep', '${data.sleep![1]}'),
              _buildDataRow('Light Sleep', '${data.sleep![2]}'),
              _buildDataRow('REM Sleep', '${data.sleep![3]}'),
              _buildDataRow('Sober/Awake', '${data.sleep![4]}'),
            ],
          ),

        // GNSS/GPS Data
        if (data.gnss != null && data.gnss!.length >= 6)
          _buildDataCard(
            '📍 GPS Data',
            [
              _buildDataRow('GPS Status', data.gnss![0] == 1 ? 'On' : 'Off'),
              _buildDataRow('Signal Quality', '${data.gnss![1]}'),
              _buildDataRow('Latitude', '${data.gnss![3]}°'),
              _buildDataRow('Longitude', '${data.gnss![4]}°'),
              _buildDataRow('Altitude', '${data.gnss![5]} m'),
            ],
          ),

        // HRV Metrics
        if (data.hrvMetrics != null)
          _buildDataCard(
            '💓 HRV Metrics',
            [
              _buildDataRow('SDNN', '${data.hrvMetrics!.sdnn}'),
              _buildDataRow('Total Power', '${data.hrvMetrics!.tp}'),
              _buildDataRow('Low Frequency', '${data.hrvMetrics!.lf}'),
              _buildDataRow('High Frequency', '${data.hrvMetrics!.hf}'),
              _buildDataRow('Very Low Frequency', '${data.hrvMetrics!.vlf}'),
            ],
          ),

        // HRV2 Metrics
        if (data.hrv2Metrics != null)
          _buildDataCard(
            '🧠 Advanced HRV Metrics',
            [
              _buildDataRow('Mental Stress', '${data.hrv2Metrics!.mentStress}'),
              _buildDataRow('Fatigue', '${data.hrv2Metrics!.fatigueLevel}'),
              _buildDataRow('Stress Resistance', '${data.hrv2Metrics!.stressResistance}'),
              _buildDataRow('Regulation Ability', '${data.hrv2Metrics!.regulationAbility}'),
            ],
          ),
      ],
    );
  }

  Widget _buildErrorCard(String title, String errorMessage) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoricalDataSection() {
    return Column(
      children: [
        // Summary Data
        if (_dataErrors['Summary'] != null)
          _buildErrorCard('📝 Daily Summary', _dataErrors['Summary']!)
        else if (_summaryData != null && _summaryData!.isNotEmpty)
          _buildHistoricalCard(
            '📝 Daily Summary',
            _summaryData!.first.values,
          ),

        // Heart Rate History
        if (_dataErrors['Heart'] != null)
          _buildErrorCard('💗 Heart Rate History', _dataErrors['Heart']!)
        else if (_heartData != null && _heartData!.isNotEmpty)
          _buildHistoricalListCard(
            '💗 Heart Rate History',
            _heartData!,
            'bpm',
            ' bpm',
          ),

        // Steps History
        if (_dataErrors['Steps'] != null)
          _buildErrorCard('👣 Steps History', _dataErrors['Steps']!)
        else if (_stepsData != null && _stepsData!.isNotEmpty)
          _buildHistoricalListCard(
            '👣 Steps History',
            _stepsData!,
            'steps',
            ' steps',
          ),

        // SpO2 History
        if (_dataErrors['SpO2'] != null)
          _buildErrorCard('🫁 SpO2 History', _dataErrors['SpO2']!)
        else if (_spo2Data != null && _spo2Data!.isNotEmpty)
          _buildHistoricalListCard(
            '🫁 SpO2 History',
            _spo2Data!,
            'spo2Pct',
            '%',
          ),

        // RRI History
        if (_dataErrors['RRI'] != null)
          _buildErrorCard('💓 RRI History', _dataErrors['RRI']!)
        else if (_rriData != null && _rriData!.isNotEmpty)
          _buildHistoricalListCard(
            '💓 RRI History',
            _rriData!,
            'rriMs',
            ' ms',
          ),

        // Temperature History
        if (_dataErrors['Temperature'] != null)
          _buildErrorCard('🌡️ Temperature History', _dataErrors['Temperature']!)
        else if (_temperatureData != null && _temperatureData!.isNotEmpty)
          _buildTemperatureHistoryCard(),

        // Barometric Pressure History
        if (_dataErrors['Baro'] != null)
          _buildErrorCard('🌡️ Barometric Pressure History', _dataErrors['Baro']!)
        else if (_baroData != null && _baroData!.isNotEmpty)
          _buildHistoricalListCard(
            '🌡️ Barometric Pressure History',
            _baroData!,
            'pressurePa',
            ' Pa',
          ),

        // Blood Pressure History
        if (_dataErrors['BP'] != null)
          _buildErrorCard('🩺 Blood Pressure History', _dataErrors['BP']!)
        else if (_bpData != null && _bpData!.isNotEmpty)
          _buildBloodPressureHistoryCard(),

        // HRV History
        if (_dataErrors['HRV'] != null)
          _buildErrorCard('💓 HRV History', _dataErrors['HRV']!)
        else if (_hrvData != null && _hrvData!.isNotEmpty)
          _buildHRVHistoryCard(),

        // Sleep History
        if (_dataErrors['Sleep'] != null)
          _buildErrorCard('😴 Sleep History', _dataErrors['Sleep']!)
        else if (_sleepData != null && _sleepData!.isNotEmpty)
          _buildSleepHistoryCard(),

        // Calories History
        if (_dataErrors['Calories'] != null)
          _buildErrorCard('🔥 Calories History', _dataErrors['Calories']!)
        else if (_caloriesData != null && _caloriesData!.isNotEmpty)
          _buildHistoricalListCard(
            '🔥 Calories History',
            _caloriesData!,
            'kcal',
            ' kcal',
          ),

        // HRV2 History
        if (_dataErrors['HRV2'] != null)
          _buildErrorCard('🧠 Advanced HRV History', _dataErrors['HRV2']!)
        else if (_hrv2Data != null && _hrv2Data!.isNotEmpty)
          _buildHRV2HistoryCard(),
      ],
    );
  }

  Widget _buildDataCard(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildHistoricalCard(String title, Map<String, dynamic> values) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            ...values.entries.map((entry) =>
              _buildDataRow(
                _formatKey(entry.key),
                entry.value?.toString() ?? 'N/A',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoricalListCard(
    String title,
    List<Hc20AllDayRow> data,
    String valueKey,
    String unit,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${data.length} data points'),
        children: [
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: data.length > 10 ? 10 : data.length,
              itemBuilder: (context, index) {
                final row = data[index];
                final value = row.values[valueKey];
                return ListTile(
                  dense: true,
                  title: Text(row.dateTime),
                  trailing: Text(
                    value != null ? '$value$unit' : 'N/A',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
          if (data.length > 10)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Showing first 10 of ${data.length} records',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTemperatureHistoryCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: const Text(
          '🌡️ Temperature History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${_temperatureData!.length} data points'),
        children: [
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: _temperatureData!.length > 10 ? 10 : _temperatureData!.length,
              itemBuilder: (context, index) {
                final row = _temperatureData![index];
                return ListTile(
                  dense: true,
                  title: Text(row.dateTime),
                  subtitle: Row(
                    children: [
                      Text('Skin: ${row.values['skinC']}°C'),
                      const SizedBox(width: 16),
                      Text('Env: ${row.values['envC']}°C'),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBloodPressureHistoryCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: const Text(
          '🩺 Blood Pressure History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${_bpData!.length} data points'),
        children: [
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: _bpData!.length > 10 ? 10 : _bpData!.length,
              itemBuilder: (context, index) {
                final row = _bpData![index];
                return ListTile(
                  dense: true,
                  title: Text(row.dateTime),
                  trailing: Text(
                    '${row.values['sys']}/${row.values['dia']} mmHg',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHRVHistoryCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: const Text(
          '💓 HRV History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${_hrvData!.length} data points'),
        children: [
          SizedBox(
            height: 300,
            child: ListView.builder(
              itemCount: _hrvData!.length > 5 ? 5 : _hrvData!.length,
              itemBuilder: (context, index) {
                final row = _hrvData![index];
                return ExpansionTile(
                  dense: true,
                  title: Text(row.dateTime, style: const TextStyle(fontSize: 14)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _buildDataRow('SDNN', '${row.values['sdnn']} s'),
                          _buildDataRow('Total Power', '${row.values['tp']} s'),
                          _buildDataRow('Low Frequency', '${row.values['lf']} s'),
                          _buildDataRow('High Frequency', '${row.values['hf']} s'),
                          _buildDataRow('Very Low Frequency', '${row.values['vlf']} s'),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepHistoryCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: const Text(
          '😴 Sleep History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${_sleepData!.length} data points'),
        children: [
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: _sleepData!.length > 10 ? 10 : _sleepData!.length,
              itemBuilder: (context, index) {
                final row = _sleepData![index];
                if (row.values.containsKey('sleepState')) {
                  return ListTile(
                    dense: true,
                    title: Text(row.dateTime),
                    trailing: Text(
                      row.values['sleepState'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                } else {
                  return ExpansionTile(
                    dense: true,
                    title: const Text('Sleep Summary'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            _buildDataRow('Sober', '${row.values['soberMin']} min'),
                            _buildDataRow('Light', '${row.values['lightMin']} min'),
                            _buildDataRow('Deep', '${row.values['deepMin']} min'),
                            _buildDataRow('REM', '${row.values['remMin']} min'),
                            if (row.values['napMin'] != null)
                              _buildDataRow('Nap', '${row.values['napMin']} min'),
                          ],
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHRV2HistoryCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: const Text(
          '🧠 Advanced HRV History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${_hrv2Data!.length} data points'),
        children: [
          SizedBox(
            height: 250,
            child: ListView.builder(
              itemCount: _hrv2Data!.length > 5 ? 5 : _hrv2Data!.length,
              itemBuilder: (context, index) {
                final row = _hrv2Data![index];
                return ExpansionTile(
                  dense: true,
                  title: Text(row.dateTime, style: const TextStyle(fontSize: 14)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _buildDataRow('Mental Stress', '${row.values['mentalStress']}'),
                          _buildDataRow('Fatigue', '${row.values['fatigue']}'),
                          _buildDataRow('Stress Resistance', '${row.values['stressResistance']}'),
                          _buildDataRow('Regulation Ability', '${row.values['regulationAbility']}'),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  String _formatKey(String key) {
    // Convert camelCase to Title Case
    return key
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(0)}',
        )
        .trim()
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
