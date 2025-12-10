# POC-Specific Implementation Guide

Based on the Nitto-HFC Agreement for 7-month Proof of Concept study.

---

## POC Overview

**Duration**: 7 months  
**Participants**: 75 parents (25 per group)  
**Groups**:
- **Group A**: Nitto Wearable + HFC Child Support (Full intervention)
- **Group B**: HFC Child Support only (No wearable)
- **Group C**: Wearable only (Control - no active intervention)

---

## Key POC Requirements

### 1. Baseline Calibration (Days 1-10)

**Technical Requirements**:
- Collect 10 days of HRV data from each participant
- Calculate personalized Z-score threshold
- Store baseline in database

**Implementation**:

```python
# Backend service: baseline_calculator.py

def calculate_baseline(user_id):
    """Calculate baseline HRV threshold from first 10 days"""
    
    # Get first 10 days of HRV data
    start_date = user.enrollment_date
    end_date = start_date + timedelta(days=10)
    
    hrv_readings = HrvData.query.filter(
        HrvData.user_id == user_id,
        HrvData.timestamp >= start_date,
        HrvData.timestamp < end_date
    ).all()
    
    if len(hrv_readings) < 100:  # Need minimum readings
        return None
    
    # Calculate mean and std of SDNN
    sdnn_values = [r.sdnn for r in hrv_readings if r.sdnn]
    mean_sdnn = statistics.mean(sdnn_values)
    std_sdnn = statistics.stdev(sdnn_values)
    
    # Update user baseline
    user = User.query.get(user_id)
    user.baseline_hrv_threshold = mean_sdnn
    user.baseline_std = std_sdnn
    user.baseline_calibration_complete = True
    db.session.commit()
    
    return mean_sdnn
```

**Mobile App**: Show calibration progress (Days 1-10)

```dart
class CalibrationScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('Baseline Calibration'),
          Text('Day 3 of 10'),
          LinearProgressIndicator(value: 0.3),
          Text('Wear your device daily for accurate baseline'),
        ],
      ),
    );
  }
}
```

---

### 2. Stress Threshold Logic (Day 11 onward)

**30-Minute Sustained Stress Rule**:
- Monitor HRV every 5 minutes
- Check if stress ≥ Level 4 (Z-score ≤ -2)
- If sustained for 30+ minutes → Trigger alert

**Implementation**:

```python
# Backend: stress_monitor.py

def check_sustained_stress(user_id):
    """Check if user has Level 4 stress for 30+ minutes"""
    
    thirty_min_ago = datetime.now() - timedelta(minutes=30)
    
    # Get HRV readings from last 30 minutes
    recent_hrvs = HrvData.query.filter(
        HrvData.user_id == user_id,
        HrvData.timestamp >= thirty_min_ago
    ).order_by(HrvData.timestamp.desc()).all()
    
    if len(recent_hrvs) < 6:  # Need at least 6 readings (5-min intervals)
        return False
    
    # Check if all recent readings are Level 4
    user = User.query.get(user_id)
    stress_levels = []
    
    for hrv in recent_hrvs:
        z_score = (hrv.sdnn - user.baseline_hrv_threshold) / user.baseline_std
        stress_level = classify_stress(z_score)
        stress_levels.append(stress_level)
    
    # All readings must be Level 4
    if all(level >= 4 for level in stress_levels):
        trigger_intervention(user_id, duration_minutes=30)
        return True
    
    return False

def classify_stress(z_score):
    """Convert Z-score to stress level (0-5)"""
    if z_score >= 0:
        return 0  # Normal
    elif z_score >= -1:
        return 2  # Moderate
    elif z_score >= -2:
        return 3  # Elevated
    else:
        return 4  # High stress (trigger alert)
```

---

### 3. User Journey Flow

#### Step 1: Alert Triggered
```python
def trigger_intervention(user_id, duration_minutes):
    """Create alert and send notification"""
    
    # Create alert record
    alert = StressAlert(
        user_id=user_id,
        triggered_at=datetime.now(),
        stress_level=4,
        duration_minutes=duration_minutes,
        alert_type='level_4_sustained',
        status='pending'
    )
    db.session.add(alert)
    db.session.commit()
    
    # Send push notification
    send_push_notification(
        user_id=user_id,
        title='Stress Alert',
        body='Your stress levels are elevated. Take a moment to breathe.',
        data={
            'alert_id': str(alert.id),
            'action': 'breathing_guide'
        }
    )
```

