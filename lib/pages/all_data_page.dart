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
  
  bool _isLoadingHistory = false;
  String _statusMessage = 'Streaming real-time data...';

  @override
  void initState() {
    super.initState();
    _startRealtimeStream();
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

  @override
  void dispose() {
    _dataRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadHistoricalData() async {
    setState(() {
      _isLoadingHistory = true;
      _statusMessage = 'Loading historical data...';
    });

    try {
      final now = DateTime.now();
      final yy = now.year % 100;
      final mm = now.month;
      final dd = now.day;

      // Load all historical data sequentially to avoid incomplete data packets
      _hrvData = await widget.client.getAllDayHrvRows(widget.device, yy: yy, mm: mm, dd: dd);
      _hrv2Data = await widget.client.getAllDayHrv2Rows(widget.device, yy: yy, mm: mm, dd: dd);
      _temperatureData = await widget.client.getAllDayTemperatureRows(widget.device, yy: yy, mm: mm, dd: dd);
      _rriData = await widget.client.getAllDayRriRows(widget.device, yy: yy, mm: mm, dd: dd);
      _summaryData = await widget.client.getAllDaySummaryRows(widget.device, yy: yy, mm: mm, dd: dd);
      _heartData = await widget.client.getAllDayHeartRows(widget.device, yy: yy, mm: mm, dd: dd);
      _stepsData = await widget.client.getAllDayStepsRows(widget.device, yy: yy, mm: mm, dd: dd);
      _spo2Data = await widget.client.getAllDaySpo2Rows(widget.device, yy: yy, mm: mm, dd: dd);
      _baroData = await widget.client.getAllDayBaroRows(widget.device, yy: yy, mm: mm, dd: dd);
      _bpData = await widget.client.getAllDayBpRows(widget.device, yy: yy, mm: mm, dd: dd);
      _caloriesData = await widget.client.getAllDayCaloriesRows(widget.device, yy: yy, mm: mm, dd: dd);
      _sleepData = await widget.client.getAllDaySleepRows(widget.device, yy: yy, mm: mm, dd: dd, includeSummary: true);


      setState(() {
        _isLoadingHistory = false;
        _statusMessage = 'Historical data loaded successfully!';
      });
    } catch (e) {
      setState(() {
        _isLoadingHistory = false;
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
          else if (_summaryData == null)
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

  Widget _buildHistoricalDataSection() {
    return Column(
      children: [
        // Summary Data
        if (_summaryData != null && _summaryData!.isNotEmpty)
          _buildHistoricalCard(
            '📝 Daily Summary',
            _summaryData!.first.values,
          ),

        // Heart Rate History
        if (_heartData != null && _heartData!.isNotEmpty)
          _buildHistoricalListCard(
            '💗 Heart Rate History',
            _heartData!,
            'bpm',
            ' bpm',
          ),

        // Steps History
        if (_stepsData != null && _stepsData!.isNotEmpty)
          _buildHistoricalListCard(
            '👣 Steps History',
            _stepsData!,
            'steps',
            ' steps',
          ),

        // SpO2 History
        if (_spo2Data != null && _spo2Data!.isNotEmpty)
          _buildHistoricalListCard(
            '🫁 SpO2 History',
            _spo2Data!,
            'spo2Pct',
            '%',
          ),

        // RRI History
        if (_rriData != null && _rriData!.isNotEmpty)
          _buildHistoricalListCard(
            '💓 RRI History',
            _rriData!,
            'rriMs',
            ' ms',
          ),

        // Temperature History
        if (_temperatureData != null && _temperatureData!.isNotEmpty)
          _buildTemperatureHistoryCard(),

        // Barometric Pressure History
        if (_baroData != null && _baroData!.isNotEmpty)
          _buildHistoricalListCard(
            '🌡️ Barometric Pressure History',
            _baroData!,
            'pressurePa',
            ' Pa',
          ),

        // Blood Pressure History
        if (_bpData != null && _bpData!.isNotEmpty)
          _buildBloodPressureHistoryCard(),

        // HRV History
        if (_hrvData != null && _hrvData!.isNotEmpty)
          _buildHRVHistoryCard(),

        // Sleep History
        if (_sleepData != null && _sleepData!.isNotEmpty)
          _buildSleepHistoryCard(),

        // Calories History
        if (_caloriesData != null && _caloriesData!.isNotEmpty)
          _buildHistoricalListCard(
            '🔥 Calories History',
            _caloriesData!,
            'kcal',
            ' kcal',
          ),

        // HRV2 History
        if (_hrv2Data != null && _hrv2Data!.isNotEmpty)
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
