import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../dataservice.dart';
import '../utils/balance_calculator.dart';

class FriendsSummaryCard extends StatelessWidget {
  final DataService dataService;
  final List<Friend> friends;

  const FriendsSummaryCard({
    Key? key,
    required this.dataService,
    required this.friends,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, List<Transaction>>>(
      stream: _getAllFriendsTransactionsStream(friends.map((f) => f.id).toList()),
      builder: (context, transactionsSnapshot) {
        final balances = <String, double>{};
        if (transactionsSnapshot.hasData) {
          for (var friend in friends) {
            balances[friend.id] = BalanceCalculator.calculateFriendBalance(
              transactionsSnapshot.data?[friend.id] ?? [],
              dataService.currentUserId,
            );
          }
        }

        return AnimatedContainer(
          duration: Duration(milliseconds: 500),
          margin: EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.blue.shade100],
              stops: [0.0, 0.7],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade200.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 1,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade200, Colors.blue.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade300.withOpacity(0.2),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.group,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${friends.length} Friends',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      BalanceCalculator.getTotalBalanceText(balances),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Stream<Map<String, List<Transaction>>> _getAllFriendsTransactionsStream(
      List<String> friendIds) {
    return Stream<Map<String, List<Transaction>>>.multi((controller) {
      final Map<String, List<Transaction>> allTransactions = {};
      final List<StreamSubscription> subscriptions = [];

      // Emit empty map first (optional: lets UI render instantly)
      controller.add({});

      Future<void> setup() async {
        for (var friendId in friendIds) {
          try {
            final stream = await dataService.getTransactionsStream(friendId);

            final subscription = stream.listen((transactions) {
              allTransactions[friendId] = transactions;

              // 🔑 Emit new copy so UI rebuilds every time a friend's list changes
              controller.add(Map.from(allTransactions));
            });

            subscriptions.add(subscription);
          } catch (e) {
            controller.addError('Error loading transactions for $friendId: $e');
          }
        }
      }

      setup();

      controller.onCancel = () {
        for (var subscription in subscriptions) {
          subscription.cancel();
        }
      };
    });
  }

}