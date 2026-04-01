// Web placeholder for check-in page — native features not available
import 'package:flutter/material.dart';

class CheckInOutPage extends StatelessWidget {
  const CheckInOutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check In / Out')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.phone_android_rounded, size: 64, color: Colors.blue.shade300),
              const SizedBox(height: 20),
              const Text(
                'Clock In/Out requires the mobile app',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Geofence verification and face recognition are only available on Android/iOS.\n\nPlease use the SmartBayu mobile app to clock in.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
