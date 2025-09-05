// lib/FriendsListPage.dart - Updated with bluish theme and real-time balance updates
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dataservice.dart';
import 'models/models.dart';
import 'TransactionPage.dart';
import 'LoginRegisterPage.dart';

class FriendsListPage extends StatefulWidget {
  @override
  _FriendsListPageState createState() => _FriendsListPageState();
}

class _FriendsListPageState extends State<FriendsListPage>
    with TickerProviderStateMixin {
  final DataService _dataService = DataService();
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    ));

    _animationController!.forward();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  // Method to calculate real-time balance from transactions
// Fixed method to calculate real-time balance from transactions
  Future<double> _calculateFriendBalance(String friendId) async {
    try {
      // Get the first snapshot from the stream
      final transactionsSnapshot = await _dataService.getTransactionsStream(friendId).first;

      double balance = 0;
      for (var transaction in transactionsSnapshot) {
        if (transaction.type == 'settlement') {
          if (transaction.paidBy == _dataService.currentUserId) {
            balance += transaction.amount;
          } else {
            balance -= transaction.amount;
          }
        } else {
          if (transaction.paidBy == _dataService.currentUserId) {
            balance += transaction.amount;
          } else {
            balance -= transaction.amount;
          }
        }
      }
      return balance;
    } catch (e) {
      print('Error calculating friend balance: $e');
      return 0.0; // Return 0 if there's an error
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // Modern App Bar with gradient
          SliverAppBar(
            expandedHeight: 60,
            floating: false,
            pinned: true,
            elevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue.shade600, Colors.blue.shade800],
                ),
              ),
              child: FlexibleSpaceBar(
                title: Text(
                  'YaarKhata',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                titlePadding: EdgeInsets.only(left: 20, bottom: 10),
              ),
            ),
            actions: [
              // Profile/Menu button
              Container(
                margin: EdgeInsets.only(right: 8),
                child: PopupMenuButton<String>(
                  icon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'profile':
                        _showUserProfile();
                        break;
                      case 'logout':
                        _showLogoutDialog();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, size: 20),
                          SizedBox(width: 12),
                          Text('Profile'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, size: 20, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Logout', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Friends List Content
          SliverToBoxAdapter(
            child: _fadeAnimation == null
                ? Container()
                : FadeTransition(
              opacity: _fadeAnimation!,
              child: StreamBuilder<List<Friend>>(
                stream: _dataService.getFriendsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingState();
                  }

                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  }

                  final friends = snapshot.data ?? [];

                  if (friends.isEmpty) {
                    return _buildEmptyState();
                  }

                  return _buildFriendsList(friends);
                },
              ),
            ),
          ),
        ],
      ),

      // Floating Add Button
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade400, Colors.blue.shade600],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 15,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _showAddFriendDialog,
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: Icon(Icons.person_add, color: Colors.white),
          label: Text(
            'Add Friend',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
            ),
            SizedBox(height: 24),
            Text(
              'Loading your friends...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade300,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Unable to load your friends',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.people_outline,
                size: 80,
                color: Colors.blue.shade300,
              ),
            ),
            SizedBox(height: 32),
            Text(
              'No friends yet!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 12),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Add friends to start tracking expenses and splitting bills together',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _showAddFriendDialog,
                icon: Icon(Icons.person_add, color: Colors.white),
                label: Text(
                  'Add Your First Friend',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList(List<Friend> friends) {
    return Container(
      padding: EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Card
          FutureBuilder<Map<String, double>>(
            future: _calculateAllFriendBalances(friends),
            builder: (context, balanceSnapshot) {
              final balances = balanceSnapshot.data ?? {};
              return Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.blue.shade50],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.group,
                        color: Colors.blue.shade600,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${friends.length} Friends',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _getTotalBalanceTextFromMap(balances),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // SizedBox(height: 15),

          // Friends List with real-time balance updates
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return FutureBuilder<double>(
                future: _calculateFriendBalance(friend.id),
                builder: (context, balanceSnapshot) {
                  final currentBalance = balanceSnapshot.data ?? friend.balance;

                  return Container(
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TransactionPage(friend: friend),
                            ),
                          );
                          // Refresh the page when returning from transaction page
                          setState(() {});
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade100,
                                      Colors.blue.shade200,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(
                                    friend.avatar,
                                    style: TextStyle(fontSize: 28),
                                  ),
                                ),
                              ),

                              SizedBox(width: 16),

                              // Friend Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      friend.name,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getBalanceColor(currentBalance)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _getBalanceText(currentBalance),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: _getBalanceColor(currentBalance),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Arrow
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.grey.shade600,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          SizedBox(height: 100), // Space for FAB
        ],
      ),
    );
  }

  Future<Map<String, double>> _calculateAllFriendBalances(List<Friend> friends) async {
    Map<String, double> balances = {};
    for (var friend in friends) {
      balances[friend.id] = await _calculateFriendBalance(friend.id);
    }
    return balances;
  }

  void _showAddFriendDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedAvatar = '👤';

    final avatars = [
      '👤', '👨', '👩', '👦', '👧', '🧑', '👶', '🧓',
      '👨‍💼', '👩‍💼',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.person_add, color: Colors.blue.shade600),
              SizedBox(width: 12),
              Text(
                'Add Friend',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name Field with bluish theme
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Friend Name',
                    labelStyle: TextStyle(color: Colors.blue.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                    ),
                    prefixIcon: Icon(Icons.person, color: Colors.blue.shade600),
                    fillColor: Colors.blue.shade50,
                    filled: true,
                  ),
                  cursorColor: Colors.blue.shade600,
                  textCapitalization: TextCapitalization.words,
                ),

                SizedBox(height: 16),

                // Phone Field with bluish theme
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    labelStyle: TextStyle(color: Colors.blue.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                    ),
                    prefixIcon: Icon(Icons.phone, color: Colors.blue.shade600),
                    prefixText: '+91 ',
                    prefixStyle: TextStyle(color: Colors.blue.shade600),
                    hintText: '9876543210',
                    hintStyle: TextStyle(color: Colors.blue.shade400),
                    fillColor: Colors.blue.shade50,
                    filled: true,
                  ),
                  cursorColor: Colors.blue.shade600,
                ),

                SizedBox(height: 20),

                // Avatar Selection
                Text(
                  'Choose Avatar:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  width: double.maxFinite,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: avatars.map((avatar) => GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedAvatar = avatar;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selectedAvatar == avatar
                                ? Colors.blue.shade600
                                : Colors.blue.shade300,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: selectedAvatar == avatar
                              ? Colors.blue.shade100
                              : Colors.blue.shade50,
                        ),
                        child: Text(
                          avatar,
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.blue.shade600)),
            ),
            ElevatedButton(
              onPressed: () => _addFriend(
                nameController.text.trim(),
                phoneController.text.trim(),
                selectedAvatar,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Add Friend'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addFriend(String name, String phone, String avatar) async {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a name')),
      );
      return;
    }

    try {
      Navigator.pop(context); // Close dialog

      // Use phone if provided, otherwise generate a unique ID
      String friendPhone = phone.isNotEmpty ? phone :
      'temp_${DateTime.now().millisecondsSinceEpoch}';

      await _dataService.addFriend(friendPhone, name, avatar);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name added successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add friend: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showUserProfile() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.person, color: Colors.blue.shade600),
            SizedBox(width: 12),
            Text('Profile'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blue.shade100,
              child: Text(
                '👤',
                style: TextStyle(fontSize: 32),
              ),
            ),
            SizedBox(height: 16),
            Text(
              _dataService.currentUserName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '+91 ${_dataService.currentUserPhone}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Colors.blue.shade600)),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 12),
            Text('Logout'),
          ],
        ),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.blue.shade600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _dataService.logoutUser();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LoginRegisterPage(),
                    ),
                        (route) => false,
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error logging out: $e'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Logout'),
          ),
        ],
      ),
    );
  }

  String _getTotalBalanceTextFromMap(Map<String, double> balances) {
    double totalOwed = 0;
    double totalOwe = 0;

    for (var balance in balances.values) {
      if (balance > 0) {
        totalOwed += balance;
      } else if (balance < 0) {
        totalOwe += balance.abs();
      }
    }

    if (totalOwed > totalOwe) {
      return 'You are owed ₹${(totalOwed - totalOwe).toStringAsFixed(2)} overall';
    } else if (totalOwe > totalOwed) {
      return 'You owe ₹${(totalOwe - totalOwed).toStringAsFixed(2)} overall';
    } else {
      return 'All settled up!';
    }
  }

  String _getTotalBalanceText(List<Friend> friends) {
    double totalOwed = 0;
    double totalOwe = 0;

    for (var friend in friends) {
      if (friend.balance > 0) {
        totalOwed += friend.balance;
      } else if (friend.balance < 0) {
        totalOwe += friend.balance.abs();
      }
    }

    if (totalOwed > totalOwe) {
      return 'You are owed ₹${(totalOwed - totalOwe).toStringAsFixed(2)} overall';
    } else if (totalOwe > totalOwed) {
      return 'You owe ₹${(totalOwe - totalOwed).toStringAsFixed(2)} overall';
    } else {
      return 'All settled up!';
    }
  }

  String _getBalanceText(double balance) {
    if (balance > 0) {
      return 'You Get ₹${balance.abs().toStringAsFixed(2)}';
    } else if (balance < 0) {
      return 'You give ₹${balance.abs().toStringAsFixed(2)}';
    } else {
      return 'All settled up';
    }
  }

  Color _getBalanceColor(double balance) {
    if (balance > 0) {
      return Colors.green.shade600;
    } else if (balance < 0) {
      return Colors.red.shade600;
    } else {
      return Colors.grey.shade600;
    }
  }
}