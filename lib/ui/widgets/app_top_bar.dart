import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../services/hc20_service.dart';  // NEW: Import HC20Service

/// AppTopBar (formerly CustomAppBar) with logo, app name, subtitle, and device connection status
/// Now reads real-time connection state from HC20Service
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onDeviceIconTap;
  final VoidCallback? onLogoTap;  // NEW: Callback for logo tap to open drawer

  const AppTopBar({
    Key? key,
    this.onDeviceIconTap,
    this.onLogoTap,  // NEW: Accept logo tap callback
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(80.0); // Taller than default

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primaryPurple,
      elevation: 0,
      toolbarHeight: 80.0,
      automaticallyImplyLeading: false,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // White status bar icons
      ),
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // LEFT SECTION: Logo + App Name + Subtitle
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // App Logo (placeholder - replace with actual logo from assets)
                    InkWell(
                      onTap: onLogoTap,  // NEW: Open drawer on tap
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.favorite,
                          color: AppColors.primaryPurple,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // App Name + Subtitle
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // App Name: "HireForCare"
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Hire',
                                  style: TextStyle(color: AppColors.textWhite),
                                ),
                                const TextSpan(
                                  text: 'For',
                                  style: TextStyle(color: Colors.pinkAccent),
                                ),
                                TextSpan(
                                  text: 'Care',
                                  style: TextStyle(color: AppColors.textWhite),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Subtitle
                          Text(
                            'One Stop Special Child Care Solution',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.7), // Light lavender / muted white
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 12),
              
              // RIGHT SECTION: Device Name + Connection Status + Device Icon
              // Now reads from HC20Service (global state)
              Consumer<HC20Service>(
                builder: (context, hc20Service, child) {
                  final deviceName = hc20Service.connectedDevice?.name ?? 'HC20';
                  final isConnected = hc20Service.isConnected;
                  final connectionStatus = hc20Service.getConnectionStatus();
                  
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Device Info Column
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Device Name
                          Text(
                            deviceName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textWhite,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Connection Status
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Status Dot
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isConnected ? Colors.greenAccent : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Status Text
                              Text(
                                connectionStatus,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isConnected 
                                      ? Colors.greenAccent.shade100 
                                      : Colors.grey.shade300,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Device Icon Button
                      InkWell(
                        onTap: onDeviceIconTap,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.watch,
                            color: AppColors.primaryPurple,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
