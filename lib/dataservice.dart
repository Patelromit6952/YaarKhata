import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:friendsbook/main.dart';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/models.dart';
import 'package:http/http.dart' as http;


class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;


  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserPhone;

  String get currentUserId => _currentUserId ?? 'anonymous';
  String get currentUserName => _currentUserName ?? 'You';
  String get currentUserPhone => _currentUserPhone ?? '';
  final String baseUrl = "https://otpserver-m62i.onrender.com";
  // Hive boxes
  late Box<Friend> _friendsBox;
  late Box<Transaction> _transactionsBox;

  // Caching and performance optimization
  Map<String, String> _phoneToFirebaseUidCache = {};
  Map<String, double> _balanceCache = {};
  Map<String, StreamSubscription> _activeStreams = {};
  bool _syncInProgress = false;
  DateTime? _lastSyncTime;

  // Status getters
  bool get isSyncInProgress => _syncInProgress;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? _verificationId;

  // Initialize Hive with error handling
  Future<void> initHive() async {
    try {
      _friendsBox = await Hive.openBox<Friend>('friends');
      _transactionsBox = await Hive.openBox<Transaction>('transactions');
      print("✅ Hive boxes initialized successfully");
    } catch (e) {
      print("❌ Error initializing Hive: $e");
      rethrow;
    }
  }

  // Enhanced initialization with proper sequencing
  Future<void> initializeAndSync() async {
    try {
      print("🚀 Initializing DataService...");

      // Step 1: Initialize Firebase Auth
      await initialize();

      // Step 2: Initialize Hive
      await initHive();

      // Step 3: Check if user is logged in
      bool isLoggedIn = await isUserLoggedIn();

      if (isLoggedIn && _currentUserId != null) {
        print("🔄 User logged in, starting initial sync...");
        // Step 4: Perform initial sync from Firestore to Hive
        await syncDataToLocal();
        print("✅ Initial sync completed successfully");
      } else {
        print("ℹ️ User not logged in, skipping sync");
      }
    } catch (e) {
      print("❌ Error during initialization: $e");
      // Don't rethrow - app should continue to work offline
    }
  }

  // Check if phone number is registered
  Future<bool> isPhoneNumberRegistered(String phone) async {
    try {
      // Check cache first
      if (_phoneToFirebaseUidCache.containsKey(phone)) {
        String cachedUserId = _phoneToFirebaseUidCache[phone]!;
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(cachedUserId).get();
        return userDoc.exists;
      }

      // Query Firestore
      QuerySnapshot query = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        // Cache the result
        String userId = query.docs.first.id;
        _phoneToFirebaseUidCache[phone] = userId;
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Error checking phone registration: $e');
      return false;
    }
  }

  Future<void> sendOTP(
      String email,
      Function(String) onCodeSent,
      Function(String) onError,
      ) async {
    try {
      print("📧 Sending OTP to: $email");

      final response = await http.post(
        Uri.parse("$baseUrl/send-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          print("✅ OTP sent successfully to email");
          onCodeSent(email); // Pass email as ID
        } else {
          print("❌ Failed to send OTP: ${data['error'] ?? 'Unknown error'}");
          onError(data['error'] ?? "Failed to send OTP");
        }
      } else {
        print("❌ HTTP error: ${response.body}");
        onError("Server error: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Exception while sending OTP: $e");
      onError("Error sending OTP: $e");
    }
  }

  // Helper method for Firebase Auth error messages
  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address entered is invalid';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'quota-exceeded':
        return 'Email OTP quota exceeded. Please try again tomorrow';
      case 'invalid-verification-code':
        return 'Invalid OTP code. Please try again.';
      case 'session-expired':
        return 'OTP expired. Please request a new code.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }

  // Verify OTP for Registration
  Future<bool> verifyOTPForRegistration(String phone, String name, String email, String smsCode) async {
    try {
      print("🔐 Verifying OTP for registration - email: $email");

      // Call backend to verify OTP with Twilio
      final response = await http.post(
        Uri.parse("$baseUrl/verify-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "otp": smsCode}),
      );

      if (response.statusCode != 200) {
        throw Exception("Server error: ${response.statusCode}");
      }

      final data = jsonDecode(response.body);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? "Invalid OTP");
      }

      print("✅ OTP verified by Twilio. Proceeding with registration...");

      // Sign in anonymously in Firebase (to get a UID)
      UserCredential anonUser = await _auth.signInAnonymously();
      String userId = "user_${phone}";

      // Check if user already exists
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        throw Exception('User already registered. Please use login instead.');
      }

      _currentUserId = userId;
      _currentUserName = name;
      _currentUserPhone = phone;
      _phoneToFirebaseUidCache[phone] = userId;
      String? token = await FirebaseMessaging.instance.getToken();

      // Create Firestore user with phone and email
      await _firestore.collection('users').doc(userId).set({
        'name': name,
        'phone': phone,
        'email': email,
        'fcmToken':token,
        'avatar': _getRandomAvatar(),
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      await _saveUserData(userId, name, phone);
      await _setLoginStatus(true);

      print("✅ New user registered successfully with ID: $userId");
      return true;
    } catch (e) {
      print('❌ Error verifying OTP for registration: $e');
      throw Exception('Error verifying OTP for registration: $e');
    }
  }

  // Verify OTP for Login

  Future<bool> verifyOTPForLogin(String phone, String email, String smsCode) async {
    try {
      print("🔐 Verifying OTP for login - email: $email");

      // 1️⃣ Verify OTP with backend
      final response = await http.post(
        Uri.parse("$baseUrl/verify-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "otp": smsCode}),
      );

      if (response.statusCode != 200) throw Exception("Server error: ${response.statusCode}");

      final data = jsonDecode(response.body);
      if (data['success'] != true) throw Exception(data['error'] ?? "Invalid OTP");

      print("✅ OTP verified successfully. Proceeding with login...");

      // 2️⃣ Fetch user from Firestore
      QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phone)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) throw Exception('User not registered. Please register first.');

      DocumentSnapshot userDoc = userQuery.docs.first;
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      _currentUserId = userDoc.id;
      _currentUserName = userData['name'] ?? '';
      _currentUserPhone = phone;
      _phoneToFirebaseUidCache[phone] = userDoc.id;

      // 3️⃣ Request notification permission (especially for iOS)
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // 4️⃣ Get FCM token
      String? token = await FirebaseMessaging.instance.getToken();
      print("📱 FCM token: $token");

      // 5️⃣ Update Firestore with token and last active
      await _firestore.collection('users').doc(userDoc.id).update({
        'lastActive': FieldValue.serverTimestamp(),
        'status': 'active',
        'fcmToken': token,
      });

      // 6️⃣ Save locally
      await _saveUserData(userDoc.id, _currentUserName!, phone);
      await _setLoginStatus(true);

      print("✅ User logged in successfully with ID: ${userDoc.id}");
      return true;

    } catch (e) {
      print('❌ Error verifying OTP for login: $e');
      throw Exception('Error verifying OTP for login: $e');
    }
  }
  // Wrapper methods for LoginRegisterPage
  Future<void> registerUserWithOTP(String phone, String name, String email, String verificationId, String otp) async {
    await verifyOTPForRegistration(phone, name, email, otp);
  }

  Future<void> loginUserWithOTP(String phone, String email, String verificationId, String otp) async {
    await verifyOTPForLogin(phone, email, otp);
  }
  // Set/get login status locally
  Future<void> _setLoginStatus(bool isLoggedIn) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', isLoggedIn);
    print("💾 Login status set to: $isLoggedIn");
  }

  Future<bool> getLoginStatus() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool('isLoggedIn') ?? false;
    } catch (e) {
      print('❌ Error getting login status: $e');
      return false;
    }
  }

  // Efficient sync with caching and batch operations
  Future<void> syncDataToLocal() async {
    if (_currentUserId == null) return;

    if (_syncInProgress) {
      print("⚠️ Sync already in progress, skipping...");
      return;
    }

    _syncInProgress = true;

    try {
      print("🔄 Starting optimized Firestore → Hive sync for user: $_currentUserId");

      await _checkAndMigrateFriends();

      // Clear caches for fresh data
      _phoneToFirebaseUidCache.clear();
      _balanceCache.clear();

      // Fetch friends with timeout
      final friendsSnapshot = await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('friends')
          .get()
          .timeout(Duration(seconds: 15));

      print("📥 Fetched ${friendsSnapshot.docs.length} friends from Firestore");

      List<Friend> friendsToUpdate = [];
      Map<String, String> friendIdToFirebaseUid = {};

      // Process friends in parallel
      List<Future<Friend?>> friendFutures = friendsSnapshot.docs.map((doc) async {
        try {
          final data = doc.data();
          final friendId = doc.id;
          final friendPhone = friendId.contains('_') ? friendId.split('_').last : friendId;

          String? friendFirebaseUid = await _getFirebaseUidByPhone(friendPhone);

          if (friendFirebaseUid != null) {
            friendIdToFirebaseUid[friendId] = friendFirebaseUid;

            final cacheKey = '${_currentUserId}_$friendFirebaseUid';
            double balance = await _calculateBalanceWithFirebaseUid(_currentUserId!, friendFirebaseUid);
            _balanceCache[cacheKey] = balance;

            return Friend(
              id: friendId,
              name: data['name'] ?? 'Unknown',
              avatar: data['avatar'] ?? '👤',
              balance: balance,
            );
          }
          return null;
        } catch (e) {
          print("⚠️ Error processing friend ${doc.id}: $e");
          return null;
        }
      }).toList();

      final friendResults = await Future.wait(friendFutures);
      friendsToUpdate = friendResults.where((f) => f != null).cast<Friend>().toList();

      // Batch update Hive
      Map<String, Friend> friendsMap = {};
      for (var friend in friendsToUpdate) {
        friendsMap[friend.id] = friend;
      }
      await _friendsBox.putAll(friendsMap);

      print("✅ ${friendsToUpdate.length} friends synced to Hive");

      await _syncTransactionsForAllFriends(friendIdToFirebaseUid);

      _lastSyncTime = DateTime.now();
      print("✅ Complete sync finished at ${_lastSyncTime}");
    } catch (e) {
      print("❌ Error during sync: $e");
      rethrow;
    } finally {
      _syncInProgress = false;
    }
  }

  // Parallel transaction sync
  Future<void> _syncTransactionsForAllFriends(Map<String, String> friendIdToFirebaseUid) async {
    if (friendIdToFirebaseUid.isEmpty) return;

    print("🔄 Starting parallel transaction sync for ${friendIdToFirebaseUid.length} friends");

    List<Future<void>> transactionFutures = friendIdToFirebaseUid.entries.map((entry) async {
      final friendId = entry.key;
      final friendFirebaseUid = entry.value;

      try {
        final conversationId = _getConversationId(_currentUserId!, friendFirebaseUid);

        final txSnapshot = await _firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('transactions')
            .get()
            .timeout(Duration(seconds: 10));

        if (txSnapshot.docs.isNotEmpty) {
          Map<String, Transaction> transactionsMap = {};

          for (var txDoc in txSnapshot.docs) {
            final data = txDoc.data();
            final tx = Transaction(
              id: txDoc.id,
              description: data['description'] ?? '',
              amount: (data['amount'] ?? 0).toDouble(),
              paidBy: data['paidBy'] ?? '',
              date: (data['date'] as Timestamp).toDate(),
              type: data['type'] ?? 'expense',
              createdBy: data['createdBy'] ?? ''
            );
            transactionsMap[txDoc.id] = tx;
          }

          await _transactionsBox.putAll(transactionsMap);
          print("✅ ${transactionsMap.length} transactions synced for friend: $friendId");
        }
      } catch (e) {
        print("⚠️ Error syncing transactions for $friendId: $e");
      }
    }).toList();

    await Future.wait(transactionFutures);
    print("✅ All transaction syncs completed");
  }

  // Cached Firebase UID lookup
  Future<String?> _getFirebaseUidByPhone(String phone) async {
    if (_phoneToFirebaseUidCache.containsKey(phone)) {
      return _phoneToFirebaseUidCache[phone];
    }

    try {
      final query = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get()
          .timeout(Duration(seconds: 5));

      if (query.docs.isNotEmpty) {
        final uid = query.docs.first.id;
        _phoneToFirebaseUidCache[phone] = uid;
        return uid;
      }
      return null;
    } catch (e) {
      print('Error resolving Firebase UID for $phone: $e');
      return null;
    }
  }

  // Enhanced balance calculation with caching
  Future<double> _calculateBalanceWithFirebaseUid(String currentUserFirebaseUid, String friendFirebaseUid) async {
    final cacheKey = '${currentUserFirebaseUid}_$friendFirebaseUid';

    if (_balanceCache.containsKey(cacheKey)) {
      return _balanceCache[cacheKey]!;
    }

    try {
      final conversationId = _getConversationId(currentUserFirebaseUid, friendFirebaseUid);

      final snapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('transactions')
          .get()
          .timeout(Duration(seconds: 10));

      double balance = 0.0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0).toDouble();
        final paidBy = data['paidBy'] ?? '';
        final type = data['type'] ?? 'expense';

        if (type == 'expense') {
          if (paidBy == currentUserFirebaseUid) {
            balance += amount;
          } else if (paidBy == friendFirebaseUid) {
            balance -= amount;
          }
        } else if (type == 'settlement') {
          if (paidBy == currentUserFirebaseUid) {
            balance -= amount;
          } else if (paidBy == friendFirebaseUid) {
            balance += amount;
          }
        }
      }

      _balanceCache[cacheKey] = balance;
      return balance;
    } catch (e) {
      print('❌ Error calculating balance: $e');
      return 0.0;
    }
  }

  // Transaction streams
  Future<Stream<List<Transaction>>> getTransactionsStream(String friendId) async {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    try {
      final friendPhone = friendId.contains('_') ? friendId.split('_').last : friendId;

      String? friendFirebaseUid = _phoneToFirebaseUidCache[friendPhone];
      if (friendFirebaseUid == null) {
        friendFirebaseUid = await _getFirebaseUidByPhone(friendPhone);
        if (friendFirebaseUid == null) {
          throw Exception('Friend not found in Firestore');
        }
        _phoneToFirebaseUidCache[friendPhone] = friendFirebaseUid;
      }

      final conversationId = _getConversationId(_currentUserId!, friendFirebaseUid);
      _activeStreams[conversationId]?.cancel();

      final stream = _firestore
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
            createdBy: data['createdBy'] ?? ''
          );
        }).toList();
      });

      return stream;
    } catch (e) {
      print('❌ Error creating transaction stream for $friendId: $e');
      return Stream.value([]);
    }
  }

  // Local transaction operations
  List<Transaction> getLocalTransactions(String friendId) {
    if (_currentUserId == null) return [];

    try {
      final friendPhone = friendId.contains('_') ? friendId.split('_').last : friendId;
      final friendFirebaseUid = _phoneToFirebaseUidCache[friendPhone];

      if (friendFirebaseUid == null) {
        return _transactionsBox.values.where((tx) {
          return tx.paidBy == _currentUserId || tx.paidBy == friendId;
        }).toList();
      }

      return _transactionsBox.values.where((tx) {
        return tx.paidBy == _currentUserId || tx.paidBy == friendFirebaseUid;
      }).toList();
    } catch (e) {
      print('❌ Error getting local transactions for $friendId: $e');
      return [];
    }
  }

  double calculateLocalBalance(String friendId) {
    final cacheKey = '${_currentUserId}_$friendId';

    if (_balanceCache.containsKey(cacheKey)) {
      return _balanceCache[cacheKey]!;
    }

    double balance = 0.0;
    final transactions = getLocalTransactions(friendId);

    for (var tx in transactions) {
      if (tx.type == 'expense') {
        if (tx.paidBy == _currentUserId) {
          balance += tx.amount;
        } else {
          balance -= tx.amount;
        }
      } else if (tx.type == 'settlement') {
        if (tx.paidBy == _currentUserId) {
          balance -= tx.amount;
        } else {
          balance += tx.amount;
        }
      }
    }

    _balanceCache[cacheKey] = balance;
    return balance;
  }

  // Add transaction

