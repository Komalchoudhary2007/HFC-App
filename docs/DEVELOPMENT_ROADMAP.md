# HFC-Nitto Wearable App Development Roadmap

## Executive Summary

This document outlines the complete development strategy for the HFC-Nitto wearable stress management platform, optimized for minimal mobile app complexity while maximizing backend processing capabilities.

**Current State**: ✅ Basic Flutter app connecting to HC20 wearable, fetching real-time data  
**Target State**: Complete stress monitoring system with mobile app + web dashboard + automated interventions

---

## Architecture Overview

### Recommended Architecture (Backend-Heavy Approach)

```
┌─────────────────┐
│  HC20 Wearable  │ (Nitto Device)
└────────┬────────┘
         │ Bluetooth
         ↓
┌─────────────────┐
│   Flutter App   │ (Minimal Logic)
│  - Data Capture │
│  - Display UI   │
│  - Notifications│
└────────┬────────┘
         │ REST API
         ↓
┌─────────────────┐
│  HFC Backend    │ (api.hireforcare.com)
│  - Data Storage │
│  - AI Analysis  │
│  - Alert Engine │
│  - Business Logic│
└────────┬────────┘
         │
    ┌────┴────┐
    ↓         ↓
┌────────┐ ┌──────────────┐
│Postgres│ │ React Web    │
│on Prism│ │ Dashboard    │
└────────┘ └──────────────┘
```

**Why This Approach?**
- ✅ Easier to update business logic without app releases
- ✅ Centralized stress analysis algorithms
- ✅ Unified data processing for all users
- ✅ Psychologists work from web dashboard
- ✅ Mobile app stays lightweight and simple

---

## Phase 1: Backend Foundation (Weeks 1-2)

### 1.1 Database Schema Design

Create PostgreSQL database on Prisma.io with these tables:

#### Core Tables

**users**
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    group_type VARCHAR(10) CHECK (group_type IN ('A', 'B', 'C')),
    enrollment_date TIMESTAMP DEFAULT NOW(),
    baseline_hrv_threshold DECIMAL(10,2),
    baseline_calibration_complete BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

**devices**
```sql
CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    device_mac VARCHAR(17) UNIQUE NOT NULL,
    device_name VARCHAR(100),
    firmware_version VARCHAR(50),
    paired_at TIMESTAMP DEFAULT NOW(),
    last_sync TIMESTAMP,
    status VARCHAR(20) DEFAULT 'active'
);
```

**realtime_vitals**
```sql
CREATE TABLE realtime_vitals (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    device_id UUID REFERENCES devices(id),
    timestamp TIMESTAMP NOT NULL,
    heart_rate INTEGER,
    spo2 INTEGER,
    systolic_bp INTEGER,
    diastolic_bp INTEGER,
    skin_temp DECIMAL(5,2),
    steps INTEGER,
    battery_level INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_realtime_user_time ON realtime_vitals(user_id, timestamp DESC);
```

**hrv_data**
```sql
CREATE TABLE hrv_data (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    timestamp TIMESTAMP NOT NULL,
    sdnn DECIMAL(10,3),
    tp DECIMAL(10,3),
    lf DECIMAL(10,3),
    hf DECIMAL(10,3),
    vlf DECIMAL(10,3),
    lf_hf_ratio DECIMAL(10,3),
    stress_score INTEGER, -- Calculated 0-100
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_hrv_user_time ON hrv_data(user_id, timestamp DESC);
```

**hrv2_stress_metrics**
```sql
CREATE TABLE hrv2_stress_metrics (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    timestamp TIMESTAMP NOT NULL,
    mental_stress INTEGER,
    fatigue INTEGER,
    stress_resistance INTEGER,
    regulation_ability INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);
```

**sleep_data**
```sql
CREATE TABLE sleep_data (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    total_sleep_minutes INTEGER,
    deep_sleep_minutes INTEGER,
    light_sleep_minutes INTEGER,
    rem_sleep_minutes INTEGER,
    awake_minutes INTEGER,
    sleep_efficiency DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, date)
);
```

