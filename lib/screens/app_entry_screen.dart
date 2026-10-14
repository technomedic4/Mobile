import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/hospital_provider.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class AppEntryScreen extends StatelessWidget {
  const AppEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hospital = context.watch<HospitalProvider>();
    if (!hospital.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (hospital.isLoggedIn) return const PatientPortalScreen();
    return const LoginScreen();
  }
}
