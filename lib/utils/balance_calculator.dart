import 'package:flutter/material.dart';
import '../models/models.dart';

class BalanceCalculator {
  static double calculateFriendBalance(List<Transaction> transactions, String currentUserId) {
    double balance = 0;
    for (var transaction in transactions) {
      if (transaction.type == 'settlement') {
        if (transaction.paidBy == currentUserId) {
          balance += transaction.amount;
        } else {
          balance -= transaction.amount;
        }
      } else {
        if (transaction.paidBy == currentUserId) {
          balance += transaction.amount;
        } else {
          balance -= transaction.amount;
        }
      }
    }
    return balance;
  }

  static String getBalanceText(double balance) {
    if (balance > 0) {
      return 'You Get ₹${balance.abs().toStringAsFixed(2)}';
    } else if (balance < 0) {
      return 'You give ₹${balance.abs().toStringAsFixed(2)}';
    } else {
      return 'All settled up';
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

  static String getTotalBalanceText(Map<String, double> balances) {
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
      return 'You Have to Take ₹${(totalOwed - totalOwe).toStringAsFixed(2)}';
    } else if (totalOwe > totalOwed) {
      return 'You Have to Give ₹${(totalOwe - totalOwed).toStringAsFixed(2)}';
    } else {
      return 'All settled up!';
    }
  }
}