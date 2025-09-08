import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:friendsbook/AddtransactionPage.dart';
import 'package:friendsbook/widgets/skeleton_loading_widget.dart';
import 'package:intl/intl.dart';
import 'dataservice.dart';
import 'models/models.dart';
import 'widgets/dash_painter.dart';
import 'dialogs/delete_confirmation_dialog.dart';
import 'utils/transaction_utils.dart';
import 'dialogs/settlement_dialog.dart';
import 'widgets/skeleton_loading_widget.dart'; // Import SkeletonLoadingWidget

class TransactionPage extends StatefulWidget {
  final Friend friend;

  const TransactionPage({required this.friend, super.key});

  @override
  _TransactionPageState createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  final DataService _dataService = DataService();

  void _showSettlementDialog(double currentBalance) {
    SettlementDialog.show(
      context: context,
      currentBalance: currentBalance,
      friend: widget.friend,
      dataService: _dataService,
      onSettled: () => setState(() {}),
    );
  }

  void _refreshTransactions() {
    setState(() {});
  }

  Future<void> _navigateToAddTransaction({
    required String friendId,
    required String friendName,
    required String paidById,
    required String paidByName,
    required double currentBalance,
    required String transactionType,
  }) async {
    HapticFeedback.lightImpact();
    await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) => AddTransactionPage(
          friendId: friendId,
          friendName: friendName,
          paidById: paidById,
          paidByName: paidByName,
          currentBalance: currentBalance,
          transactionType: transactionType,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0); // Slide from bottom
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          // Slide transition
          var slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var slideAnimation = animation.drive(slideTween);

