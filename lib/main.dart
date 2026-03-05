import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'welcome_page.dart';
import 'attendance_screen.dart';
import 'login_screen.dart';
import 'branch_semester_selection_screen.dart';
import 'view_saved_files_screen.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize time zone data
  tz.initializeTimeZones();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@drawable/attendance_bg');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      if (response.payload != null) {
        _navigateToScreen(response.payload!);
      }
    },
  );

  // Request exact alarm permissions
  await _requestExactAlarmPermission();

  // Configure Firebase Messaging for background messages
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(AttendanceApp(flutterLocalNotificationsPlugin: flutterLocalNotificationsPlugin));
}

// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}

// Navigation function based on payload
void _navigateToScreen(String payload) {
  GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  switch (payload) {
    case 'attendance_screen':
      navigatorKey.currentState?.pushNamed('/home');
      break;
    case 'branch_semester_selection_screen':
      navigatorKey.currentState?.pushNamed('/branch_semester_selection_screen');
      break;
  // Add more cases for different screens if needed
    default:
      navigatorKey.currentState?.pushNamed('/home'); // Default navigation
      break;
  }
}

// Request exact alarm permission
Future<void> _requestExactAlarmPermission() async {
  final status = await Permission.manageExternalStorage.request();
  if (status.isDenied) {
    // Handle the case when permission is denied
    print('Exact alarm permission is denied');
  } else if (status.isGranted) {
    // Permission granted, proceed with scheduling notifications
    print('Exact alarm permission is granted');
  }
}

class AttendanceApp extends StatelessWidget {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  AttendanceApp({super.key, required this.flutterLocalNotificationsPlugin});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GEC Madhubani',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const WelcomePage(),
      routes: {
        '/branch_semester_selection_screen': (context) => BranchSemesterSelectionScreen(),
        '/login_screen': (context) => const LoginScreen(),
        '/home': (context) => const AttendanceScreen(),
        '/view_saved_files_screen': (context) => const ViewSavedFilesScreen(),
      },
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // Assign the navigator key to the MaterialApp
    );
  }
}