#### Step 2: User Opens App → Breathing Guide
```dart
class BreathingGuideScreen extends StatefulWidget {
  final String alertId;
  
  @override
  _BreathingGuideScreenState createState() => _BreathingGuideScreenState();
}

class _BreathingGuideScreenState extends State<BreathingGuideScreen> {
  int _seconds = 0;
  Timer? _timer;
  
  @override
  void initState() {
    super.initState();
    _startBreathingExercise();
  }
  
  void _startBreathingExercise() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() => _seconds++);
      
      if (_seconds >= 180) {  // 3 minutes
        _timer?.cancel();
        _showVasRating();
      }
    });
  }
  
  void _showVasRating() {
    showDialog(
      context: context,
      builder: (_) => VasRatingDialog(
        onRatingSubmit: (rating) {
          _completeExercise(rating);
        },
      ),
    );
  }
  
  Future<void> _completeExercise(int vasRating) async {
    await apiService.markBreathingComplete(
      widget.alertId,
      _seconds,
      vasRating,
    );
    
    // Show booking prompt
    _showBookingPrompt();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Breathe In', style: TextStyle(fontSize: 32)),
            SizedBox(height: 20),
            AnimatedBreathingCircle(duration: 4),
            SizedBox(height: 20),
            Text('${_seconds}s / 180s'),
          ],
        ),
      ),
    );
  }
}
```

#### Step 3: VAS Rating + Booking Prompt
```dart
class VasRatingDialog extends StatelessWidget {
  final Function(int) onRatingSubmit;
  
  @override
  Widget build(BuildContext context) {
    int _rating = 5;
    
    return AlertDialog(
      title: Text('How stressed do you feel now?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Slider(
            value: _rating.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: _rating.toString(),
            onChanged: (value) => _rating = value.toInt(),
          ),
          Text('1 = Not stressed, 10 = Very stressed'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onRatingSubmit(_rating);
          },
          child: Text('Submit'),
        ),
      ],
    );
  }
}

class BookingPromptDialog extends StatelessWidget {
  final String alertId;
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Book Counselling?'),
      content: Text('Would you like to schedule a session with a psychologist?'),
      actions: [
        TextButton(
          onPressed: () {
            // Log declined
            apiService.respondToAlert(alertId, 'decline');
            Navigator.pop(context);
          },
          child: Text('Not Now'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialRoute(
                builder: (_) => BookSessionScreen(alertId: alertId),
              ),
            );
          },
          child: Text('Book Session'),
        ),
      ],
    );
  }
}
```

---

### 4. No-Response Safeguard (60 minutes)

**Backend Cron Job** (runs every 5 minutes):

```python
@celery.task
def check_ignored_alerts():
    """Send follow-up if user doesn't respond within 60 min"""
    
    sixty_min_ago = datetime.now() - timedelta(minutes=60)
    
    ignored_alerts = StressAlert.query.filter(
        StressAlert.status == 'pending',
        StressAlert.triggered_at <= sixty_min_ago,
        StressAlert.user_response_at.is_(None)
    ).all()
    
    for alert in ignored_alerts:
        # Send WhatsApp/SMS follow-up
        send_whatsapp_message(
            user_id=alert.user_id,
            message=f"Hi, we noticed elevated stress levels. Are you okay? Reply YES to confirm."
        )
        
        # Mark as ignored
        alert.status = 'ignored'
        db.session.commit()
        
        # Flag for psychologist review
        flag_for_review(alert.user_id, alert.id)
```

---

### 5. Night-time Logic

**Suppress alerts during sleep**:

```python
def should_suppress_alert(user_id, timestamp):
    """Check if alert should be suppressed (user sleeping)"""
    
    hour = timestamp.hour
    
    # Suppress between 10 PM and 6 AM
    if hour >= 22 or hour < 6:
        return True
    
    # Also check sleep data
    latest_sleep = SleepData.query.filter_by(
        user_id=user_id
    ).order_by(SleepData.timestamp.desc()).first()
    
    if latest_sleep and latest_sleep.sleep_state in ['light', 'deep', 'rem']:
        return True
    
    return False

def send_morning_summary(user_id):
    """Send summary of nocturnal stress on morning unlock"""
    
    # Get overnight alerts (10 PM to 6 AM)
    last_night_start = datetime.now().replace(hour=22, minute=0)
    this_morning = datetime.now().replace(hour=6, minute=0)
    
    overnight_alerts = StressAlert.query.filter(
        StressAlert.user_id == user_id,
        StressAlert.triggered_at >= last_night_start,
        StressAlert.triggered_at < this_morning,
        StressAlert.status == 'suppressed'
    ).count()
    
    if overnight_alerts > 0:
        send_push_notification(
            user_id=user_id,
            title='Sleep Summary',
            body=f'You had {overnight_alerts} stress episodes overnight. Consider booking a check-in.',
            data={'type': 'morning_summary'}
        )
```