**stress_alerts**
```sql
CREATE TABLE stress_alerts (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    triggered_at TIMESTAMP NOT NULL,
    stress_level INTEGER NOT NULL,
    duration_minutes INTEGER,
    alert_type VARCHAR(50), -- 'level_4_sustained', 'weekly_threshold', etc.
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'user_declined', 'user_accepted', 'ignored', 'escalated'
    user_response_at TIMESTAMP,
    breathing_exercise_completed BOOLEAN DEFAULT FALSE,
    vas_stress_rating INTEGER, -- 1-10 scale
    counselling_booked BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_alerts_user_status ON stress_alerts(user_id, status, triggered_at DESC);
```

**intervention_sessions**
```sql
CREATE TABLE intervention_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    alert_id BIGINT REFERENCES stress_alerts(id),
    session_type VARCHAR(50), -- 'breathing_guide', 'counselling_call', 'proactive_outreach'
    scheduled_at TIMESTAMP,
    completed_at TIMESTAMP,
    psychologist_id UUID, -- Reference to staff table
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);
```

**child_meltdown_logs**
```sql
CREATE TABLE child_meltdown_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    logged_at TIMESTAMP NOT NULL,
    severity INTEGER CHECK (severity BETWEEN 1 AND 10),
    duration_minutes INTEGER,
    triggers TEXT,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);
```

**psi_sf_assessments**
```sql
CREATE TABLE psi_sf_assessments (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    assessment_date DATE NOT NULL,
    assessment_phase VARCHAR(20), -- 'baseline', 'month_2_5', 'month_5'
    total_score INTEGER,
    subscale_scores JSONB, -- Store detailed subscale results
    percentile INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);
```

### 1.2 API Endpoints Design

Create RESTful API at `api.hireforcare.com/api/v1/`

#### Authentication Endpoints
```
POST   /auth/register          - Register new user
POST   /auth/login             - Login user
POST   /auth/refresh           - Refresh token
GET    /auth/profile           - Get user profile
```

#### Device Management
```
POST   /devices/pair           - Pair device with user
GET    /devices/my-devices     - Get user's devices
DELETE /devices/:id             - Unpair device
```

#### Data Upload Endpoints (Mobile App → Backend)
```
POST   /vitals/realtime        - Upload real-time vitals (bulk)
POST   /vitals/hrv             - Upload HRV data
POST   /vitals/hrv2            - Upload HRV2 stress metrics
POST   /vitals/sleep           - Upload sleep data
POST   /vitals/daily-summary   - Upload daily summary
```

Request payload example:
```json
{
  "device_mac": "AA:BB:CC:DD:EE:FF",
  "readings": [
    {
      "timestamp": "2024-12-04T10:30:00Z",
      "heart_rate": 75,
      "spo2": 98,
      "systolic_bp": 120,
      "diastolic_bp": 80,
      "skin_temp": 36.5,
      "steps": 1250,
      "battery_level": 85
    }
  ]
}
```

#### Data Retrieval Endpoints (Mobile App ← Backend)
```
GET    /vitals/latest          - Get latest vitals
GET    /vitals/history         - Get historical data (with pagination)
GET    /alerts/active          - Get active stress alerts
GET    /alerts/history         - Get alert history
GET    /sessions/upcoming      - Get upcoming counselling sessions
```

#### Alert Response Endpoints
```
POST   /alerts/:id/respond     - User responds to alert
POST   /alerts/:id/breathing-complete  - Mark breathing exercise complete
POST   /alerts/:id/book-session        - Book counselling session
```

#### Child Behavior Logging
```
POST   /child/meltdown         - Log child meltdown
GET    /child/meltdown-history - Get meltdown history
```

#### Assessment Endpoints
```
POST   /assessments/psi-sf     - Submit PSI-SF assessment
GET    /assessments/history    - Get assessment history
```

---

## Phase 2: Mobile App Development (Weeks 3-4)

### 2.1 Project Structure Refactoring

