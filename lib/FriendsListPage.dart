import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:friendsbook/AboutUsPage.dart';
import 'package:friendsbook/PrivacyPolicyPage.dart';
import 'package:friendsbook/widgets/skeleton_loading_widget.dart';
import 'dataservice.dart';
import 'models/models.dart';
import 'TransactionPage.dart';
import 'LoginRegisterPage.dart';

// Import the separate widget files
import 'widgets/friends_app_bar.dart';
import 'widgets/friends_drawer.dart';
import 'widgets/friends_summary_card.dart';
import 'widgets/friend_list_item.dart';
import 'widgets/empty_state_widget.dart';
import 'widgets/error_state_widget.dart';
import 'dialogs/add_friend_dialog.dart';
import 'dialogs/delete_friend_dialog.dart';
import 'dialogs/logout_dialog.dart';

class FriendsListPage extends StatefulWidget {
  @override
  _FriendsListPageState createState() => _FriendsListPageState();
}

class _FriendsListPageState extends State<FriendsListPage> with TickerProviderStateMixin {
  final DataService _dataService = DataService();
  late AnimationController _animationController;
  late AnimationController _gradientController;
  Animation<double>? _fadeAnimation;

  // State management for efficient loading
  bool _isInitialLoad = true;
  List<Friend> _friends = [];
  String? _error;
  StreamSubscription<List<Friend>>? _friendsSubscription;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeFriendsStream();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _gradientController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  void _initializeFriendsStream() {
    _friendsSubscription = _dataService.getFriendsStream().listen(
          (friends) {
        if (mounted) {
          setState(() {
            _friends = friends;
            _error = null;
            _isInitialLoad = false;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _error = error.toString();
            _isInitialLoad = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _gradientController.dispose();
    _friendsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      drawer: FriendsDrawer(
        dataService: _dataService,
        onLogout: () => LogoutDialog.show(context, _dataService),
      ),
      body: CustomScrollView(
        slivers: [
          FriendsAppBar(gradientController: _gradientController),
          SliverToBoxAdapter(
            child: _fadeAnimation == null
                ? Container()
                : FadeTransition(
              opacity: _fadeAnimation!,
              child: _buildContent(),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildContent() {
    // Show shimmer loading only on initial load
    if (_isInitialLoad) {
      return SkeletonLoadingWidget(itemCount: 5);
    }

    // Show error state if there's an error
    if (_error != null) {
      return ErrorStateWidget(error: _error!);
    }

    // Show empty state if no friends
    if (_friends.isEmpty) {
      return EmptyStateWidget(
        onAddFriend: () => _showAddFriendDialog(),
      );
    }

    // Show friends list
    return _buildFriendsList(_friends);
  }

  Widget _buildFloatingActionButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade500, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade900.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: _showAddFriendDialog,
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: Icon(Icons.person_add, color: Colors.white, size: 24),
        label: Text(
          'Add Friend',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildFriendsList(List<Friend> friends) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FriendsSummaryCard(
            dataService: _dataService,
            friends: friends,
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return FriendListItem(
                friend: friend,
                dataService: _dataService,
                animationController: _animationController,
                index: index,
                onTap: () => _navigateToTransactions(friend),
                onLongPress: () => _showDeleteFriendDialog(friend),
                // Pass a flag to disable any internal loading states
                showLoading: false,
              );
            },
          ),
          SizedBox(height: 80),
        ],
      ),
    );
  }

  void _showAddFriendDialog() {
    AddFriendDialog.show(context, _dataService);
  }

  void _showDeleteFriendDialog(Friend friend) {
    DeleteFriendDialog.show(context, _dataService, friend);
  }

  Future<void> _navigateToTransactions(Friend friend) async {
    HapticFeedback.lightImpact();
    await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: Duration(milliseconds: 600),
        reverseTransitionDuration: Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) => TransactionPage(friend: friend),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0); // Slide from right
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          // Slide transition
          var slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var slideAnimation = animation.drive(slideTween);

          // Fade transition
          var fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));
          var fadeAnimation = animation.drive(fadeTween);

          return SlideTransition(
            position: slideAnimation,
            child: FadeTransition(
              opacity: fadeAnimation,
              child: child,
            ),
          );
        },
      ),
    );
  }
}