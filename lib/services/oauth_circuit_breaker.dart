import 'dart:async';

/// Circuit states for OAuth circuit breaker
enum CircuitState { closed, open, halfOpen }

/// Circuit breaker for OAuth authentication failures
/// Prevents app from hanging when OAuth server returns 500 errors
/// Ticket #3: Prevent 30-50s hangs on OAuth 500 errors
class OAuthCircuitBreaker {
  static final OAuthCircuitBreaker _instance = OAuthCircuitBreaker._internal();
  factory OAuthCircuitBreaker() => _instance;
  OAuthCircuitBreaker._internal();
  
  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  DateTime? _circuitOpenedTime;
  Timer? _resetTimer;
  
  /// Configuration
  static const int maxFailures = 3;
  static const Duration resetTimeout = Duration(minutes: 5);
  static const Duration failureWindow = Duration(minutes: 2);
  
  /// Get current circuit state (for debugging)
  CircuitState get state => _state;
  
  /// Check if OAuth requests should be attempted
  bool get shouldAttemptAuth {
    if (_state == CircuitState.open) {
      // Check if it's time to try again (half-open)
      if (_circuitOpenedTime != null) {
        final elapsed = DateTime.now().difference(_circuitOpenedTime!);
        if (elapsed >= resetTimeout) {
          print('🔄 [OAuthCircuitBreaker] Timeout elapsed - entering half-open state');
          _state = CircuitState.halfOpen;
          return true;
        }
      }
      return false; // Circuit still open
    }
    
    return true; // Closed or half-open - allow attempt
  }
  
  /// Record successful OAuth authentication
  void recordSuccess() {
    if (_state != CircuitState.closed) {
      print('✅ [OAuthCircuitBreaker] Success - closing circuit');
    }
    
    _state = CircuitState.closed;
    _failureCount = 0;
    _lastFailureTime = null;
    _circuitOpenedTime = null;
    _resetTimer?.cancel();
  }
  
  /// Record failed OAuth authentication
  void recordFailure(String error) {
    final now = DateTime.now();
    
    // Check if failure is within window
    if (_lastFailureTime != null) {
      final elapsed = now.difference(_lastFailureTime!);
      if (elapsed > failureWindow) {
        // Old failure - reset count
        print('ℹ️ [OAuthCircuitBreaker] Failure outside window - resetting count');
        _failureCount = 0;
      }
    }
    
    _failureCount++;
    _lastFailureTime = now;
    
    print('⚠️ [OAuthCircuitBreaker] Failure #$_failureCount: $error');
    
    // Open circuit if max failures reached
    if (_failureCount >= maxFailures && _state != CircuitState.open) {
      _openCircuit();
    }
  }
  
  /// Open the circuit (stop attempting OAuth)
  void _openCircuit() {
    print('🔴 [OAuthCircuitBreaker] CIRCUIT OPENED - OAuth disabled for ${resetTimeout.inMinutes}min');
    print('   Reason: $maxFailures failures in ${failureWindow.inMinutes}min');
    print('   App will operate in degraded mode (no OAuth-dependent features)');
    
    _state = CircuitState.open;
    _circuitOpenedTime = DateTime.now();
    
    // Schedule automatic reset
    _resetTimer?.cancel();
    _resetTimer = Timer(resetTimeout, () {
      print('⏰ [OAuthCircuitBreaker] Auto-reset timer fired');
      _state = CircuitState.halfOpen;
    });
  }
  
  /// Get circuit status
  Map<String, dynamic> getStatus() {
    return {
      'state': _state.toString(),
      'failures': _failureCount,
      'lastFailure': _lastFailureTime?.toIso8601String(),
      'circuitOpened': _circuitOpenedTime?.toIso8601String(),
      'canAttempt': shouldAttemptAuth,
    };
  }
  
  /// Reset circuit manually (for testing or admin action)
  void reset() {
    print('🔄 [OAuthCircuitBreaker] Manual reset');
    _state = CircuitState.closed;
    _failureCount = 0;
    _lastFailureTime = null;
    _circuitOpenedTime = null;
    _resetTimer?.cancel();
  }
}
