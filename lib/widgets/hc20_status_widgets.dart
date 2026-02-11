import 'package:flutter/material.dart';
import 'package:hc20/hc20.dart';

/// ✅ HC20 Status Widgets - Only contains USED widgets
/// - HeroSection (used in main.dart - before device setup)
/// - LowBatteryWarning (used in main.dart)
/// - ManualReconnectButton (used in main.dart)
/// - BatteryOptimizationWarning (used in main.dart)

// ==================== HERO SECTION (No Device Setup) ====================
class HeroSection extends StatefulWidget {
  final VoidCallback onSetupDevice;
  final List<Hc20Device> discoveredDevices;
  final bool isScanning;
  final Function(Hc20Device)? onConnectDevice;
  
  const HeroSection({
    super.key, 
    required this.onSetupDevice,
    this.discoveredDevices = const [],
    this.isScanning = false,
    this.onConnectDevice,
  });

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _floatController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _floatAnimation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF532A7B),
            Color(0xFF7B4BA8),
            Color(0xFF9B6BC8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF532A7B).withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Animated background circles
          Positioned(
            right: -40,
            top: -40,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            right: 60,
            bottom: 40,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          // Main content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Animated watch icon
                AnimatedBuilder(
                  animation: _floatAnimation,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, _floatAnimation.value),
                    child: child,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) => Transform.scale(
                        scale: _pulseAnimation.value * 0.95 + 0.05,
                        child: child,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.watch_rounded,
                            color: Colors.white,
                            size: 64,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.favorite_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                const Text(
                  'HC20 Health Monitor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    fontFamily: 'poppins',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your Personal Wellness Companion',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'poppins',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Feature chips
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFeatureChip(Icons.monitor_heart_outlined, 'Heart Rate'),
                    _buildFeatureChip(Icons.psychology_outlined, 'Stress'),
                    _buildFeatureChip(Icons.bloodtype_outlined, 'SpO2'),
                    _buildFeatureChip(Icons.thermostat_outlined, 'Temp'),
                    _buildFeatureChip(Icons.speed_outlined, 'BP'),
                    _buildFeatureChip(Icons.bedtime_outlined, 'Sleep'),
                  ],
                ),
                const SizedBox(height: 24),
                // Info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          color: Colors.white.withOpacity(0.9),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Get Started',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'poppins',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Connect your HC20 wearable to start tracking your health metrics in real-time.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                                height: 1.4,
                                fontFamily: 'poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Setup button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.isScanning ? null : widget.onSetupDevice,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: widget.isScanning ? Colors.white.withOpacity(0.7) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.isScanning) ...[
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF532A7B)),
                              ),
                            ),
                          ] else ...[
                            const Icon(
                              Icons.bluetooth_searching_rounded,
                              color: Color(0xFF532A7B),
                              size: 24,
                            ),
                          ],
                          const SizedBox(width: 12),
                          Text(
                            widget.isScanning ? 'Scanning...' : 'Connect HC20 Device',
                            style: const TextStyle(
                              color: Color(0xFF532A7B),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              fontFamily: 'poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Discovered Devices Section (inside hero)
                if (widget.discoveredDevices.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.devices_rounded,
                                  color: Color(0xFF4CAF50),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Found ${widget.discoveredDevices.length} Device${widget.discoveredDevices.length > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'poppins',
                                ),
                              ),
                              const Spacer(),
                              if (widget.isScanning)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Device list
                        ...widget.discoveredDevices.map((device) => _buildDeviceItem(device)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(Hc20Device device) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onConnectDevice?.call(device),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.watch_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'poppins',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.id,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Connect',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'poppins',
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== LOW BATTERY WARNING ====================
class LowBatteryWarning extends StatelessWidget {
  final int batteryLevel;
  const LowBatteryWarning({super.key, required this.batteryLevel});

  @override
  Widget build(BuildContext context) {
    if (batteryLevel >= 20) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade300, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(Icons.battery_alert, color: Colors.red.shade700, size: 32),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Low Battery Warning', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
          const SizedBox(height: 4),
          Text('HC20 battery is at $batteryLevel%. Please charge your device soon.', style: TextStyle(fontSize: 14, color: Colors.red.shade700)),
        ])),
      ]),
    );
  }
}