          // Fade transition
          var fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));
          var fadeAnimation = animation.drive(fadeTween);

          // Scale transition
          var scaleTween = Tween<double>(begin: 0.8, end: 1.0).chain(CurveTween(curve: curve));
          var scaleAnimation = animation.drive(scaleTween);

          return SlideTransition(
            position: slideAnimation,
            child: FadeTransition(
              opacity: fadeAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: child,
              ),
            ),
          );
        },
      ),
    ).then((result) {
      if (result == true) _refreshTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade700, Colors.blue.shade900],
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade100,
              ),
              child: Text(
                widget.friend.avatar,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              widget.friend.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<Stream<List<Transaction>>>(
        future: _dataService.getTransactionsStream(widget.friend.id),
        builder: (context, futureSnapshot) {
          if (futureSnapshot.connectionState == ConnectionState.waiting) {
            return const SkeletonLoadingWidget(itemCount: 3); // Use skeleton for FutureBuilder
          }
          if (futureSnapshot.hasError) {
            return Center(child: Text('Error: ${futureSnapshot.error}'));
          }
          if (!futureSnapshot.hasData) {
            return const Center(child: Text('No data available'));
          }

          final stream = futureSnapshot.data!;

          return StreamBuilder<List<Transaction>>(
            stream: stream,
            builder: (context, snapshot) {
              final transactions = snapshot.data ?? [];
              final currentBalance = TransactionUtils.calculateBalance(
                transactions,
                _dataService.currentUserId,
              );

              return Column(
                children: [
                  _buildBalanceDisplay(currentBalance),
                  Expanded(child: _buildTransactionsList(snapshot)),
                  Divider(color: Colors.blue.shade200, thickness: 1),
                  _buildActionButtons(currentBalance),
                  const SizedBox(height: 15),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBalanceDisplay(double currentBalance) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade50, Colors.blue.shade100],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            currentBalance > 0
                ? 'Take ₹${currentBalance.abs().toStringAsFixed(2)} from ${widget.friend.name}'
                : currentBalance < 0
                ? 'Give ₹${currentBalance.abs().toStringAsFixed(2)} to ${widget.friend.name}'
                : 'All settled up!',
            style: TextStyle(
              fontSize:22 ,
              fontWeight: FontWeight.bold,
              color: TransactionUtils.getBalanceColor(currentBalance),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(AsyncSnapshot<List<Transaction>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const SkeletonLoadingWidget(itemCount: 3); // Use skeleton for StreamBuilder
    }

    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade600),
            const SizedBox(height: 16),
            Text('Error loading transactions: ${snapshot.error}'),
            ElevatedButton(
              onPressed: () => setState(() {}),
              child: const Text('Retry'),
            ),
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
            Icon(Icons.receipt_long, size: 48, color: Colors.blue.shade600),
            const SizedBox(height: 16),
            const Text(
              'No transactions yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    transactions.sort((a, b) => b.date.compareTo(a.date));

    List<Widget> listItems = [];
    String? previousDateString;

    for (int i = 0; i < transactions.length; i++) {
      final transaction = transactions[i];
      final currentDateString = DateFormat('yyyy-MM-dd').format(transaction.date);

      if (previousDateString != currentDateString) {
        listItems.add(_buildDateHeader(transaction.date));
        previousDateString = currentDateString;
      }

      final isUserPaid = transaction.paidBy == _dataService.currentUserId;

      listItems.add(
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isUserPaid ? Colors.green.shade100 : Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isUserPaid ? Icons.arrow_upward : Icons.arrow_downward,
                color: isUserPaid ? Colors.green.shade700 : Colors.orange.shade700,
              ),
            ),
            title: Text(
              transaction.description,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              DateFormat('MMM dd, yyyy • hh:mm a').format(transaction.date),
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${transaction.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isUserPaid ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
                Text(
                  isUserPaid ? 'You paid' : '${widget.friend.name.split(' ')[0]} paid',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            onLongPress: () => _showTransactionOptions(transaction),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: listItems,
    );
  }

  Widget _buildDateHeader(DateTime date) {
    String dateText = DateFormat('dd-MM-yyyy').format(date);

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 20),
              painter: DashPainter(),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              dateText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade700,
              ),
            ),
          ),
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 20),
              painter: DashPainter(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(double currentBalance) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _navigateToAddTransaction(
                friendId: widget.friend.id,
                friendName: widget.friend.name,
                paidById: _dataService.currentUserId,
                paidByName: _dataService.currentUserName,
                currentBalance: currentBalance,
                transactionType: 'user_paid',
              ),
              icon: const Icon(Icons.account_balance_wallet, size: 20),
              label: const Text('I paid'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _navigateToAddTransaction(
                friendId: widget.friend.id,
                friendName: widget.friend.name,
                paidById: widget.friend.id,
                paidByName: widget.friend.name,
                currentBalance: currentBalance,
                transactionType: 'friend_paid',
              ),
              icon: const Icon(Icons.account_balance_wallet, size: 20),
              label: Text('${widget.friend.name.split(' ')[0]} Paid'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showSettlementDialog(currentBalance),
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text('Settle Up'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTransactionOptions(Transaction transaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final isUserPaid = transaction.paidBy == _dataService.currentUserId;
        final paidByName = isUserPaid ? 'You' : widget.friend.name.split(' ')[0];

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Amount: ₹${transaction.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    Text(
                      'Paid by: $paidByName',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    Text(
                      'Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(transaction.date)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _editTransaction(transaction);
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showDeleteConfirmationDialog(transaction);
                      },
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }

  // Replace the existing _editTransaction method with this:

  void _editTransaction(Transaction transaction) async {
    if(transaction.createdBy == _dataService.currentUserId){
      final isUserPaid = transaction.createdBy == _dataService.currentUserId;
      // Calculate current balance (you might need to get fresh transactions)
      final stream = await _dataService.getTransactionsStream(widget.friend.id);
      final transactions = await stream.first;
      final currentBalance = TransactionUtils.calculateBalance(
        transactions,
        _dataService.currentUserId,
      );

      HapticFeedback.lightImpact();
      await Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          reverseTransitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) => AddTransactionPage(
            friendId: widget.friend.id,
            friendName: widget.friend.name,
            paidById: transaction.paidBy,
            paidByName: isUserPaid ? _dataService.currentUserName : widget.friend.name,
            currentBalance: currentBalance,
            transactionType: isUserPaid ? 'user_paid' : 'friend_paid',
            // Add these parameters for editing:
            editingTransaction: transaction, // Pass the transaction to edit
            isEditing: true, // Flag to indicate we're editing
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;

            var slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var slideAnimation = animation.drive(slideTween);

            var fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));
            var fadeAnimation = animation.drive(fadeTween);

            var scaleTween = Tween<double>(begin: 0.8, end: 1.0).chain(CurveTween(curve: curve));
            var scaleAnimation = animation.drive(scaleTween);

            return SlideTransition(
              position: slideAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: ScaleTransition(
                  scale: scaleAnimation,
                  child: child,
                ),
              ),
            );
          },
        ),
      ).then((result) {
        if (result == true) _refreshTransactions();
      });
    }
    else{
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You Don't have access to update"),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  void _showDeleteConfirmationDialog(Transaction transaction) {
    if(transaction.createdBy == _dataService.currentUserId){
      DeleteConfirmationDialog.show(
        context: context,
        transaction: transaction,
        friend: widget.friend,
        dataService: _dataService,
        onDeleted: () => _refreshTransactions(),
      );
    }
    else{
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You Don't have access to update"),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
}

class DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.shade300
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 5;
    const dashSpace = 3;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}