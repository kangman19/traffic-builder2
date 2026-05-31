import 'package:flutter/material.dart';
import 'core/network/api_client.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiClient.init();
  await NotificationService.init();
  runApp(const TrafficBuilderApp());
}

class TrafficBuilderApp extends StatelessWidget {
  const TrafficBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Traffic Builder',
      theme: AppTheme.dark,
      home: const DashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