Organize codebase:
```
lib/
├── main.dart
├── config/
│   ├── api_config.dart           # API endpoints
│   ├── app_config.dart           # App-wide config
│   └── nitto_config.dart         # Nitto SDK credentials
├── models/
│   ├── user.dart
│   ├── device.dart
│   ├── vital_reading.dart
│   ├── hrv_data.dart
│   ├── stress_alert.dart
│   └── api_response.dart
├── services/
│   ├── auth_service.dart         # Authentication
│   ├── api_service.dart          # HTTP client wrapper
│   ├── device_service.dart       # HC20 device management
│   ├── data_sync_service.dart    # Background sync
│   ├── notification_service.dart # Push notifications
│   └── local_storage_service.dart # SQLite cache
├── providers/                     # State management (Provider/Riverpod)
│   ├── auth_provider.dart
│   ├── device_provider.dart
│   └── vitals_provider.dart
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── onboarding/
│   │   ├── device_pairing_screen.dart
│   │   └── calibration_screen.dart
│   ├── home/
│   │   ├── dashboard_screen.dart
│   │   └── vitals_chart_screen.dart
│   ├── alerts/
│   │   ├── stress_alert_screen.dart
│   │   └── breathing_exercise_screen.dart
│   ├── sessions/
│   │   └── sessions_list_screen.dart
│   └── profile/
│       └── profile_screen.dart
├── widgets/
│   ├── vital_card.dart
│   ├── stress_meter.dart
│   └── custom_buttons.dart
└── utils/
    ├── constants.dart
    ├── helpers.dart
    └── validators.dart
```

### 2.2 Core Services Implementation

#### API Service (`lib/services/api_service.dart`)
```dart
import 'package:dio/dio.dart';
import '../config/api_config.dart';

class ApiService {
  final Dio _dio;
  
  ApiService() : _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: Duration(seconds: 30),
    receiveTimeout: Duration(seconds: 30),
  )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add auth token
        final token = await _getStoredToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Handle token refresh
          await _refreshToken();
          return handler.resolve(await _retry(error.requestOptions));
        }
        return handler.next(error);
      },
    ));
  }
  
  // Upload realtime vitals
  Future<void> uploadVitals(List<VitalReading> readings) async {
    try {
      await _dio.post('/vitals/realtime', data: {
        'readings': readings.map((r) => r.toJson()).toList(),
      });
    } catch (e) {
      throw ApiException('Failed to upload vitals: $e');
    }
  }
  
  // Upload HRV data
  Future<void> uploadHrvData(List<HrvReading> data) async {
    try {
      await _dio.post('/vitals/hrv', data: {
        'readings': data.map((r) => r.toJson()).toList(),
      });
    } catch (e) {
      throw ApiException('Failed to upload HRV: $e');
    }
  }
  
  // Get active alerts
  Future<List<StressAlert>> getActiveAlerts() async {
    try {
      final response = await _dio.get('/alerts/active');
      return (response.data['alerts'] as List)
          .map((json) => StressAlert.fromJson(json))
          .toList();
    } catch (e) {
      throw ApiException('Failed to fetch alerts: $e');
    }
  }
  
  // Respond to alert
  Future<void> respondToAlert(String alertId, AlertResponse response) async {
    try {
      await _dio.post('/alerts/$alertId/respond', data: response.toJson());
    } catch (e) {
      throw ApiException('Failed to respond to alert: $e');
    }
  }
}
```

#### Data Sync Service (`lib/services/data_sync_service.dart`)
```dart
import 'dart:async';
import 'package:workmanager/workmanager.dart';

class DataSyncService {
  static const String syncTaskName = 'com.hfc.data_sync';
  
  // Initialize background sync
  static void initialize() {
    Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    Workmanager().registerPeriodicTask(
      syncTaskName,
      syncTaskName,
      frequency: Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }
  
  // Sync pending data
  Future<void> syncPendingData() async {
    final localStorage = LocalStorageService();
    final apiService = ApiService();
    
    // Get unsync'd vitals from local DB
    final pendingVitals = await localStorage.getUnsyncedVitals();
    if (pendingVitals.isNotEmpty) {
      await apiService.uploadVitals(pendingVitals);
      await localStorage.markVitalsAsSynced(pendingVitals.map((v) => v.id).toList());
    }
    
    // Get unsync'd HRV data
    final pendingHrv = await localStorage.getUnsyncedHrv();
    if (pendingHrv.isNotEmpty) {
      await apiService.uploadHrvData(pendingHrv);
      await localStorage.markHrvAsSynced(pendingHrv.map((h) => h.id).toList());
    }
  }
}

// Background callback
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final syncService = DataSyncService();
      await syncService.syncPendingData();
      return true;
    } catch (e) {
      return false;
    }
  });
}
```

### 2.3 Key Screens Implementation

