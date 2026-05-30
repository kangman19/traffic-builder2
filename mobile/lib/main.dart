import 'package:flutter/material.dart';
import 'core/network/api_client.dart';
import 'services/notification_service.dart';
import 'screens/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // AppConfig values are compile-time constants — no file loading needed.
  // Pass overrides at build time: flutter run --dart-define=BACKEND_BASE_URL=...
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E40AF)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E40AF),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const DashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
