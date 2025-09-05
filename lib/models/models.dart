// lib/models/models.dart
class Friend {
  final String id;
  final String name;
  final String avatar;
  double balance;

  Friend({
    required this.id,
    required this.name,
    required this.avatar,
    this.balance = 0.0,
  });
}

class Transaction {
  final String id;
  final String description;
  final double amount;
  final String paidBy; // friend id who paid
  final DateTime date;
  final String type; // 'expense' or 'settlement'

  Transaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.date,
    required this.type,
  });
}