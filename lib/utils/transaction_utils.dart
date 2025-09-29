import 'package:flutter/material.dart';
import '../models/models.dart';

class TransactionUtils {
  static double calculateBalance(List<Transaction> transactions, String currentUserId) {
    double balance = 0;
    for (var transaction in transactions) {
      if (transaction.type == 'settlement') {
        if (transaction.paidBy == currentUserId) {
          balance += transaction.amount; // You paid in settlement = friend owes you less
        } else {
          balance -= transaction.amount; // Friend paid in settlement = you owe friend less
        }
      } else {
        // REGULAR TRANSACTION LOGIC: Standard expense tracking
        if (transaction.paidBy == currentUserId) {
          balance += transaction.amount; // You paid, friend owes you more
        } else {
          balance -= transaction.amount; // Friend paid, you owe friend more
        }
      }
    }
    return balance;
  }

  static String getBalanceText(double balance, String friendName) {
    if (balance > 0) {
      return 'Take ₹${balance.abs().toStringAsFixed(2)} from ${friendName.split(' ')[0]}';
    } else if (balance < 0) {
      return 'Give ₹${balance.abs().toStringAsFixed(2)} to ${friendName.split(' ')[0]}';
    } else {
      return 'All settled up! 🎉';
    }
  }

  static Color getBalanceColor(double balance) {
    if (balance > 0) {
      return Colors.green.shade600;
    } else if (balance < 0) {
      return Colors.red.shade600;
    } else {
      return Colors.blue.shade700;
    }
  }
}