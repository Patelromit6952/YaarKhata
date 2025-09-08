import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../dataservice.dart';
import '../models/models.dart';

class SettlementDialog {
  static void show({
    required BuildContext context,
    required double currentBalance,
    required Friend friend,
    required DataService dataService,
    required VoidCallback onSettled,
  }) {
    if (currentBalance == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Already settled up!'),
            ],
          ),
          backgroundColor: Colors.blue.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final amountController = TextEditingController(
      text: currentBalance.abs().toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Colors.blue.shade700),
            SizedBox(width: 12),
            Text(
              'Settle Up',
              style: TextStyle(
                color: Colors.blue.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentBalance > 0
                  ? '${friend.name} owes you ₹${currentBalance.abs().toStringAsFixed(2)}'
                  : 'You owe ${friend.name} ₹${currentBalance.abs().toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Settlement Amount',
                labelStyle: TextStyle(color: Colors.blue.shade700),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
                ),
                prefixText: '₹',
                prefixStyle: TextStyle(color: Colors.blue.shade700),
                fillColor: Colors.blue.shade50,
                filled: true,
              ),
              cursorColor: Colors.blue.shade700,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                HapticFeedback.lightImpact();

                // CORRECT SETTLEMENT LOGIC:
                // Create the settlement transaction with proper paidBy field
                final settlementPaidBy = currentBalance > 0 ? friend.id : dataService.currentUserId;

                final transaction = Transaction(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  description: 'Settlement',
                  amount: amount,
                  paidBy: settlementPaidBy, // This is who "paid" in the settlement
                  date: DateTime.now(),
                  createdBy: dataService.currentUserId,
                  type: 'settlement',
                );

                // FIXED: Pass friend.id as friendId parameter, not paidBy
                dataService.addSettlementTransaction(friend.id, transaction);

                Navigator.pop(context);
                onSettled();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Settlement recorded'),
                      ],
                    ),
                    backgroundColor: Colors.green.shade600,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Please enter a valid amount'),
                      ],
                    ),
                    backgroundColor: Colors.red.shade600,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Settle',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}