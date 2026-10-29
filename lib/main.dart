import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'database_helper.dart';
import 'notification_service.dart';
import 'screens/customer_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper().db;
  await NotificationService().init();
  await Permission.camera.request();
  runApp(const CarteraApp());
}

class CarteraApp extends StatelessWidget {
  const CarteraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cartera Eliana',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6A1B9A)),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const CustomerListScreen(),
    );
  }
}
