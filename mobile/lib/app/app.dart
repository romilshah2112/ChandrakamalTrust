import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/app/router.dart';
import 'package:optima_healthcare_mobile/app/theme.dart';

class OptimaHealthcareApp extends StatelessWidget {
  const OptimaHealthcareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chandrakamal Memorial Trust',
      theme: AppTheme.light,
      initialRoute: AppRouter.splash,
      routes: AppRouter.routes,
      debugShowCheckedModeBanner: false,
    );
  }
}
