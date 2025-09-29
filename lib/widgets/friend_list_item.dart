import 'package:flutter/material.dart';
import 'package:friendsbook/widgets/skeleton_loading_widget.dart';
import '../models/models.dart';
import '../dataservice.dart';
import '../utils/balance_calculator.dart';

class FriendListItem extends StatelessWidget {
  final Friend friend;
  final DataService dataService;
  final AnimationController animationController;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final showLoading;

  const FriendListItem({
    Key? key,
    required this.friend,
    required this.dataService,
    required this.animationController,
    required this.index,
    required this.onTap,
    required this.onLongPress,
    required this.showLoading
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Stream<List<Transaction>>>(
      future: dataService.getTransactionsStream(friend.id),
      builder: (context, futureSnapshot) {
        if (futureSnapshot.connectionState == ConnectionState.waiting) {
          return SkeletonLoadingWidget(itemCount: 5);
        }
        if (futureSnapshot.hasError) {
          return Center(child: Text('Error: ${futureSnapshot.error}'));
        }
        if (!futureSnapshot.hasData) {
          return const SizedBox(); // or some placeholder widget
        }

        final stream = futureSnapshot.data!;

        return StreamBuilder<List<Transaction>>(
          stream: stream,
          builder: (context, snapshot) {
            final transactions = snapshot.data ?? [];
            final currentBalance = BalanceCalculator.calculateFriendBalance(
              transactions,
              dataService.currentUserId,
            );

            return FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(
                  parent: animationController,
                  curve: Interval(
                    index * 0.1,
                    (index * 0.1) + 0.5,
                    curve: Curves.easeOut,
                  ),
                ),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade100.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    onLongPress: onLongPress,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          _buildAvatar(),
                          const SizedBox(width: 16),
                          _buildFriendInfo(currentBalance),
                          _buildArrowIcon(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

  }

  Widget _buildAvatar() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade100,
            Colors.blue.shade300,
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade200.withOpacity(0.3),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          friend.avatar,
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  Widget _buildFriendInfo(double currentBalance) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            friend.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade900,
            ),
          ),
          SizedBox(height: 6),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: BalanceCalculator.getBalanceColor(currentBalance).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              BalanceCalculator.getBalanceText(currentBalance),
              style: TextStyle(
                fontSize: 14,
                color: BalanceCalculator.getBalanceColor(currentBalance),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrowIcon() {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.arrow_forward_ios,
        color: Colors.blue.shade600,
        size: 18,
      ),
    );
  }
}