#### Dashboard Screen
```dart
class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  final DeviceService _deviceService = DeviceService();
  
  VitalReading? _latestVitals;
  List<StressAlert> _activeAlerts = [];
  Timer? _dataFetchTimer;
  
  @override
  void initState() {
    super.initState();
    _startRealtimeDataStream();
    _startPeriodicSync();
    _checkForAlerts();
  }
  
  void _startRealtimeDataStream() {
    _deviceService.getRealtimeStream().listen((vitals) {
      setState(() => _latestVitals = vitals);
      _saveToLocalStorage(vitals);
    });
  }
  
  void _startPeriodicSync() {
    _dataFetchTimer = Timer.periodic(Duration(seconds: 30), (_) async {
      await _syncDataToBackend();
      await _checkForAlerts();
    });
  }
  
  Future<void> _syncDataToBackend() async {
    final localStorage = LocalStorageService();
    final unsyncedData = await localStorage.getUnsyncedVitals();
    
    if (unsyncedData.isNotEmpty) {
      try {
        await _apiService.uploadVitals(unsyncedData);
        await localStorage.markVitalsAsSynced(
          unsyncedData.map((v) => v.id).toList()
        );
      } catch (e) {
        // Handle error - data stays in local storage
      }
    }
  }
  
  Future<void> _checkForAlerts() async {
    final alerts = await _apiService.getActiveAlerts();
    if (alerts.isNotEmpty && alerts != _activeAlerts) {
      setState(() => _activeAlerts = alerts);
      _showAlertDialog(alerts.first);
    }
  }
  
  void _showAlertDialog(StressAlert alert) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StressAlertDialog(alert: alert),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('HFC Wellness')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Active alerts banner
          if (_activeAlerts.isNotEmpty)
            AlertBanner(alerts: _activeAlerts),
          
          // Real-time vitals cards
          VitalCard(
            title: 'Heart Rate',
            value: _latestVitals?.heartRate?.toString() ?? '--',
            unit: 'bpm',
            icon: Icons.favorite,
          ),
          VitalCard(
            title: 'SpO2',
            value: _latestVitals?.spo2?.toString() ?? '--',
            unit: '%',
            icon: Icons.air,
          ),
          // ... more vital cards
        ],
      ),
    );
  }
}
```

---

## Phase 3: Backend Alert Engine (Weeks 5-6)

### 3.1 Stress Analysis Service

Create backend service to process incoming HRV data:

**Backend Logic (Node.js/Python example)**
```python
# services/stress_analyzer.py

class StressAnalyzer:
    def __init__(self, user_id):
        self.user = User.query.get(user_id)
        self.baseline_threshold = self.user.baseline_hrv_threshold
    
    def analyze_hrv_data(self, hrv_reading):
        """Analyze single HRV reading and determine stress level"""
        
        # Calculate Z-score against baseline
        z_score = (hrv_reading.sdnn - self.baseline_threshold) / self.baseline_std
        
        # Determine stress level (0-5)
        if z_score >= 0:
            stress_level = 0  # Normal/Low stress
        elif z_score >= -1:
            stress_level = 2  # Moderate stress
        elif z_score >= -2:
            stress_level = 3  # Elevated stress
        else:
            stress_level = 4  # High stress
        
        # Store stress score
        hrv_reading.stress_score = self._map_to_100_scale(stress_level)
        db.session.commit()
        
        return stress_level
    
    def check_sustained_stress(self):
        """Check if user has sustained Level 4 stress for 30+ min"""
        
        # Get HRV readings from last 30 minutes
        thirty_min_ago = datetime.now() - timedelta(minutes=30)
        recent_readings = HrvData.query.filter(
            HrvData.user_id == self.user.id,
            HrvData.timestamp >= thirty_min_ago
        ).all()
        
        # Check if all readings are Level 4
        stress_levels = [self.analyze_hrv_data(r) for r in recent_readings]
        
        if len(stress_levels) >= 6 and all(level >= 4 for level in stress_levels):
            return True
        
        return False
    
    def trigger_alert(self, alert_type='level_4_sustained'):
        """Create stress alert and trigger intervention"""
        
        # Check if alert already exists in last hour
        existing = StressAlert.query.filter(
            StressAlert.user_id == self.user.id,
            StressAlert.triggered_at >= datetime.now() - timedelta(hours=1),
            StressAlert.status.in_(['pending', 'ignored'])
        ).first()
        
        if existing:
            return existing  # Don't duplicate alerts
        
        # Create new alert
        alert = StressAlert(
            user_id=self.user.id,
            triggered_at=datetime.now(),
            stress_level=4,
            alert_type=alert_type,
            status='pending'
        )
        db.session.add(alert)
        db.session.commit()
        
        # Send push notification to mobile app
        self._send_push_notification(alert)
        
        return alert
    
    def _send_push_notification(self, alert):
        """Send FCM push notification"""
        message = {
            'notification': {
                'title': 'Stress Alert',
                'body': 'Your stress levels are elevated. Take a moment to breathe.',
            },
            'data': {
                'alert_id': str(alert.id),
                'type': 'stress_alert',
                'action': 'open_breathing_guide',
            },
            'priority': 'high',
        }
        
        fcm_service.send_to_user(self.user.id, message)
```

