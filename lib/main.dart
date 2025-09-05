// lib/main.dart - Updated with login check
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'FriendsListPage.dart';
import 'LoginRegisterPage.dart';
import 'dataservice.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase first
  FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
  runApp(MyApp());
}
@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  print('Background message: ${message.messageId}');
  // Handle background message processing here
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

class _SplashScreenState extends State<SplashScreen> {
  String _statusMessage = 'Starting app...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() {
        _statusMessage = 'Initializing...';
      });

      // Check if Firebase is initialized
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      setState(() {
        _statusMessage = 'Checking login status...';
      });

      // Initialize DataService for Firebase Auth
      await DataService()
          .initialize()
          .timeout(
        Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException('Connection timed out. Please try again.');
        },
      )
          .catchError((error) {
        print('DataService error: $error');
        throw Exception('Unable to initialize services: $error');
      });

      // Check if user is already logged in
      bool isLoggedIn = await DataService().isUserLoggedIn();

      setState(() {
        _statusMessage = isLoggedIn ? 'Welcome back!' : 'Please login to continue';
      });

      await Future.delayed(Duration(milliseconds: 1000));

      if (mounted) {
        if (isLoggedIn) {
          // User is logged in, go to main app
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => FriendsListPage()),
          );
        } else {
          // User is not logged in, go to login page
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
        errorMessage =
        'Authentication error. Please check your Firebase configuration.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network connection error';
      }

      setState(() {
        _statusMessage = errorMessage;
      });

      // Show error dialog with more details
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
                  _initializeApp(); // Retry
                },
                child: Text('Retry'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Go to login page even if there's an error
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
      backgroundColor: Colors.blue.shade50,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade400, Colors.blue.shade800],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo
              // Container(
              //   width: 100,
              //   height: 100,
              //   decoration: BoxDecoration(
              //     color: Colors.white,
              //     shape: BoxShape.circle,
              //     boxShadow: [
              //       BoxShadow(
              //         color: Colors.black.withOpacity(0.1),
              //         blurRadius: 20,
              //         offset: Offset(0, 10),
              //       ),
              //     ],
              //   ),
              //   // child: Icon(
              //   //   Icons.account_balance_wallet,
              //   //   size: 50,
              //   //   color: Colors.blue.shade600,
              //   // ),
              // ),

              SizedBox(height: 30),

              Image.asset('assets/frontimg.png', width: 500, height: 300),


              SizedBox(height: 40),

              // Loading indicator
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),

              SizedBox(height: 30),

              // Status message
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9)
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}