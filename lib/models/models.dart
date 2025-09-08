// lib/models/models.dart
import 'package:hive/hive.dart';

part 'models.g.dart'; // This will be generated

@HiveType(typeId: 0)
class Friend extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String avatar;

  @HiveField(3)
  double balance;

  Friend({
    required this.id,
    required this.name,
    required this.avatar,
    this.balance = 0.0,
  });

  // Optional: Add convenience methods for JSON serialization if needed
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatar': avatar,
    'balance': balance,
  };

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
    id: json['id'],
    name: json['name'],
    avatar: json['avatar'],
    balance: json['balance']?.toDouble() ?? 0.0,
  );

  // Optional: Override toString for debugging
  @override
  String toString() {
    return 'Friend{id: $id, name: $name, avatar: $avatar, balance: $balance}';
  }

  // Optional: Implement equality operators
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Friend && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

@HiveType(typeId: 1)
class Transaction extends HiveObject {
  @HiveField(0)
  late final String id;

  @HiveField(1)
  final String description;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final String paidBy; // friend id who paid

  @HiveField(4)
  final DateTime date;

  @HiveField(5)
  final String type; // 'expense' or 'settlement'

  @HiveField(6)
  final String? createdBy;

  Transaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.date,
    required this.type,
    required this.createdBy
  });

  // Optional: Add convenience methods for JSON serialization if needed
  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'amount': amount,
    'paidBy': paidBy,
    'date': date.toIso8601String(),
    'type': type,
    'createdBy':createdBy
  };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'],
    description: json['description'],
    amount: json['amount']?.toDouble() ?? 0.0,
    paidBy: json['paidBy'],
    date: DateTime.parse(json['date']),
    type: json['type'],
    createdBy: json['createdBy']
  );

  // Optional: Override toString for debugging
  @override
  String toString() {
    return 'Transaction{id: $id, description: $description, amount: $amount, paidBy: $paidBy, date: $date, type: $type,createdBy:$createdBy}';
  }

  // Optional: Implement equality operators
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Transaction && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Optional: Add helper methods
  bool get isExpense => type == 'expense';
  bool get isSettlement => type == 'settlement';
}