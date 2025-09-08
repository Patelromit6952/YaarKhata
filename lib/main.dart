import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'FriendsListPage.dart';
import 'LoginRegisterPage.dart';
import 'dataservice.dart';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/models.dart'; // your Friend & Transaction models
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Firebase
  await Firebase.initializeApp();

  // ✅ Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(FriendAdapter());
  Hive.registerAdapter(TransactionAdapter());

  await Hive.openBox<Friend>('friends');
  await Hive.openBox<Transaction>('transactions');

  await DataService().initHive();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Setup FCM foreground message handler
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    showLocalNotification(message);
  });

  runApp(MyApp());
}

void setupFCM() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request permission
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  print('User granted permission: ${settings.authorizationStatus}');

  // Get FCM token
  String? token = await messaging.getToken();
  print("📱 FCM Token: $token");
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("📩 Foreground message: ${message.notification?.title} - ${message.notification?.body}");
  });
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Friends Transaction App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: SplashScreen(),
    );
  }
}


class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  String _statusMessage = 'Starting app...';
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    setupFCM();

    // Initialize animation controller with 2-second duration
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 3000), // Matches desired 2-second display
    );

    // Scale animation for logo
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Fade animation for text
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );

    _animationController.forward();
    _initializeApp();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() {
        _statusMessage = 'Checking login status...';
      });

      // Run login check and enforce minimum 2-second display
      final loginCheckFuture = DataService().isUserLoggedIn();
      final delayFuture = Future.delayed(Duration(seconds: 2)); // Minimum 2 seconds

      // Wait for both login check and minimum delay
      final bool isLoggedIn = await loginCheckFuture;

      setState(() {
        _statusMessage = isLoggedIn ? 'Welcome back!' : 'Please login to continue';
      });

      // Ensure animation and minimum display time are complete
      await delayFuture;

      if (isLoggedIn) {
        // Perform sync in the background
        DataService().syncDataToLocal().catchError((e) {
          print('Background sync error: $e');
        });
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => FriendsListPage()),
          );
        }
      } else {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginRegisterPage()),
          );
        }
      }
    } catch (e) {
      print('Error initializing app: $e');
      String errorMessage = 'Connection error';

      if (e.toString().contains('firebase_auth/unknown')) {
        errorMessage = 'Authentication error. Please check your Firebase configuration.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network connection error';
      }

      setState(() {
        _statusMessage = errorMessage;
      });

      // Ensure minimum 2-second display even in error case
      await Future.delayed(Duration(seconds: 2));

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text('Connection Error'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 16),
                Text(errorMessage),
                SizedBox(height: 16),
                Text('Troubleshooting steps:'),
                SizedBox(height: 8),
                Text('1. Check internet connection'),
                Text('2. Verify Firebase configuration'),
                Text('3. Restart the app'),
                if (e.toString().contains('firebase_auth'))
                  Text('4. Check Firebase Console setup'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _initializeApp();
                },
                child: Text('Retry'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => LoginRegisterPage()),
                  );
                },
                child: Text('Continue Offline'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade300,
              Colors.blue.shade700,
              Colors.blue.shade900,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Icon(Icons.account_balance_wallet, color: Colors.blue, size: 70),
                  ),
                ),
              ),
              SizedBox(height: 40),

              // App Title
              Text(
                'Friends Transaction',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.black26,
                      offset: Offset(2.0, 2.0),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // Loading indicator with animation
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
                backgroundColor: Colors.white.withOpacity(0.2),
              ),
              SizedBox(height: 30),

              // Status message with fade animation
              FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(
                          blurRadius: 5.0,
                          color: Colors.black26,
                          offset: Offset(1.0, 1.0),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Background message: ${message.messageId}');
}
Future<void> showLocalNotification(RemoteMessage message) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'default_channel', // channel id
    'Default',         // channel name
    channelDescription: 'Default channel for notifications',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
  );

  const NotificationDetails platformDetails =
  NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    0, // notification id
    message.notification?.title ?? 'Notification',
    message.notification?.body ?? '',
    platformDetails,
  );
}
