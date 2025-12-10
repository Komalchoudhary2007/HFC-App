# HFC Backend API Documentation

Base URL: `https://api.hireforcare.com/api/v1`

## Authentication

All endpoints (except `/auth/*`) require Bearer token authentication.

### Headers
```
Authorization: Bearer <token>
Content-Type: application/json
```

---

## 1. Authentication Endpoints

### 1.1 Register User
```
POST /auth/register
```

**Request Body:**
```json
{
  "email": "parent@example.com",
  "password": "SecurePass123",
  "name": "John Doe",
  "phone": "+919876543210",
  "group_type": "A",
  "user_info": {
    "gender": 1,
    "height": 175,
    "weight": 70,
    "age": 35
  }
}
```

**Response (201):**
```json
{
  "success": true,
  "data": {
    "user_id": "uuid-here",
    "email": "parent@example.com",
    "access_token": "eyJhbGc...",
    "refresh_token": "eyJhbGc...",
    "expires_in": 3600
  }
}
```

### 1.2 Login
```
POST /auth/login
```

**Request Body:**
```json
{
  "email": "parent@example.com",
  "password": "SecurePass123"
}
```

**Response (200):**
```json
{
  "success": true,
  "data": {
    "user_id": "uuid-here",
    "access_token": "eyJhbGc...",
    "refresh_token": "eyJhbGc...",
    "expires_in": 3600,
    "baseline_complete": false
  }
}
```

---

## 2. Device Management

### 2.1 Pair Device
```
POST /devices/pair
```

**Request Body:**
```json
{
  "device_mac": "AA:BB:CC:DD:EE:FF",
  "device_name": "HC20-Watch",
  "firmware_version": "1.2.3"
}
```

**Response (201):**
```json
{
  "success": true,
  "data": {
    "device_id": "uuid-here",
    "paired_at": "2024-12-04T10:30:00Z"
  }
}
```

### 2.2 Get My Devices
```
GET /devices/my-devices
```

**Response (200):**
```json
{
  "success": true,
  "data": [
    {
      "device_id": "uuid-here",
      "device_mac": "AA:BB:CC:DD:EE:FF",
      "device_name": "HC20-Watch",
      "status": "active",
      "last_sync": "2024-12-04T10:25:00Z",
      "battery_level": 85
    }
  ]
}
```

---

## 3. Vitals Data Upload

### 3.1 Upload Real-time Vitals (Bulk)
```
POST /vitals/realtime
```

