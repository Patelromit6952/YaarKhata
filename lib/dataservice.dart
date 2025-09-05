// lib/dataservice.dart - Updated with Firebase Cloud Functions FCM integration
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/models.dart';

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserPhone;

  String get currentUserId => _currentUserId ?? 'anonymous';
  String get currentUserName => _currentUserName ?? 'You';
  String get currentUserPhone => _currentUserPhone ?? '';

  // Initialize FCM and local notifications
  Future<void> initializeNotifications() async {
    try {
      // Request permissions
      await _requestNotificationPermissions();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Configure FCM
      await _configureFCM();

      // Save FCM token to user profile
      await _saveFCMTokenToProfile();

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen(_onTokenRefresh);

      print('Notifications initialized successfully');
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  Future<void> _requestNotificationPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('Notification permission status: ${settings.authorizationStatus}');
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels
    await _createNotificationChannels();
  }

  Future<void> _createNotificationChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
    _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    const AndroidNotificationChannel transactionChannel = AndroidNotificationChannel(
      'transaction_channel',
      'Transaction Notifications',
      description: 'Notifications for new transactions and payments',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await androidImplementation?.createNotificationChannel(transactionChannel);
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');

    if (response.payload != null) {
      try {
        Map<String, dynamic> data = json.decode(response.payload!);

        if (data['type'] == 'transaction') {
          // Handle transaction notification tap
          // You can navigate to specific screen here
          print('Transaction notification tapped: ${data['description']}');
        }
      } catch (e) {
        print('Error parsing notification payload: $e');
      }
    }
  }

  Future<void> _configureFCM() async {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

    // Handle notification opened app
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Handle initial message (app opened from terminated state)
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Foreground message: ${message.messageId}');

    // Show local notification when app is in foreground
    await _showLocalNotification(message);
  }

  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    print('Message opened app: ${message.messageId}');
    // Handle navigation based on message data
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'transaction_channel',
      'Transaction Notifications',
      channelDescription: 'Notifications for transactions',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(10),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New Transaction',
      message.notification?.body ?? '',
      platformDetails,
      payload: json.encode(message.data),
    );
  }

  Future<void> _saveFCMTokenToProfile() async {
    if (_currentUserId == null) return;

    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(currentUserId).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print('FCM token saved: $token');
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  void _onTokenRefresh(String newToken) async {
    if (_currentUserId != null) {
      await _firestore.collection('users').doc(currentUserId).update({
        'fcmToken': newToken,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
      print('FCM token refreshed: $newToken');
    }
  }

  // Send notification using Cloud Functions
  Future<bool> _sendNotificationToUser({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // Call the Cloud Function
      final HttpsCallable callable = _functions.httpsCallable('sendNotification');

      final result = await callable.call({
        'fcmToken': fcmToken,
        'title': title,
        'body': body,
        'data': data ?? {},
      });

      // Check if the notification was sent successfully
      if (result.data['success'] == true) {
        print('Notification sent successfully via Cloud Functions');
        return true;
      } else {
        print('Failed to send notification: ${result.data['error']}');
        return false;
      }
    } catch (e) {
      print('Error calling Cloud Function for notification: $e');
      return false;
    }
  }

  // Alternative method using HTTP request to Cloud Functions
  Future<bool> _sendNotificationViaHTTP({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // Replace with your actual Cloud Functions URL
      const String cloudFunctionUrl = 'https://us-central1-friendsbook-2e205.cloudfunctions.net/sendNotification';

      final Map<String, dynamic> requestBody = {
        'data': {
          'fcmToken': fcmToken,
          'title': title,
          'body': body,
          'data': data ?? {},
        }
      };

      final response = await http.post(
        Uri.parse(cloudFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['result']['success'] == true) {
          print('Notification sent successfully via HTTP');
          return true;
        } else {
          print('Failed to send notification: ${responseData['result']['error']}');
          return false;
        }
      } else {
        print('HTTP request failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error sending notification via HTTP: $e');
      return false;
    }
  }

  // Send transaction notification to friend using Cloud Functions
  Future<void> _sendTransactionNotification({
    required String friendId,
    required String transactionType,
    required String description,
    required double amount,
  }) async {
    try {
      // Get friend's FCM token
      String? friendFcmToken = await _getFriendFcmToken(friendId);

      if (friendFcmToken == null || friendFcmToken.isEmpty) {
        print('Friend FCM token not found for: $friendId');
        return;
      }

      String title;
      String body;

      if (transactionType == 'expense') {
        title = 'New Expense Added';
        body = '$currentUserName added an expense: $description ₹${amount.toStringAsFixed(2)}';
      } else {
        title = 'Payment Recorded';
        body = '$currentUserName recorded a payment: $description ₹${amount.toStringAsFixed(2)}';
      }

      // Use Cloud Functions to send notification
      await _sendNotificationToUser(
        fcmToken: friendFcmToken,
        title: title,
        body: body,
        data: {
          'type': 'transaction',
          'transaction_type': transactionType,
          'amount': amount.toString(),
          'description': description,
          'sender_id': currentUserId,
          'sender_name': currentUserName,
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
    } catch (e) {
      print('Error sending transaction notification: $e');
    }
  }

  // Method to send general notification using Cloud Functions
  Future<bool> sendCustomNotification({
    required String friendId,
    required String title,
    required String body,
    Map<String, String>? customData,
  }) async {
    try {
      String? friendFcmToken = await _getFriendFcmToken(friendId);

      if (friendFcmToken == null || friendFcmToken.isEmpty) {
        print('Friend FCM token not found for: $friendId');
        return false;
      }

      return await _sendNotificationToUser(
        fcmToken: friendFcmToken,
        title: title,
        body: body,
        data: customData ?? {},
      );
    } catch (e) {
      print('Error sending custom notification: $e');
      return false;
    }
  }

  // Method to send notification to multiple users
  Future<void> sendNotificationToMultipleUsers({
    required List<String> friendIds,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    for (String friendId in friendIds) {
      await Future.delayed(Duration(milliseconds: 100)); // Small delay to avoid rate limiting

      String? friendFcmToken = await _getFriendFcmToken(friendId);

      if (friendFcmToken != null && friendFcmToken.isNotEmpty) {
        await _sendNotificationToUser(
          fcmToken: friendFcmToken,
          title: title,
          body: body,
          data: data,
        );
      }
    }
  }

  // Get friend's FCM token
  Future<String?> _getFriendFcmToken(String friendId) async {
    try {
      // First, check if friend is a registered user
      DocumentSnapshot friendDoc = await _firestore
          .collection('users')
          .doc(friendId)
          .get();

      if (friendDoc.exists) {
        Map<String, dynamic> friendData = friendDoc.data() as Map<String, dynamic>;
        return friendData['fcmToken'] as String?;
      }

      return null;
    } catch (e) {
      print('Error getting friend FCM token: $e');
      return null;
    }
  }

  // Check if user is already logged in
  Future<bool> isUserLoggedIn() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');
      String? userName = prefs.getString('user_name');
      String? userPhone = prefs.getString('user_phone');

      if (userId != null && userName != null && userPhone != null) {
        _currentUserId = userId;
        _currentUserName = userName;
        _currentUserPhone = userPhone;

        // Verify user still exists in database
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          // Update last active and initialize notifications
          await _firestore.collection('users').doc(userId).update({
            'lastActive': FieldValue.serverTimestamp(),
          });

          // Initialize notifications after login
          await initializeNotifications();

          return true;
        } else {
          // User doesn't exist in database, clear local data
          await _clearUserData();
          return false;
        }
      }
      return false;
    } catch (e) {
      print('Error checking login status: $e');
      return false;
    }
  }

  // Register new user
  Future<void> registerUser(String name, String phone) async {
    try {
      // Check if phone number already exists
      QuerySnapshot existingUsers = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (existingUsers.docs.isNotEmpty) {
        throw Exception('Phone number already registered. Please login instead.');
      }

      // Generate unique user ID
      String userId = _generateUserId(phone);

      // Get FCM token
      String? fcmToken = await _firebaseMessaging.getToken();

      // Create user document
      await _firestore.collection('users').doc(userId).set({
        'name': name,
        'phone': phone,
        'avatar': _getRandomAvatar(),
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
        'status': 'active',
        'fcmToken': fcmToken,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });

      // Save user data locally
      await _saveUserData(userId, name, phone);

      _currentUserId = userId;
      _currentUserName = name;
      _currentUserPhone = phone;

      // Initialize notifications for new user
      await initializeNotifications();

    } catch (e) {
      print('Registration error: $e');
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  // Login existing user
  Future<bool> loginUser(String phone) async {
    try {
      // Find user by phone number
      QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        return false; // User not found
      }

      DocumentSnapshot userDoc = userQuery.docs.first;
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      String userId = userDoc.id;
      String userName = userData['name'] ?? 'User';

      // Update last active and FCM token
      String? fcmToken = await _firebaseMessaging.getToken();
      await _firestore.collection('users').doc(userId).update({
        'lastActive': FieldValue.serverTimestamp(),
        'fcmToken': fcmToken,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });

      // Save user data locally
      await _saveUserData(userId, userName, phone);

      _currentUserId = userId;
      _currentUserName = userName;
      _currentUserPhone = phone;

      // Initialize notifications after login
      await initializeNotifications();

      return true;
    } catch (e) {
      print('Login error: $e');
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  // Initialize Firebase Auth (for backward compatibility)
  Future<void> initialize() async {
    try {
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously().timeout(
          Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Authentication timed out');
          },
        );
      }
    } catch (e) {
      print('DataService initialization error: $e');
      throw Exception('Failed to initialize DataService: $e');
    }
  }

  // Logout user
  Future<void> logoutUser() async {
    try {
      await _clearUserData();
      _currentUserId = null;
      _currentUserName = null;
      _currentUserPhone = null;
    } catch (e) {
      print('Logout error: $e');
      throw Exception('Logout failed: ${e.toString()}');
    }
  }

  // Save user data to local storage
  Future<void> _saveUserData(String userId, String name, String phone) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('user_name', name);
    await prefs.setString('user_phone', phone);
  }

  // Clear user data from local storage
  Future<void> _clearUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_phone');
  }

  // Generate unique user ID based on phone
  String _generateUserId(String phone) {
    return 'user_$phone';
  }

  // Get random avatar
  String _getRandomAvatar() {
    List<String> avatars = [
      '👤', '🧑‍💼', '👩‍💼', '🧑‍🎓', '👩‍🎓', '🧑‍💻', '👩‍💻',
      '🧑‍🔬', '👩‍🔬', '🧑‍🎨', '👩‍🎨', '🧑‍🍳', '👩‍🍳', '🧑‍⚕️', '👩‍⚕️'
    ];
    return avatars[DateTime.now().millisecond % avatars.length];
  }

  // Get friends list as a real-time stream
  Stream<List<Friend>> getFriendsStream() {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .snapshots()
        .asyncMap((snapshot) async {
      List<Friend> friends = [];

      for (var doc in snapshot.docs) {
        final friendData = doc.data();
        final friendId = doc.id;

        // Calculate real-time balance for each friend
        final balance = await _calculateBalance(friendId);

        friends.add(
          Friend(
            id: friendId,
            name: friendData['name'] ?? 'Unknown',
            avatar: friendData['avatar'] ?? '👤',
            balance: balance,
          ),
        );
      }

      return friends;
    });
  }

  // Get transactions for a specific friend as real-time stream
  Stream<List<Transaction>> getTransactionsStream(String friendId) {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    final conversationId = _getConversationId(currentUserId, friendId);

    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('transactions')
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Transaction(
          id: doc.id,
          description: data['description'] ?? '',
          amount: (data['amount'] ?? 0).toDouble(),
          paidBy: data['paidBy'] ?? '',
          date: (data['date'] as Timestamp).toDate(),
          type: data['type'] ?? 'expense',
        );
      }).toList();
    });
  }

  // Add a new transaction with notification via Cloud Functions
  Future<void> addTransaction(String friendId, Transaction transaction) async {
    if (_currentUserId == null) {
      throw Exception('User not logged in');
    }

    final conversationId = _getConversationId(currentUserId, friendId);

    // Add transaction to database
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('transactions')
        .add({
      'description': transaction.description,
      'amount': transaction.amount,
      'paidBy': transaction.paidBy,
      'date': Timestamp.fromDate(transaction.date),
      'type': transaction.type,
      'createdBy': currentUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update conversation metadata
    await _firestore.collection('conversations').doc(conversationId).set({
      'participants': [currentUserId, friendId],
      'lastActivity': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Send notification to friend using Cloud Functions
    await _sendTransactionNotification(
      friendId: friendId,
      transactionType: transaction.type,
      description: transaction.description,
      amount: transaction.amount,
    );
  }

  // Add a new friend
  Future<void> addFriend(String friendPhone, String name, String avatar) async {
    if (_currentUserId == null) {
      throw Exception('User not logged in');
    }

    // Generate friend ID from phone
    String friendId = _generateUserId(friendPhone);

    // Check if friend exists in users collection
    DocumentSnapshot friendDoc = await _firestore
        .collection('users')
        .doc(friendId)
        .get();

    String friendName = name;
    String friendAvatar = avatar;

    if (friendDoc.exists) {
      // Friend is a registered user, use their data
      Map<String, dynamic> friendData = friendDoc.data() as Map<String, dynamic>;
      friendName = friendData['name'] ?? name;
      friendAvatar = friendData['avatar'] ?? avatar;
    }

    // Add friend to current user's friends list
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .doc(friendId)
        .set({
      'name': friendName,
      'phone': friendPhone,
      'avatar': friendAvatar,
      'addedAt': FieldValue.serverTimestamp(),
      'status': 'active',
      'isRegisteredUser': friendDoc.exists,
    });
  }

  // Get specific friend details
  Future<Friend?> getFriend(String friendId) async {
    if (_currentUserId == null) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(friendId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final balance = await _calculateBalance(friendId);

      return Friend(
        id: friendId,
        name: data['name'] ?? 'Unknown',
        avatar: data['avatar'] ?? '👤',
        balance: balance,
      );
    } catch (e) {
      print('Error getting friend: $e');
      return null;
    }
  }

  // Calculate balance between current user and friend
  Future<double> _calculateBalance(String friendId) async {
    if (_currentUserId == null) return 0.0;

    try {
      final conversationId = _getConversationId(currentUserId, friendId);

      final snapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('transactions')
          .get();

      double balance = 0.0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0).toDouble();
        final paidBy = data['paidBy'] ?? '';
        final type = data['type'] ?? 'expense';

        if (type == 'expense') {
          if (paidBy == currentUserId) {
            balance += amount; // Friend owes you the full amount
          } else {
            balance -= amount; // You owe friend the full amount
          }
        } else if (type == 'settlement') {
          if (paidBy == currentUserId) {
            balance -= amount; // You paid friend
          } else {
            balance += amount; // Friend paid you
          }
        }
      }

      return balance;
    } catch (e) {
      print('Error calculating balance: $e');
      return 0.0;
    }
  }

  // Generate consistent conversation ID for two users
  String _getConversationId(String userId1, String userId2) {
    final users = [userId1, userId2]..sort();
    return '${users[0]}_${users[1]}';
  }

  // Delete a friend
  Future<void> deleteFriend(String friendId) async {
    if (_currentUserId == null) return;

    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .doc(friendId)
        .delete();
  }

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (_currentUserId == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(currentUserId).get();
      return doc.data();
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  Future<void> deleteTransaction(String friendId, String transactionId) async {
    try {
      final conversationId = _getConversationId(currentUserId, friendId);

      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('transactions')
          .doc(transactionId)
          .delete();
    } catch (e) {
      print('Error deleting transaction: $e');
      rethrow;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(String name, String avatar) async {
    if (_currentUserId == null) return;

    await _firestore.collection('users').doc(currentUserId).set({
      'name': name,
      'avatar': avatar,
      'phone': _currentUserPhone,
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _currentUserName = name;

    // Update local storage
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
  }

  // Get current user's FCM token
  Future<String?> getCurrentUserFCMToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }
}

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  print('Background message: ${message.messageId}');
  // Handle background message processing here
}