---

### 6. 14-Day Stepped Care Rule

**Backend Cron Job** (runs daily):

```python
@celery.task
def check_14day_escalation():
    """Escalate if ≥5 declined/persistent episodes in 14 days"""
    
    fourteen_days_ago = datetime.now() - timedelta(days=14)
    
    users_needing_escalation = db.session.query(
        StressAlert.user_id,
        func.count(StressAlert.id).label('episode_count')
    ).filter(
        StressAlert.triggered_at >= fourteen_days_ago,
        StressAlert.status.in_(['user_declined', 'ignored'])
    ).group_by(
        StressAlert.user_id
    ).having(
        func.count(StressAlert.id) >= 5
    ).all()
    
    for user_id, count in users_needing_escalation:
        # Create escalation record
        escalation = Escalation(
            user_id=user_id,
            escalation_type='14day_stepped_care',
            episode_count=count,
            status='pending_psychologist',
            notes=f'{count} declined/ignored episodes in 14 days'
        )
        db.session.add(escalation)
        
        # Notify psychologist team
        notify_psychologist_team(
            user_id=user_id,
            urgency='high',
            reason=f'14-day rule triggered: {count} episodes'
        )
    
    db.session.commit()
```

---

### 7. Weekly Escalation Check

**Backend Cron Job** (runs weekly on Sunday):

```python
@celery.task
def check_weekly_escalation():
    """Escalate if ≥7 Level 4 events in past 7 days"""
    
    seven_days_ago = datetime.now() - timedelta(days=7)
    
    high_stress_users = db.session.query(
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
    
    for user_id, count in high_stress_users:
        # Escalate to 1-to-1 coaching
        create_coaching_request(
            user_id=user_id,
            urgency='high',
            reason=f'{count} high-stress events in 7 days',
            intervention_type='intensive_coaching'
        )
        
        # Send notification to user
        send_push_notification(
            user_id=user_id,
            title='Care Team Outreach',
            body='Our psychologist will reach out soon for additional support.',
            data={'type': 'psychologist_outreach'}
        )
```

---

### 8. Monthly Engagement Letter

**Backend Cron Job** (runs on 1st of each month):

```python
@celery.task
def send_monthly_reports():
    """Send monthly summary email to all users"""
    
    for user in User.query.filter_by(status='active').all():
        # Calculate stats for last month
        last_month_start = datetime.now().replace(day=1) - timedelta(days=1)
        last_month_start = last_month_start.replace(day=1)
        this_month_start = datetime.now().replace(day=1)
        
        stats = calculate_monthly_stats(
            user.id,
            last_month_start,
            this_month_start
        )
        
        # Generate email
        email_body = f"""
        Dear {user.name},
        
        Here's your monthly wellness summary:
        
        📊 Stress Overview:
        - Average stress level: {stats['avg_stress']}/100
        - High stress episodes: {stats['alert_count']}
        - Interventions completed: {stats['interventions_completed']}
        
        😴 Sleep Quality:
        - Average sleep: {stats['avg_sleep_hours']} hours
        - Sleep efficiency: {stats['sleep_efficiency']}%
        
        🧘 Wellness Activities:
        - Breathing exercises: {stats['breathing_count']}
        - Counselling sessions: {stats['session_count']}
        
        💡 Next Month Tips:
        {generate_personalized_tips(stats)}
        
        Keep up the great work!
        HFC Wellness Team
        """
        
        send_email(user.email, 'Your Monthly Wellness Summary', email_body)
```

---

## POC-Specific Data Collection

### Required Data Points for Analysis

#### 1. Parental Stress (PSI-SF)
```python
class PsiSfAssessment(db.Model):
    id = db.Column(db.BigInteger, primary_key=True)
    user_id = db.Column(db.UUID, db.ForeignKey('users.id'))
    assessment_date = db.Column(db.Date, nullable=False)
    assessment_phase = db.Column(db.String(20))  # baseline, month_2_5, month_5
    
    # Subscale scores
    parental_distress = db.Column(db.Integer)
    parent_child_dysfunction = db.Column(db.Integer)
    difficult_child = db.Column(db.Integer)
    total_score = db.Column(db.Integer)
    percentile = db.Column(db.Integer)
```

**Mobile App**: PSI-SF Questionnaire Screen (36 questions)