### 3.2 Alert Management Cron Jobs

**Scheduled Tasks (runs every 5 minutes)**
```python
# tasks/stress_monitoring.py

@celery.task
def monitor_user_stress_levels():
    """Check all active users for stress alerts"""
    
    active_users = User.query.filter_by(status='active').all()
    
    for user in active_users:
        if user.group_type in ['A', 'C']:  # Only for groups with wearable
            analyzer = StressAnalyzer(user.id)
            
            # Check for sustained Level 4 stress
            if analyzer.check_sustained_stress():
                analyzer.trigger_alert('level_4_sustained')

@celery.task
def check_weekly_escalation():
    """Check users who had ≥7 Level 4 events in past 7 days"""
    
    seven_days_ago = datetime.now() - timedelta(days=7)
    
    users_needing_escalation = db.session.query(
        StressAlert.user_id,
        func.count(StressAlert.id).label('alert_count')
    ).filter(
        StressAlert.triggered_at >= seven_days_ago,
        StressAlert.stress_level >= 4
    ).group_by(
        StressAlert.user_id
    ).having(
        func.count(StressAlert.id) >= 7
    ).all()
    
    for user_id, count in users_needing_escalation:
        # Flag for psychologist review
        flag_for_psychologist(user_id, f'{count} high stress events in 7 days')

@celery.task
def check_no_response_alerts():
    """Check alerts with no user response after 60 minutes"""
    
    sixty_min_ago = datetime.now() - timedelta(minutes=60)
    
    ignored_alerts = StressAlert.query.filter(
        StressAlert.status == 'pending',
        StressAlert.triggered_at <= sixty_min_ago,
        StressAlert.user_response_at.is_(None)
    ).all()
    
    for alert in ignored_alerts:
        # Send WhatsApp/SMS follow-up
        send_whatsapp_reminder(alert.user_id, alert.id)
        
        # Update status
        alert.status = 'ignored'
        db.session.commit()
```

---

## Phase 4: Web Dashboard Development (Weeks 7-8)

### 4.1 Psychologist Dashboard Features

**Key Pages:**

1. **Patient List View**
   - Show all assigned patients
   - Status indicators (active alert, overdue assessment, etc.)
   - Quick filters (Group A/B/C, high stress, recent alerts)

2. **Patient Detail View**
   - Real-time vitals chart
   - Stress trend graph (last 7/30 days)
   - Alert history timeline
   - Sleep patterns
   - Child meltdown logs
   - PSI-SF assessment scores

3. **Alert Management**
   - Active alerts requiring attention
   - One-click to initiate call/video session
   - Add session notes
   - Mark alerts as resolved

4. **Analytics Dashboard**
   - Group A vs B vs C comparison
   - Intervention success rates
   - Average stress reduction metrics

### 4.2 React Dashboard Structure

```
src/
├── components/
│   ├── charts/
│   │   ├── StressTrendChart.jsx
│   │   ├── HrvChart.jsx
│   │   └── SleepChart.jsx
│   ├── patients/
│   │   ├── PatientCard.jsx
│   │   ├── PatientList.jsx
│   │   └── PatientDetail.jsx
│   ├── alerts/
│   │   ├── AlertsList.jsx
│   │   └── AlertCard.jsx
│   └── sessions/
│       └── SessionScheduler.jsx
├── pages/
│   ├── Dashboard.jsx
│   ├── Patients.jsx
│   ├── PatientProfile.jsx
│   ├── Alerts.jsx
│   └── Analytics.jsx
├── services/
│   ├── api.js
│   └── auth.js
└── utils/
    ├── chartHelpers.js
    └── dateUtils.js
```