// Updated DataService method - returns immediately after local storage
  Future<void> addTransaction(String friendId, Transaction transaction) async {
    if (_currentUserId == null || _currentUserPhone == null) {
      throw Exception('User not logged in or phone number missing');
    }

    try {
      final tempId = UniqueKey().toString();
      final tempTransaction = Transaction(
        id: tempId,
        description: transaction.description,
        amount: transaction.amount,
        paidBy: transaction.paidBy,
        date: transaction.date,
        type: transaction.type,
        createdBy: _currentUserId,
      );

      // Add to local storage immediately
      await _transactionsBox.put(tempId, tempTransaction);

      // Update local friend balance & cache
      _balanceCache.remove('${_currentUserId}_$friendId');
      final friend = _friendsBox.get(friendId);
      if (friend != null) {
        friend.balance = calculateLocalBalance(friendId);
        await friend.save();
      }

      print("✅ Transaction added locally with temp ID: $tempId");

      // Sync to Firebase in background (don't await)
      _syncTransactionToFirebase(friendId, transaction, tempId);

    } catch (e) {
      print('❌ Error adding transaction locally: $e');
      throw Exception('Failed to add transaction: $e');
    }
  }// Add this method to your DataService class

  // Add settlement transaction (separate from regular transactions)
  Future<void> addSettlementTransaction(String friendId, Transaction transaction) async {
    if (_currentUserId == null || _currentUserPhone == null) {
      throw Exception('User not logged in or phone number missing');
    }

    try {
      final friendPhone = friendId.contains('_') ? friendId.split('_').last : friendId;

      String? friendFirebaseUid = _phoneToFirebaseUidCache[friendPhone];
      if (friendFirebaseUid == null) {
        friendFirebaseUid = await _getFirebaseUidByPhone(friendPhone);
        if (friendFirebaseUid == null) {
          throw Exception('Friend not found in Firestore');
        }
        _phoneToFirebaseUidCache[friendPhone] = friendFirebaseUid;
      }

      final conversationId = _getConversationId(_currentUserId!, friendFirebaseUid);

      // IMPORTANT: For settlements, use the transaction's paidBy field as-is
      // Don't override it like in regular transactions
      DocumentReference docRef = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('transactions')
          .add({
        'description': transaction.description,
        'amount': transaction.amount,
        'paidBy': transaction.paidBy, // Keep the original paidBy value
        'date': Timestamp.fromDate(transaction.date),
        'type': transaction.type,
        'createdBy': _currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'participants': [_currentUserId!, friendFirebaseUid],
      });

      // Update conversation metadata
      await _firestore.collection('conversations').doc(conversationId).set({
        'participants': [_currentUserId!, friendFirebaseUid],
        'lastActivity': FieldValue.serverTimestamp(),
        'lastTransaction': {
          'description': transaction.description,
          'amount': transaction.amount,
          'createdBy': _currentUserId,
          'createdAt': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));

      // Add to Hive with the correct transaction data
      final transactionWithId = Transaction(
        id: docRef.id,
        description: transaction.description,
        amount: transaction.amount,
        paidBy: transaction.paidBy, // Keep original paidBy
        date: transaction.date,
        type: transaction.type,
        createdBy: transaction.createdBy
      );

      await _transactionsBox.put(docRef.id, transactionWithId);

      // Invalidate balance cache
      _balanceCache.remove('${_currentUserId}_$friendId');
      _balanceCache.remove('${_currentUserId}_$friendFirebaseUid');

      // Update friend balance
      final friend = _friendsBox.get(friendId);
      if (friend != null) {
        friend.balance = calculateLocalBalance(friendId);
        await friend.save();
      }

      print("✅ Settlement transaction added successfully with ID: ${docRef.id}");
    } catch (e) {
      print('❌ Error adding settlement transaction: $e');
      throw Exception('Failed to add settlement transaction: $e');
    }
  }
  // Friends stream
  Stream<List<Friend>> getFriendsStream() {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(_currentUserId!)
        .collection('friends')
        .snapshots()
        .asyncMap((snapshot) async {
      List<Friend> friends = [];

      List<Future<Friend?>> friendFutures = snapshot.docs.map((doc) async {
        try {
          final friendData = doc.data();
          final friendId = doc.id;
          final friendPhone = friendId.contains('_') ? friendId.split('_').last : friendId;

          String? friendFirebaseUid = _phoneToFirebaseUidCache[friendPhone];
          if (friendFirebaseUid == null) {
            friendFirebaseUid = await _getFirebaseUidByPhone(friendPhone);
            if (friendFirebaseUid != null) {
              _phoneToFirebaseUidCache[friendPhone] = friendFirebaseUid;
            }
          }

          double balance = 0.0;
          if (friendFirebaseUid != null) {
            balance = await _calculateBalanceWithFirebaseUid(_currentUserId!, friendFirebaseUid);
          }

          final friend = Friend(
            id: friendId,
            name: friendData['name'] ?? 'Unknown',
            avatar: friendData['avatar'] ?? '👤',
            balance: balance,
          );

          // Store/update friend in Hive
          await _friendsBox.put(friendId, friend);

          return friend;
        } catch (e) {
          print('Error processing friend ${doc.id}: $e');
          return null;
        }
      }).toList();

      final results = await Future.wait(friendFutures);
      friends = results.where((f) => f != null).cast<Friend>().toList();

      return friends;
    });
  }

  // Add friend
  Future<void> addFriend(String friendPhone, String name, String avatar) async {
    if (_currentUserId == null) throw Exception('User not logged in');

    try {
      print("👥 Adding friend with phone: $friendPhone to user: $_currentUserId");

      // Check if friend already exists
      final existingFriend = await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('friends')
          .where('phone', isEqualTo: friendPhone)
          .limit(1)
          .get();

      if (existingFriend.docs.isNotEmpty) {
        throw Exception('Friend with this phone number is already added');
      }

      String? friendFirebaseUid = _phoneToFirebaseUidCache[friendPhone];
      bool isRegisteredUser = false;
      String friendName = name;
      String friendAvatar = avatar;

      if (friendFirebaseUid == null) {
        QuerySnapshot friendQuery = await _firestore
            .collection('users')
            .where('phone', isEqualTo: friendPhone)
            .limit(1)
            .get();

        if (friendQuery.docs.isNotEmpty) {
          DocumentSnapshot friendDoc = friendQuery.docs.first;
          Map<String, dynamic> friendData = friendDoc.data() as Map<String, dynamic>;

          friendFirebaseUid = friendDoc.id;
          friendName = name;
          friendAvatar = avatar;
          isRegisteredUser = true;

          _phoneToFirebaseUidCache[friendPhone] = friendFirebaseUid;
          print("✅ Adding registered friend with ID: $friendFirebaseUid");
        } else {
          friendFirebaseUid = _generateUserId(friendPhone);
          print("✅ Adding unregistered friend with ID: $friendFirebaseUid");
        }
      }

      final friendDocId = 'user_${friendPhone}';

      await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('friends')
          .doc(friendDocId)
          .set({
        'name': friendName,
        'phone': friendPhone,
        'avatar': friendAvatar,
        'addedAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'isRegisteredUser': isRegisteredUser,
      });

      if (isRegisteredUser) {
        await _addReverseFriendship(friendFirebaseUid!, _currentUserPhone!);
      }

      final friend = Friend(
        id: friendDocId,
        name: friendName,
        avatar: friendAvatar,
        balance: 0.0,
      );
      await _friendsBox.put(friendDocId, friend);

      print("✅ Friend added successfully to user: $_currentUserId");
    } catch (e) {
      print('❌ Error adding friend: $e');
      throw Exception('Failed to add friend: $e');
    }
  }

  // Check login status
  Future<bool> isUserLoggedIn() async {
    try {
      bool isLoggedInLocally = await getLoginStatus();

      if (!isLoggedInLocally) {
        print("❌ User not logged in locally");
        return false;
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');
      String? userName = prefs.getString('user_name');
      String? userPhone = prefs.getString('user_phone');

      if (userId != null && userName != null && userPhone != null) {
        _currentUserId = userId;
        _currentUserName = userName;
        _currentUserPhone = userPhone;

        print("✅ User already logged in: $userId");

        // Background checks
        _updateUserStatus(userId).catchError((e) {
          print("⚠️ Background Firestore check failed: $e");
        });

        _checkAndMigrateFriends().catchError((e) {
          print("⚠️ Friend migration check failed: $e");
        });

        return true;
      } else {
        await _setLoginStatus(false);
        return false;
      }
    } catch (e) {
      print('❌ Error checking login status: $e');
      await _setLoginStatus(false);
      return false;
    }
  }

  // Update user status in background
  Future<void> _updateUserStatus(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get()
          .timeout(Duration(seconds: 5));

      if (userDoc.exists) {
        await _firestore.collection('users').doc(userId).update({
          'lastActive': FieldValue.serverTimestamp(),
        });
        print("✅ User status updated for: $userId");
      }
    } catch (e) {
      print("⚠️ Firestore check failed, continuing offline: $e");
    }
  }

  // Initialize Firebase Auth
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
      print("✅ DataService initialized");
    } catch (e) {
      print('❌ DataService initialization error: $e');
      throw Exception('Failed to initialize DataService: $e');
    }
  }

  // Logout user
  Future<void> logoutUser() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('user_name');
      await prefs.remove('user_phone');

      await _setLoginStatus(false);

      _currentUserId = null;
      _currentUserName = null;
      _currentUserPhone = null;

      cleanup();
      await _auth.signOut();

      print("✅ User logged out successfully");
    } catch (e) {
      print('❌ Logout error: $e');
      throw Exception('Logout failed: ${e.toString()}');
    }
  }

  // Save user data locally
  Future<void> _saveUserData(String userId, String name, String phone) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('user_name', name);
    await prefs.setString('user_phone', phone);
    print("💾 User data saved locally for: $userId");
  }

  // Friend migration methods
  Future<void> _checkAndMigrateFriends() async {
    if (_currentUserId == null) return;

    try {
      print("🔄 Checking for friend migrations...");

      final friendsSnapshot = await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('friends')
          .get();

      List<Map<String, dynamic>> friendsToMigrate = [];

      for (var friendDoc in friendsSnapshot.docs) {
        final friendData = friendDoc.data();
        final friendId = friendDoc.id;
        final phone = friendData['phone'] as String?;

        if (friendId.startsWith('unregistered_') && phone != null) {
          print("🔍 Checking if unregistered friend has registered: $phone");

          final registeredUserQuery = await _firestore
              .collection('users')
              .where('phone', isEqualTo: phone)
              .limit(1)
              .get();

          if (registeredUserQuery.docs.isNotEmpty) {
            final registeredUserDoc = registeredUserQuery.docs.first;
            final newUserId = registeredUserDoc.id;

            print("🎉 Friend has registered! Migrating from $friendId to $newUserId");

            friendsToMigrate.add({
              'oldId': friendId,
              'newId': newUserId,
              'friendData': friendData,
              'phone': phone,
            });
          }
        }
      }

      for (var migration in friendsToMigrate) {
        await _migrateFriend(
            migration['oldId'],
            migration['newId'],
            migration['friendData'],
            migration['phone']
        );
      }
    } catch (e) {
      print("❌ Error checking friend migrations: $e");
    }
  }

  Future<void> _migrateFriend(String oldFriendId, String newFriendId, Map<String, dynamic> friendData, String phone) async {
    if (_currentUserId == null) return;

    try {
      print("🚀 Migrating friend from $oldFriendId to $newFriendId");

      final registeredUserDoc = await _firestore
          .collection('users')
          .doc(newFriendId)
          .get();

      Map<String, dynamic> registeredUserData = registeredUserDoc.data() as Map<String, dynamic>;

      await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('friends')
          .doc(newFriendId)
          .set({
        'name': registeredUserData['name'] ?? friendData['name'],
        'phone': phone,
        'avatar': registeredUserData['avatar'] ?? friendData['avatar'],
        'addedAt': friendData['addedAt'] ?? FieldValue.serverTimestamp(),
        'status': 'active',
        'isRegisteredUser': true,
        'migratedFrom': oldFriendId,
        'migratedAt': FieldValue.serverTimestamp(),
      });

      await _addReverseFriendship(newFriendId, phone);
      await _migrateTransactions(oldFriendId, newFriendId);

      await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('friends')
          .doc(oldFriendId)
          .delete();

      print("✅ Friend migration completed successfully");
    } catch (e) {
      print("❌ Error migrating friend: $e");
    }
  }

  Future<void> _addReverseFriendship(String friendUserId, String myPhone) async {
    if (_currentUserId == null) return;

    try {
      final myUserDoc = await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .get();

      if (!myUserDoc.exists) return;

      final myData = myUserDoc.data() as Map<String, dynamic>;

      await _firestore
          .collection('users')
          .doc(friendUserId)
          .collection('friends')
          .doc('${_currentUserName}_${_currentUserPhone}')
          .set({
        'name': myData['name'] ?? _currentUserName,
        'phone': myPhone,
        'avatar': myData['avatar'] ?? '👤',
        'addedAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'isRegisteredUser': true,
        'addedBy': 'migration',
      }, SetOptions(merge: true));

      print("✅ Reverse friendship added for user: $friendUserId");
    } catch (e) {
      print("❌ Error adding reverse friendship: $e");
    }
  }

  Future<void> _migrateTransactions(String oldFriendId, String newFriendId) async {
    if (_currentUserId == null) return;

    try {
      final oldConversationId = _getConversationId(_currentUserId!, oldFriendId);
      final newConversationId = _getConversationId(_currentUserId!, newFriendId);

      print("📦 Migrating transactions from $oldConversationId to $newConversationId");

      final oldTransactions = await _firestore
          .collection('conversations')
          .doc(oldConversationId)
          .collection('transactions')
          .get();

      WriteBatch batch = _firestore.batch();

      for (var txDoc in oldTransactions.docs) {
        final txData = txDoc.data();

        if (txData['paidBy'] == oldFriendId) {
          txData['paidBy'] = newFriendId;
        }

        txData['migratedFrom'] = oldConversationId;
        txData['migratedAt'] = FieldValue.serverTimestamp();

        final newTxRef = _firestore
            .collection('conversations')
            .doc(newConversationId)
            .collection('transactions')
            .doc();

        batch.set(newTxRef, txData);
      }

      batch.set(
          _firestore.collection('conversations').doc(newConversationId),
          {
            'participants': [_currentUserId!, newFriendId],
            'lastActivity': FieldValue.serverTimestamp(),
            'migratedFrom': oldConversationId,
            'migratedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true)
      );

      await batch.commit();
      await _deleteConversation(oldConversationId);

      print("✅ Transactions migrated successfully");
    } catch (e) {
      print("❌ Error migrating transactions: $e");
    }
  }

  Future<void> _deleteConversation(String conversationId) async {
    try {
      final transactions = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('transactions')
          .get();

      WriteBatch batch = _firestore.batch();

      for (var doc in transactions.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(_firestore.collection('conversations').doc(conversationId));
      await batch.commit();

      print("🗑️ Old conversation deleted: $conversationId");
    } catch (e) {
      print("❌ Error deleting conversation: $e");
    }
  }

  // Utility methods
  String _generateUserId(String phone) {
    return 'unregistered_$phone';
  }

  String _getRandomAvatar() {
    List<String> avatars = [
      '👤', '🧑‍💼', '👩‍💼', '🧑‍🎓', '👩‍🎓', '🧑‍💻', '👩‍💻',
      '🧑‍🔬', '👩‍🔬', '🧑‍🎨', '👩‍🎨', '🧑‍🍳', '👩‍🍳', '🧑‍⚕️', '👩‍⚕️'
    ];
    return avatars[DateTime.now().millisecond % avatars.length];
  }

  String _getConversationId(String userId1, String userId2) {
    final users = [userId1, userId2]..sort();
    return '${users[0]}_${users[1]}';
  }

  // Additional utility methods
  Future<void> refreshData() async {
    if (_currentUserId == null) {
      throw Exception('User not logged in');
    }

    print("🔄 Manual data refresh triggered...");
    await syncDataToLocal();
    print("✅ Manual refresh completed");
  }

  Stream<List<Friend>> getLocalFriends() {
    return _friendsBox.watch().map((event) => _friendsBox.values.toList());
  }

  Future<Friend?> getFriend(String friendId) async {
    if (_currentUserId == null) return null;

    try {
      final cachedFriend = _friendsBox.get(friendId);
      if (cachedFriend != null) {
        return cachedFriend;
      }

      final doc = await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('friends')
          .doc(friendId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final friendPhone = friendId.contains('_') ? friendId.split('_').last : friendId;
      final friendFirebaseUid = await _getFirebaseUidByPhone(friendPhone);

      double balance = 0.0;
      if (friendFirebaseUid != null) {
        balance = await _calculateBalanceWithFirebaseUid(_currentUserId!, friendFirebaseUid);
      }

      final friend = Friend(
        id: friendId,
        name: data['name'] ?? 'Unknown',
        avatar: data['avatar'] ?? '👤',
        balance: balance,
      );

      await _friendsBox.put(friendId, friend);
      return friend;
    } catch (e) {
      print('❌ Error getting friend: $e');
      return null;
    }
  }

  Future<bool> updateTransaction(String friendId, Transaction transaction) async {
    if (_currentUserId == null) throw Exception('User not logged in');

    try {
      final friendPhone = friendId.contains('_') ? friendId.split('_').last : friendId;
      String? friendFirebaseUid = _phoneToFirebaseUidCache[friendPhone];

      if (friendFirebaseUid == null) {
        friendFirebaseUid = await _getFirebaseUidByPhone(friendPhone);
        if (friendFirebaseUid == null) {
          throw Exception('Friend not found');
        }
        _phoneToFirebaseUidCache[friendPhone] = friendFirebaseUid;
      }

      final conversationId = _getConversationId(_currentUserId!, friendFirebaseUid);
      print(transaction.createdBy);
     if(transaction.createdBy == _currentUserId){
       await _firestore
           .collection('conversations')
           .doc(conversationId)
           .collection('transactions')
           .doc(transaction.id)
           .set({
         'description': transaction.description,
         'amount': transaction.amount,
         'paidBy': transaction.paidBy,
         'date': Timestamp.fromDate(transaction.date),
         'type': transaction.type,
         'createdBy':_currentUserId,
         'updatedAt': FieldValue.serverTimestamp(),
       }, SetOptions(merge: true));

       await _transactionsBox.put(transaction.id, transaction);

       // Invalidate balance cache
       _balanceCache.remove('${_currentUserId}_$friendId');
       _balanceCache.remove('${_currentUserId}_$friendFirebaseUid');

       // Update friend balance
       final friend = _friendsBox.get(friendId);
       if (friend != null) {
         friend.balance = calculateLocalBalance(friendId);
         await friend.save();
       }

       print("✅ Transaction updated successfully: ${transaction.id}");
       return true;
     }
     else{
       return false;
     }
    } catch (e) {
      print('❌ Error updating transaction: $e');
      throw Exception('Failed to update transaction: $e');
    }
  }

  Future<void> deleteTransaction(String friendId, String transactionId) async {
    if (_currentUserId == null) throw Exception('User not logged in');

    try {
      final friendPhone = friendId.contains('_') ? friendId.split('_').last : friendId;
      String? friendFirebaseUid = _phoneToFirebaseUidCache[friendPhone];

      if (friendFirebaseUid == null) {
        friendFirebaseUid = await _getFirebaseUidByPhone(friendPhone);
        if (friendFirebaseUid == null) {
          throw Exception('Friend not found');
        }
        _phoneToFirebaseUidCache[friendPhone] = friendFirebaseUid;
      }

      final conversationId = _getConversationId(_currentUserId!, friendFirebaseUid);

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('transactions')
          .doc(transactionId)
          .delete();

      await _transactionsBox.delete(transactionId);

      // Invalidate balance cache
      _balanceCache.remove('${_currentUserId}_$friendId');
      _balanceCache.remove('${_currentUserId}_$friendFirebaseUid');

      print("✅ Transaction deleted: $transactionId");
    } catch (e) {
      print('❌ Error deleting transaction: $e');
      throw Exception('Failed to delete transaction: $e');
    }
  }

  Future<void> deleteFriend(String friendId) async {
    if (_currentUserId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('friends')
          .doc(friendId)
          .delete();

      await _friendsBox.delete(friendId);

      // Clear related caches
      final friendPhone = friendId.contains('_') ? friendId.split('_').last : friendId;
      _phoneToFirebaseUidCache.remove(friendPhone);
      _balanceCache.removeWhere((key, _) => key.contains(friendId));

      print("✅ Friend deleted: $friendId");
    } catch (e) {
      print("❌ Error deleting friend: $e");
      throw Exception('Failed to delete friend: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    if (_currentUserId == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(_currentUserId!).get();
      return doc.data();
    } catch (e) {
      print('❌ Error getting user profile: $e');
      return null;
    }
  }

  Future<void> updateUserProfile(String name, String avatar) async {
    if (_currentUserId == null) return;

    try {
      await _firestore.collection('users').doc(_currentUserId!).set({
        'name': name,
        'avatar': avatar,
        'phone': _currentUserPhone,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _currentUserName = name;

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);

      print("✅ User profile updated");
    } catch (e) {
      print("❌ Error updating profile: $e");
      throw Exception('Failed to update profile: $e');
    }
  }

  // Cleanup and performance methods
  void cleanup() {
    for (var subscription in _activeStreams.values) {
      subscription.cancel();
    }
    _activeStreams.clear();
    _phoneToFirebaseUidCache.clear();
    _balanceCache.clear();
  }

  Map<String, dynamic> getPerformanceStats() {
    return {
      'cacheSize': {
        'phoneToFirebaseUid': _phoneToFirebaseUidCache.length,
        'balance': _balanceCache.length,
      },
      'activeStreams': _activeStreams.length,
      'localData': {
        'friends': _friendsBox.length,
        'transactions': _transactionsBox.length,
      },
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
      'syncInProgress': _syncInProgress,
    };
  }

  void clearCache() {
    _phoneToFirebaseUidCache.clear();
    _balanceCache.clear();
    print("🧹 All caches cleared");
  }

  void clearBalanceCache() {
    _balanceCache.clear();
    print("💰 Balance cache cleared");
  }

  // Development helper
  void deleteBox() async {
    await Hive.deleteBoxFromDisk('friends');
    await Hive.deleteBoxFromDisk('transactions');
    print('📦 Hive boxes deleted successfully!');
  }
  Future<void> _syncTransactionToFirebase(String friendId, Transaction transaction, String tempId) async {
    try {
      final friendPhone = friendId.contains('_') ? friendId.split('_').last : friendId;
      String? friendFirebaseUid = _phoneToFirebaseUidCache[friendPhone] ??
          await _getFirebaseUidByPhone(friendPhone);

      if (friendFirebaseUid == null) {
        print('❌ Friend not found in Firestore for background sync');
        return;
      }
      _phoneToFirebaseUidCache[friendPhone] = friendFirebaseUid;

      final conversationId = _getConversationId(_currentUserId!, friendFirebaseUid);

      // Add transaction to Firestore
      DocumentReference docRef = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('transactions')
          .add({
        'description': transaction.description,
        'amount': transaction.amount,
        'paidBy': transaction.paidBy,
        'date': Timestamp.fromDate(transaction.date),
        'type': transaction.type,
        'createdBy': _currentUserId,
        'updatedAt': Timestamp.now(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update conversation metadata
      await _firestore.collection('conversations').doc(conversationId).set({
        'participants': [_currentUserId!, friendFirebaseUid],
        'lastActivity': FieldValue.serverTimestamp(),
        'lastTransaction': {
          'description': transaction.description,
          'amount': transaction.amount,
          'createdBy': _currentUserId,
          'createdAt': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));

      // Replace temp Hive entry with real Firestore ID
      final syncedTransaction = Transaction(
        id: docRef.id,
        description: transaction.description,
        amount: transaction.amount,
        paidBy: transaction.paidBy,
        date: transaction.date,
        type: transaction.type,
        createdBy: _currentUserId,
      );

      await _transactionsBox.put(docRef.id, syncedTransaction);
      await _transactionsBox.delete(tempId);

      // Send FCM notification
      DocumentSnapshot friendDoc = await _firestore.collection('users').doc(friendFirebaseUid).get();
      String? friendToken = friendDoc['fcmToken'];
      if (friendToken != null && friendToken.isNotEmpty) {
        await http.post(
          Uri.parse('$baseUrl/send-notification'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "token": friendToken,
            "title": "New Transaction",
            "body": "${_currentUserName} added ₹${transaction.amount} for ${transaction.description}."
          }),
        );
        print("📩 Notification sent to friend");
      }

      print("✅ Transaction synced to Firebase with ID: ${docRef.id}");
    } catch (e) {
      print('❌ Error syncing transaction to Firebase: $e');
      // You might want to implement a retry mechanism here
      // or mark the transaction as pending sync
    }
  }
}