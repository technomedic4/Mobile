import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/hospital_provider.dart';
import 'screens/app_entry_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => HospitalProvider()..initialize(),
        ),
      ],
      child: const HospitalApp(),
    ),
  );
}

class HospitalApp extends StatelessWidget {
  const HospitalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIMRS Sehat',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF087F8C),
          primary: const Color(0xFF087F8C),
          secondary: const Color(0xFF38A89D),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F8F8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F8F8),
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const AppEntryScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}