---

## Phase 5: Testing & Refinement (Weeks 9-10)

### 5.1 Testing Checklist

**Mobile App Testing**
- [ ] Device pairing and connection stability
- [ ] Background data sync (app in background)
- [ ] Push notification delivery
- [ ] Offline data storage and sync when online
- [ ] Battery optimization
- [ ] Alert response flow (breathing guide → VAS rating → booking)

**Backend Testing**
- [ ] API load testing (100+ concurrent users)
- [ ] Alert triggering accuracy
- [ ] Data integrity checks
- [ ] Cron job execution
- [ ] Database query optimization

**Integration Testing**
- [ ] End-to-end: Wearable → App → Backend → Dashboard
- [ ] Alert flow: Trigger → Notification → User response → Dashboard update
- [ ] Historical data retrieval

### 5.2 Performance Optimization

**Mobile App**
- Implement data pagination (don't load all history at once)
- Use SQLite for local caching
- Batch API requests (send vitals in groups of 10-20)
- Compress HRV/RRI data before upload

**Backend**
- Add Redis caching for frequently accessed data
- Index database columns (user_id, timestamp)
- Use database connection pooling
- Implement rate limiting on API endpoints

---

## Phase 6: Deployment & Monitoring (Week 11)

### 6.1 Deployment Checklist

**Mobile App**
- [ ] Update API endpoints to production URLs
- [ ] Configure Nitto SDK credentials
- [ ] Set up Firebase Cloud Messaging
- [ ] Enable ProGuard for Android
- [ ] Build and test release APK/IPA
- [ ] Submit to Play Store / App Store (internal testing first)

**Backend**
- [ ] Deploy to production server (AWS/GCP/Azure)
- [ ] Set up SSL certificates
- [ ] Configure environment variables
- [ ] Set up automated backups for PostgreSQL
- [ ] Configure monitoring (New Relic/Datadog)
- [ ] Set up error tracking (Sentry)

**Web Dashboard**
- [ ] Build production bundle
- [ ] Deploy to hosting (Vercel/Netlify)
- [ ] Configure environment variables
- [ ] Set up CDN for assets

### 6.2 Monitoring & Alerts

**Set up alerts for:**
- API response time > 2 seconds
- Database connection failures
- Failed cron job executions
- Push notification delivery failures
- App crash rate > 1%

---

## Development Timeline Summary

| Phase | Duration | Key Deliverables |
|-------|----------|------------------|
| **Phase 1**: Backend Foundation | 2 weeks | Database schema, API endpoints |
| **Phase 2**: Mobile App Core | 2 weeks | Data sync, vital display, alerts UI |
| **Phase 3**: Alert Engine | 2 weeks | Stress analysis, automated alerts |
| **Phase 4**: Web Dashboard | 2 weeks | Psychologist interface, analytics |
| **Phase 5**: Testing | 2 weeks | Full system testing, optimization |
| **Phase 6**: Deployment | 1 week | Production release |
| **Total** | **11 weeks** | Complete system live |

---

## Critical Success Factors

✅ **Keep Mobile App Simple**: Just capture and display data  
✅ **Backend Does Heavy Lifting**: All business logic on server  
✅ **Reliable Background Sync**: Data must reach backend even when app closed  
✅ **Fast Alert Delivery**: Push notifications within 1 minute  
✅ **Data Privacy**: HIPAA-compliant encryption and storage  
✅ **Psychologist UX**: Dashboard must be intuitive and fast  

---

## Next Steps (Immediate Actions)

1. **Week 1 Focus**: Set up PostgreSQL database on Prisma.io
2. **Week 1-2**: Build core API endpoints with authentication
3. **Week 2**: Start mobile app refactoring for clean architecture
4. **Week 3**: Implement background sync and local storage
5. **Week 4**: Connect mobile app to backend APIs

---

For detailed implementation code and examples, see companion documents:
- `API_DOCUMENTATION.md` - Full API endpoint specs
- `MOBILE_APP_GUIDE.md` - Step-by-step mobile implementation
- `DASHBOARD_GUIDE.md` - Web dashboard development guide