```dart
class PsiSfScreen extends StatefulWidget {
  final String phase;  // 'baseline', 'month_2_5', 'month_5'
  
  @override
  _PsiSfScreenState createState() => _PsiSfScreenState();
}
```

#### 2. Child Meltdown Logs
```dart
class MeltdownLogScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Log Meltdown')),
      body: Form(
        child: Column(
          children: [
            TextFormField(
              decoration: InputDecoration(labelText: 'Severity (1-10)'),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Duration (minutes)'),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Triggers'),
              maxLines: 3,
            ),
            ElevatedButton(
              onPressed: () => _submitLog(),
              child: Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### 3. Sleep Efficiency
```python
def calculate_sleep_efficiency(sleep_data):
    """Calculate sleep efficiency percentage"""
    
    total_sleep = (
        sleep_data.deep_sleep_minutes +
        sleep_data.light_sleep_minutes +
        sleep_data.rem_sleep_minutes
    )
    
    time_in_bed = total_sleep + sleep_data.awake_minutes
    
    sleep_efficiency = (total_sleep / time_in_bed) * 100
    
    return round(sleep_efficiency, 2)
```

---

## POC Dashboard Views

### Psychologist Dashboard - Patient Overview

```jsx
// React component: PatientOverview.jsx

function PatientOverview({ userId }) {
  const [patient, setPatient] = useState(null);
  const [stressTrend, setStressTrend] = useState([]);
  const [alerts, setAlerts] = useState([]);
  
  useEffect(() => {
    fetchPatientData();
  }, [userId]);
  
  return (
    <div className="patient-overview">
      <PatientHeader patient={patient} />
      
      <div className="metrics-row">
        <MetricCard
          title="Average Stress (7d)"
          value={patient.avg_stress_7d}
          trend={patient.stress_trend}
        />
        <MetricCard
          title="Sleep Efficiency"
          value={`${patient.sleep_efficiency}%`}
          target="≥ 85%"
        />
        <MetricCard
          title="Active Alerts"
          value={alerts.length}
          color="red"
        />
      </div>
      
      <StressTrendChart data={stressTrend} />
      
      <AlertsList alerts={alerts} />
      
      <SessionScheduler userId={userId} />
    </div>
  );
}
```

---

## Go/No-Go Criteria Implementation

### Automated KPI Tracking

```python
@celery.task
def calculate_poc_kpis():
    """Calculate POC KPIs for Go/No-Go decision"""
    
    # KPI 1: Parental Stress Reduction
    group_a_success = calculate_psi_success_rate('A')
    
    # KPI 2: Behavioral Regulation
    meltdown_reduction = calculate_meltdown_reduction('A', 'C')
    
    # KPI 3: Engagement (30-day retention)
    retention_rate = calculate_retention_rate(days=30)
    
    # KPI 4: NPS Score
    nps_score = calculate_nps()
    
    # Go/No-Go Decision
    go_criteria = {
        'psi_success_rate': group_a_success >= 0.50,  # ≥50%
        'meltdown_reduction': meltdown_reduction >= 0.30,  # ≥30%
        'retention': retention_rate >= 0.50,  # ≥50%
        'nps': nps_score > 20
    }
    
    decision = 'GO' if all(go_criteria.values()) else 'NO-GO'
    
    return {
        'decision': decision,
        'criteria': go_criteria,
        'metrics': {
            'psi_success_rate': group_a_success,
            'meltdown_reduction': meltdown_reduction,
            'retention_rate': retention_rate,
            'nps_score': nps_score
        }
    }
```

---

## Summary: POC-Specific Features to Implement

### Mobile App POC Features:
1. ✅ Baseline calibration progress (Days 1-10)
2. ✅ Breathing guide with haptics
3. ✅ VAS stress rating (1-10 scale)
4. ✅ Counselling booking (≤3 taps)
5. ✅ PSI-SF questionnaire (3 times during study)
6. ✅ Meltdown logging
7. ✅ Morning summary notifications

### Backend POC Features:
1. ✅ Baseline threshold calculation
2. ✅ 30-minute sustained stress detection
3. ✅ Alert suppression during sleep
4. ✅ 14-day stepped care check
5. ✅ Weekly escalation check
6. ✅ Monthly engagement emails
7. ✅ KPI calculation for Go/No-Go

### Web Dashboard POC Features:
1. ✅ Group comparison (A vs B vs C)
2. ✅ PSI-SF score tracking
3. ✅ Meltdown frequency charts
4. ✅ Sleep efficiency trends
5. ✅ Intervention success rates
6. ✅ Escalation queue for psychologists

---

**This guide covers all POC-specific requirements from the Nitto-HFC agreement.**
