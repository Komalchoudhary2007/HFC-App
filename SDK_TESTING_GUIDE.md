# HC20 SDK Testing Guide
# =======================
# 
# This file shows how to safely switch between old and new SDK for testing

# OPTION 1: Use OLD STABLE SDK (hc20 v1.0.0) - CURRENT DEFAULT
# ============================================================
# dependencies:
#   flutter:
#     sdk: flutter
#   hc20:
#     path: ./hc20

# OPTION 2: Use NEW SDK (hc20_new v1.0.2) - FOR TESTING
# ======================================================
# dependencies:
#   flutter:
#     sdk: flutter
#   hc20:
#     path: ./hc20_new

# HOW TO SWITCH:
# ==============
# 1. Edit pubspec.yaml
# 2. Change the path from './hc20' to './hc20_new' (or vice versa)
# 3. Run: flutter pub get
# 4. Run: flutter clean (recommended)
# 5. Run: flutter run
# 6. Test all features thoroughly

# WHAT TO TEST:
# =============
# ✓ Device scanning and connection
# ✓ Real-time data updates (HR, SpO2, BP, Temp)
# ✓ Historical data retrieval
# ✓ Webhook data transmission
# ✓ Background sync (new SDK enables automatically)
# ✓ Sensor enabling/disabling
# ✓ Battery status
# ✓ Steps counting
# ✓ Time synchronization
# ✓ Device disconnect/reconnect handling

# NEW SDK SPECIFIC FEATURES TO TEST:
# ===================================
# ✓ Auto-enable sensors on connection (should happen automatically)
# ✓ Auto-enable background sync (should start automatically)
# ✓ Raw sensor data upload (should work automatically)
# ✓ Improved historical data retrieval (sensors auto-disable/enable)

# ROLLBACK IF ISSUES:
# ===================
# If new SDK causes problems:
# 1. Edit pubspec.yaml back to './hc20'
# 2. Run: flutter pub get
# 3. Run: flutter clean
# 4. Run: flutter run
# Your old stable version will be restored!