**Request Body:**
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
    },
    {
      "timestamp": "2024-12-04T10:35:00Z",
      "heart_rate": 78,
      "spo2": 97,
      "systolic_bp": 122,
      "diastolic_bp": 82,
      "skin_temp": 36.6,
      "steps": 1320,
      "battery_level": 84
    }
  ]
}
```

**Response (201):**
```json
{
  "success": true,
  "message": "2 readings uploaded successfully",
  "data": {
    "uploaded_count": 2,
    "failed_count": 0
  }
}
```

### 3.2 Upload HRV Data
```
POST /vitals/hrv
```

**Request Body:**
```json
{
  "device_mac": "AA:BB:CC:DD:EE:FF",
  "readings": [
    {
      "timestamp": "2024-12-04T10:30:00Z",
      "sdnn": 45.2,
      "tp": 2500.5,
      "lf": 800.3,
      "hf": 350.2,
      "vlf": 1350.0,
      "lf_hf_ratio": 2.28
    }
  ]
}
```

**Response (201):**
```json
{
  "success": true,
  "message": "HRV data uploaded",
  "data": {
    "uploaded_count": 1,
    "stress_score_calculated": 72,
    "alert_triggered": true,
    "alert_id": "alert-uuid"
  }
}
```

### 3.3 Upload HRV2 Stress Metrics
```
POST /vitals/hrv2
```

**Request Body:**
```json
{
  "device_mac": "AA:BB:CC:DD:EE:FF",
  "readings": [
    {
      "timestamp": "2024-12-04T10:30:00Z",
      "mental_stress": 75,
      "fatigue": 65,
      "stress_resistance": 45,
      "regulation_ability": 50
    }
  ]
}
```

### 3.4 Upload Sleep Data
```
POST /vitals/sleep
```

**Request Body:**
```json
{
  "device_mac": "AA:BB:CC:DD:EE:FF",
  "date": "2024-12-03",
  "total_sleep_minutes": 420,
  "deep_sleep_minutes": 120,
  "light_sleep_minutes": 240,
  "rem_sleep_minutes": 60,
  "awake_minutes": 30,
  "sleep_efficiency": 87.5
}
```

### 3.5 Upload Daily Summary
```
POST /vitals/daily-summary
```

**Request Body:**
```json
{
  "device_mac": "AA:BB:CC:DD:EE:FF",
  "date": "2024-12-04",
  "total_steps": 8500,
  "total_calories": 2200,
  "distance_meters": 6800,
  "active_minutes": 180,
  "silent_minutes": 1260
}
```

---

## 4. Data Retrieval

### 4.1 Get Latest Vitals
```
GET /vitals/latest
```

**Response (200):**
```json
{
  "success": true,
  "data": {
    "timestamp": "2024-12-04T10:30:00Z",
    "heart_rate": 75,
    "spo2": 98,
    "systolic_bp": 120,
    "diastolic_bp": 80,
    "skin_temp": 36.5,
    "steps": 1250,
    "battery_level": 85,
    "stress_score": 72
  }
}
```

### 4.2 Get Historical Data
```
GET /vitals/history?type=heart_rate&start_date=2024-12-01&end_date=2024-12-04&page=1&limit=100
```

**Query Parameters:**
- `type`: heart_rate | spo2 | blood_pressure | hrv | sleep
- `start_date`: ISO date (YYYY-MM-DD)
- `end_date`: ISO date (YYYY-MM-DD)
- `page`: Page number (default: 1)
- `limit`: Records per page (default: 100, max: 1000)

**Response (200):**
```json
{
  "success": true,
  "data": {
    "records": [
      {
        "timestamp": "2024-12-04T10:30:00Z",
        "value": 75
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 100,
      "total_records": 450,
      "total_pages": 5
    }
  }
}
```

---

## 5. Stress Alerts

### 5.1 Get Active Alerts
```
GET /alerts/active
```

**Response (200):**
```json
{
  "success": true,
  "data": [
    {
      "alert_id": "uuid-here",
      "triggered_at": "2024-12-04T10:30:00Z",
      "stress_level": 4,
      "duration_minutes": 35,
      "alert_type": "level_4_sustained",
      "status": "pending",
      "recommended_action": "breathing_exercise",
      "message": "Your stress levels have been elevated for 35 minutes. Take a moment to breathe."
    }
  ]
}
```

### 5.2 Get Alert History
```
GET /alerts/history?page=1&limit=20
```

**Response (200):**
```json
{
  "success": true,
  "data": {
    "alerts": [
      {
        "alert_id": "uuid-here",
        "triggered_at": "2024-12-03T15:20:00Z",
        "stress_level": 4,
        "status": "user_accepted",
        "user_response_at": "2024-12-03T15:22:00Z",
        "breathing_completed": true,
        "vas_rating": 7,
        "counselling_booked": true
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 45
    }
  }
}
```

### 5.3 Respond to Alert
```
POST /alerts/:alert_id/respond
```

**Request Body:**
```json
{
  "action": "accept",
  "vas_rating": 7,
  "notes": "Feeling stressed about child's therapy session"
}
```

**Actions:** `accept` | `decline` | `snooze`

**Response (200):**
```json
{
  "success": true,
  "message": "Response recorded",
  "data": {
    "next_action": "breathing_exercise",
    "redirect_to": "/breathing-guide"
  }
}
```

### 5.4 Mark Breathing Exercise Complete
```
POST /alerts/:alert_id/breathing-complete
```

**Request Body:**
```json
{
  "completed": true,
  "duration_seconds": 180,
  "post_exercise_vas": 5
}
```

**Response (200):**
```json
{
  "success": true,
  "message": "Exercise logged",
  "data": {
    "show_booking_prompt": true
  }
}
```

### 5.5 Book Counselling Session
```
POST /alerts/:alert_id/book-session
```

**Request Body:**
```json
{
  "preferred_time_slots": [
    "2024-12-05T10:00:00Z",
    "2024-12-05T14:00:00Z",
    "2024-12-06T10:00:00Z"
  ],
  "urgency": "high"
}
```

**Response (201):**
```json
{
  "success": true,
  "message": "Session request submitted",
  "data": {
    "request_id": "uuid-here",
    "status": "pending_psychologist_confirmation",
    "estimated_response_time": "within 2 hours"
  }
}
```

---

## 6. Sessions Management

### 6.1 Get Upcoming Sessions
```
GET /sessions/upcoming
```

**Response (200):**
```json
{
  "success": true,
  "data": [
    {
      "session_id": "uuid-here",
      "scheduled_at": "2024-12-05T10:00:00Z",
      "session_type": "counselling_call",
      "psychologist_name": "Dr. Sarah Smith",
      "status": "confirmed",
      "meeting_link": "https://meet.hfc.com/xyz123"
    }
  ]
}
```

### 6.2 Get Session History
```
GET /sessions/history?page=1&limit=10
```

---

## 7. Child Behavior Tracking

### 7.1 Log Meltdown
```
POST /child/meltdown
```

**Request Body:**
```json
{
  "logged_at": "2024-12-04T16:30:00Z",
  "severity": 8,
  "duration_minutes": 25,
  "triggers": ["transition from school", "denied screen time"],
  "notes": "Used calm corner, took 25 min to regulate"
}
```

**Response (201):**
```json
{
  "success": true,
  "data": {
    "log_id": "uuid-here",
    "weekly_count": 3,
    "trend": "decreasing"
  }
}
```

### 7.2 Get Meltdown History
```
GET /child/meltdown-history?start_date=2024-11-01&end_date=2024-12-04
```

**Response (200):**
```json
{
  "success": true,
  "data": {
    "logs": [
      {
        "logged_at": "2024-12-04T16:30:00Z",
        "severity": 8,
        "duration_minutes": 25
      }
    ],
    "statistics": {
      "total_count": 12,
      "average_severity": 6.5,
      "average_duration": 22,
      "weekly_trend": "stable"
    }
  }
}
```

---

## 8. Assessments

### 8.1 Submit PSI-SF Assessment
```
POST /assessments/psi-sf
```

**Request Body:**
```json
{
  "assessment_date": "2024-12-04",
  "assessment_phase": "baseline",
  "responses": {
    "q1": 4,
    "q2": 3,
    "q3": 5,
    // ... all 36 questions
    "q36": 2
  }
}
```

**Response (201):**
```json
{
  "success": true,
  "data": {
    "assessment_id": "uuid-here",
    "total_score": 85,
    "percentile": 78,
    "subscale_scores": {
      "parental_distress": 28,
      "parent_child_dysfunction": 30,
      "difficult_child": 27
    },
    "interpretation": "Clinically significant stress",
    "recommendation": "Immediate psychologist consultation recommended"
  }
}
```

### 8.2 Get Assessment History
```
GET /assessments/history
```

---

## 9. User Profile

### 9.1 Get Profile
```
GET /auth/profile
```

**Response (200):**
```json
{
  "success": true,
  "data": {
    "user_id": "uuid-here",
    "name": "John Doe",
    "email": "parent@example.com",
    "phone": "+919876543210",
    "group_type": "A",
    "enrollment_date": "2024-11-01",
    "baseline_complete": true,
    "baseline_hrv_threshold": 45.2,
    "devices": [
      {
        "device_mac": "AA:BB:CC:DD:EE:FF",
        "status": "active"
      }
    ]
  }
}
```

### 9.2 Update Profile
```
PUT /auth/profile
```

**Request Body:**
```json
{
  "name": "John Doe",
  "phone": "+919876543210",
  "user_info": {
    "height": 175,
    "weight": 72
  }
}
```

---

## 10. Psychologist Dashboard APIs

### 10.1 Get Patient List
```
GET /psychologist/patients?status=active&group=A&page=1&limit=20
```

**Headers:**
```
Authorization: Bearer <psychologist_token>
```

**Response (200):**
```json
{
  "success": true,
  "data": {
    "patients": [
      {
        "user_id": "uuid",
        "name": "John Doe",
        "group_type": "A",
        "enrollment_date": "2024-11-01",
        "active_alerts_count": 2,
        "last_session": "2024-11-28",
        "stress_trend": "increasing",
        "latest_psi_score": 85
      }
    ],
    "pagination": {
      "page": 1,
      "total": 25
    }
  }
}
```

### 10.2 Get Patient Detail
```
GET /psychologist/patients/:user_id
```

**Response (200):**
```json
{
  "success": true,
  "data": {
    "user": {
      "user_id": "uuid",
      "name": "John Doe",
      "group_type": "A"
    },
    "vitals_summary": {
      "avg_stress_7d": 68,
      "avg_heart_rate_7d": 78,
      "sleep_efficiency_7d": 82
    },
    "recent_alerts": [...],
    "upcoming_sessions": [...],
    "psi_scores": [
      {
        "date": "2024-11-01",
        "phase": "baseline",
        "total_score": 92
      }
    ]
  }
}
```

### 10.3 Add Session Notes
```
POST /psychologist/sessions/:session_id/notes
```

**Request Body:**
```json
{
  "notes": "Patient reported improvement in stress management...",
  "interventions_discussed": ["breathing exercises", "time management"],
  "next_steps": "Follow up in 1 week",
  "risk_level": "low"
}
```

---

## Error Responses

All error responses follow this format:

```json
{
  "success": false,
  "error": {
    "code": "INVALID_REQUEST",
    "message": "Missing required field: device_mac",
    "details": {}
  }
}
```

### Common Error Codes
- `INVALID_REQUEST` (400): Malformed request
- `UNAUTHORIZED` (401): Missing/invalid token
- `FORBIDDEN` (403): Insufficient permissions
- `NOT_FOUND` (404): Resource not found
- `CONFLICT` (409): Resource already exists
- `RATE_LIMIT_EXCEEDED` (429): Too many requests
- `INTERNAL_ERROR` (500): Server error

---

## Rate Limiting

- Authentication endpoints: 5 requests/minute
- Data upload endpoints: 100 requests/minute
- Data retrieval endpoints: 200 requests/minute
- Alert endpoints: 50 requests/minute

**Rate limit headers:**
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1638360000
```

---

## Webhooks (Optional)

Configure webhooks to receive real-time notifications:

```
POST /webhooks/configure
```

**Request Body:**
```json
{
  "url": "https://your-server.com/webhook",
  "events": ["alert.created", "session.scheduled"],
  "secret": "your-webhook-secret"
}
```

**Webhook Payload Example:**
```json
{
  "event": "alert.created",
  "timestamp": "2024-12-04T10:30:00Z",
  "data": {
    "alert_id": "uuid",
    "user_id": "uuid",
    "stress_level": 4
  }
}
```
