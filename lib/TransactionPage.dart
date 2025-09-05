// lib/TransactionPage.dart
import 'package:flutter/material.dart';
import 'dataservice.dart';
import 'models/models.dart';

class TransactionPage extends StatefulWidget {
  final Friend friend;

  TransactionPage({required this.friend});

  @override
  _TransactionPageState createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  final DataService _dataService = DataService();
  final TextEditingController _amountController = TextEditingController();

  // Static dropdown options
  final List<String> _descriptionOptions = [
    'Bhavani',
    'Bajarang',
    'Ravi',
    'Dmart',
    'Reliance Fresh',
    'Petrol',
    'Pizza',
  ];

  String? _selectedDescription;

  // Method to calculate current balance from transactions
  double _calculateBalance(List<Transaction> transactions) {
    double balance = 0;
    for (var transaction in transactions) {
      if (transaction.type == 'settlement') {
        // For settlements, if current user paid, they received money (positive)
        // If friend paid, current user gave money (negative)
        if (transaction.paidBy == _dataService.currentUserId) {
          balance += transaction.amount;
        }
        else {
        balance -= transaction.amount;
      }
    } else {
    // For expenses, if current user paid, friend owes them (positive)
    // If friend paid, current user owes friend (negative)
    if (transaction.paidBy == _dataService.currentUserId) {
    balance += transaction.amount; // Assuming split equally
    } else {
    balance -= transaction.amount; // Assuming split equally
    }
    }
  }
    return balance;
  }
  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friend.name),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Transaction>>(
        stream: _dataService.getTransactionsStream(widget.friend.id),
        builder: (context, snapshot) {
          final transactions = snapshot.data ?? [];
          final currentBalance = _calculateBalance(transactions);

          return Column(
            children: [
              // Balance Summary - Now updates dynamically
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.blue.shade100],
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.friend.avatar,
                      style: TextStyle(fontSize: 30),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _getBalanceText(currentBalance),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _getBalanceColor(currentBalance),
                      ),
                    ),
                  ],
                ),
              ),

              // Add Transaction Section
              Padding(
                padding: EdgeInsets.all(10),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedDescription,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      items: _descriptionOptions.map((String description) {
                        return DropdownMenuItem<String>(
                          value: description,
                          child: Text(description),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedDescription = newValue;
                        });
                      },
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount (₹)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _addTransaction(_dataService.currentUserId, 'expense'),
                            icon: Icon(Icons.add),
                            label: Text('I Paid'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _addTransaction(widget.friend.id, 'expense'),
                            icon: Icon(Icons.add),
                            label: Text('${widget.friend.name.split(' ')[0]} Paid'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showSettlementDialog(currentBalance),
                      icon: Icon(Icons.account_balance_wallet),
                      label: Text('Settle Up'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 40),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(),

              // Transaction History
              Expanded(
                child: _buildTransactionsList(snapshot),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTransactionsList(AsyncSnapshot<List<Transaction>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('Error loading transactions'),
          ],
        ),
      );
    }

    final transactions = snapshot.data ?? [];

    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[transactions.length - 1 - index];
        return _buildTransactionTile(transaction);
      },
    );
  }

  Widget _buildTransactionTile(Transaction transaction) {
    final isCurrentUserPayer = transaction.paidBy == _dataService.currentUserId;
    final paidByName = isCurrentUserPayer ? 'You' : widget.friend.name.split(' ')[0];

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: transaction.type == 'settlement'
              ? Colors.blue.shade100
              : (isCurrentUserPayer ? Colors.green.shade100 : Colors.orange.shade100),
          child: Icon(
            transaction.type == 'settlement'
                ? Icons.account_balance_wallet
                : Icons.receipt,
            color: transaction.type == 'settlement'
                ? Colors.blue
                : (isCurrentUserPayer ? Colors.green : Colors.orange),
          ),
        ),
        title: Text(transaction.description),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paid by $paidByName'),
            Text(
              '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '₹${transaction.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                if (value == 'delete') {
                  _showDeleteConfirmationDialog(transaction);
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

    void _addTransaction(String paidBy, String type) {
      if (_selectedDescription == null || _selectedDescription!.isEmpty || _amountController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please fill all fields')),
        );
        return;
      }

      final amount = double.tryParse(_amountController.text);
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a valid amount')),
        );
        return;
      }

      final transaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        description: _selectedDescription!,
        amount: amount,
        paidBy: paidBy,
        date: DateTime.now(),
        type: type,
      );

      _dataService.addTransaction(widget.friend.id, transaction);

    // _loadFCMToken();
      setState(() {
        _selectedDescription = null;
      });
      _amountController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transaction added successfully')),
      );
    }
  // Future<void> _loadFCMToken() async {
  //   String? token = await _dataService.getCurrentUserFCMToken();
  //   setState(() {
  //     _fcmToken  = token;
  //   });
  // }
  void _showSettlementDialog(double currentBalance) {
    if (currentBalance == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Already settled up!')),
      );
      return;
    }

    final amountController = TextEditingController(
      text: currentBalance.abs().toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Settle Up'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentBalance > 0
                  ? '${widget.friend.name} owes you ₹${currentBalance.abs().toStringAsFixed(2)}'
                  : 'You owe ${widget.friend.name} ₹${currentBalance.abs().toStringAsFixed(2)}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Settlement Amount',
                border: OutlineInputBorder(),
                prefixText: '₹',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                final paidBy = currentBalance > 0 ? widget.friend.id : _dataService.currentUserId;
                final transaction = Transaction(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  description: 'Settlement',
                  amount: amount,
                  paidBy: paidBy,
                  date: DateTime.now(),
                  type: 'settlement',
                );

                _dataService.addTransaction(widget.friend.id, transaction);
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Settlement recorded')),
                );
              }
            },
            child: Text('Settle'),
          ),
        ],
      ),
    );
  }

  String _getBalanceText(double balance) {
    if (balance > 0) {
      return ' Take ₹${balance.abs().toStringAsFixed(2)} From ${widget.friend.name.split(' ')[0]}';
    } else if (balance < 0) {
      return ' Give ₹${balance.abs().toStringAsFixed(2)} To ${widget.friend.name.split(' ')[0]}';
    } else {
      return 'All settled up! 🎉';
    }
  }

  Color _getBalanceColor(double balance) {
    if (balance > 0) {
      return Colors.green;
    } else if (balance < 0) {
      return Colors.red;
    } else {
      return Colors.blue;
    }
  }

  void _showDeleteConfirmationDialog(Transaction transaction) {
    final isCurrentUserPayer = transaction.paidBy == _dataService.currentUserId;
    final paidByName = isCurrentUserPayer ? 'You' : widget.friend.name.split(' ')[0];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Delete Transaction'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete this transaction?'),
              SizedBox(height: 12),
              Container(
                width: 280,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text('Paid by $paidByName'),
                    Text('Amount: ₹${transaction.amount.toStringAsFixed(2)}'),
                    Text(
                      '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Text(
                'This action cannot be undone.',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteTransaction(transaction);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Deleting transaction...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Delete the transaction
      await _dataService.deleteTransaction(widget.friend.id, transaction.id);

      // Show success message
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Transaction deleted successfully'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text('Failed to delete transaction'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}