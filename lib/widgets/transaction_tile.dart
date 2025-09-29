import 'package:flutter/material.dart';
import '../models/models.dart';

class TransactionUtils {
  static double calculateBalance(List<Transaction> transactions, String currentUserId) {
    double balance = 0;
    for (var transaction in transactions) {
      // UNIFIED LOGIC: All transactions work the same way
      // Settlement transactions are just regular transactions that happen to settle debt
      if (transaction.paidBy == currentUserId) {
        balance += transaction.amount; // You paid = friend owes you more
      } else {
        balance -= transaction.amount; // Friend paid = you owe friend more
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