// ==================== MANUAL RECONNECT BUTTON ====================
class ManualReconnectButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isReconnecting;
  final int? minutesUntilAutoReconnect;
  const ManualReconnectButton({super.key, required this.onPressed, this.isReconnecting = false, this.minutesUntilAutoReconnect});

  String _getInfoText() {
    if (minutesUntilAutoReconnect != null && minutesUntilAutoReconnect! > 0) {
      return 'Auto-reconnect in $minutesUntilAutoReconnect min. Tap below to manually reconnect. If taking too long, close and reopen the app.';
    }
    return 'Auto-reconnect soon. Tap below to manually reconnect. If taking too long, close and reopen the app.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade700,
            Colors.grey.shade600,
            Colors.grey.shade500,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade700.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.grey.shade700.withOpacity(0.2),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern circles
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            left: -15,
            bottom: -15,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            right: 50,
            bottom: -25,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Animated disconnected icon
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.orange.shade300.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.bluetooth_disabled_rounded,
                        color: Colors.orange.shade300,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Device Offline',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade400.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, color: Colors.white, size: 8),
                                    SizedBox(width: 5),
                                    Text(
                                      'OFFLINE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'HC20 connection lost',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Info box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.white.withOpacity(0.7),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _getInfoText(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Reconnect button with purple accent
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isReconnecting ? null : onPressed,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isReconnecting
                              ? [Colors.grey.shade400, Colors.grey.shade300]
                              : [const Color(0xFF532A7B), const Color(0xFF7B4BA8)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: isReconnecting
                            ? []
                            : [
                                BoxShadow(
                                  color: const Color(0xFF532A7B).withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isReconnecting) ...[
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ),
                          ] else ...[
                            const Icon(
                              Icons.sync_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ],
                          const SizedBox(width: 10),
                          Text(
                            isReconnecting ? 'Searching for device...' : 'Reconnect Now',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== BATTERY OPTIMIZATION WARNING ====================
class BatteryOptimizationWarning extends StatelessWidget {
  final VoidCallback onDisable;
  final bool isDisabled;
  const BatteryOptimizationWarning({super.key, required this.onDisable, required this.isDisabled});

  @override
  Widget build(BuildContext context) {
    if (isDisabled) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade300, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.battery_alert, color: Colors.orange.shade700, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Text('Battery Optimization Enabled', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange.shade700))),
        ]),
        const SizedBox(height: 8),
        Text('This app needs unrestricted battery access to work properly in background.', style: TextStyle(fontSize: 14, color: Colors.orange.shade700)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onDisable,
            icon: const Icon(Icons.battery_charging_full),
            label: const Text('Disable Battery Optimization'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ==================== ACCOUNT & DEVICE SECTION ====================
class AccountDeviceSection extends StatelessWidget {
  final String accountName;
  final String deviceName;
  final String? deviceId;
  final bool isLinked;
  final VoidCallback? onAccountTap;
  final VoidCallback? onDeviceTap;
  final VoidCallback? onLinkedTap;

  const AccountDeviceSection({
    super.key,
    required this.accountName,
    this.deviceName = 'HC20 Wearable',
    this.deviceId,
    this.isLinked = false,
    this.onAccountTap,
    this.onDeviceTap,
    this.onLinkedTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with gradient
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade50, Colors.purple.shade100.withOpacity(0.5)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.devices_rounded, color: Colors.purple.shade700, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  'Account & Device',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade900,
                  ),
                ),
                const Spacer(),
                // Link status badge in header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isLinked ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLinked ? Colors.green.shade200 : Colors.orange.shade200,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLinked ? Icons.link_rounded : Icons.link_off_rounded,
                        size: 12,
                        color: isLinked ? Colors.green.shade600 : Colors.orange.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isLinked ? 'Linked' : 'Not Linked',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isLinked ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content rows
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Account row
                _buildInfoRow(
                  icon: Icons.person_rounded,
                  iconBgColor: Colors.purple.shade50,
                  iconColor: Colors.purple.shade600,
                  label: 'Account',
                  value: accountName,
                ),
                const SizedBox(height: 10),
                // Device row
                _buildInfoRow(
                  icon: Icons.watch_rounded,
                  iconBgColor: Colors.blue.shade50,
                  iconColor: Colors.blue.shade600,
                  label: 'Device',
                  value: deviceName,
                ),
                if (deviceId != null) ...[
                  const SizedBox(height: 10),
                  // Device ID row
                  _buildInfoRow(
                    icon: Icons.qr_code_2_rounded,
                    iconBgColor: Colors.grey.shade100,
                    iconColor: Colors.grey.shade600,
                    label: 'Device ID',
                    value: deviceId!,
                    isMonospace: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String label,
    required String value,
    bool isMonospace = false,
  }) {
    return Row(
      children: [
        // Icon badge
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 14),
        ),
        const SizedBox(width: 10),
        // Label
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(width: 8),
        // Value
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
              fontFamily: isMonospace ? 'monospace' : null,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
