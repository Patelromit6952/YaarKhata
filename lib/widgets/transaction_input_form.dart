import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../dataservice.dart';
import '../models/models.dart';

class TransactionInputForm extends StatefulWidget {
  final Friend friend;
  final DataService dataService;
  final VoidCallback onAddTransaction;
  final VoidCallback onSettle;

  TransactionInputForm({
    required this.friend,
    required this.dataService,
    required this.onAddTransaction,
    required this.onSettle,
  });

  @override
  _TransactionInputFormState createState() => _TransactionInputFormState();
}

class _TransactionInputFormState extends State<TransactionInputForm> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _customDescriptionController = TextEditingController();
  String? _selectedDescription;
  bool _isCustomDescriptionSelected = false;
  DateTime _selectedDate = DateTime.now();

  final List<String> _descriptionOptions = [
    'Bhavani',
    'Bajarang',
    'Ravi',
    'Padika',
    'Dmart',
    'Reliance Fresh',
    'Petrol',
    'Pizza',
    'Bunkar-Dunkar',
    'Gayatri',
    'other things'
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _customDescriptionController.dispose();
    super.dispose();
  }

  void _showCustomDescriptionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Icon(Icons.edit, color: Colors.blue.shade700),
              SizedBox(width: 12),
              Text(
                'Custom Description',
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
                'Enter a custom description for this transaction:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.blue.shade700,
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _customDescriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
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
                  prefixIcon: Icon(Icons.description, color: Colors.blue.shade700),
                  fillColor: Colors.blue.shade50,
                  filled: true,
                  hintText: 'Enter description...',
                  hintStyle: TextStyle(color: Colors.blue.shade400),
                ),
                cursorColor: Colors.blue.shade700,
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _customDescriptionController.clear();
                Navigator.pop(context);
              },
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
                if (_customDescriptionController.text.trim().isNotEmpty) {
                  setState(() {
                    _selectedDescription = _customDescriptionController.text.trim();
                    _isCustomDescriptionSelected = true;
                  });
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Please enter a description'),
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
                'Save',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
              surface: Colors.blue.shade50,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _addTransaction(String paidBy, String type) {
    if (_selectedDescription == null || _selectedDescription!.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Text('Please fill all fields'),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
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
      return;
    }

    HapticFeedback.lightImpact();
    final transaction = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      description: _selectedDescription!,
      amount: amount,
      paidBy: paidBy,
      date: _selectedDate,
      type: type,
      createdBy: widget.dataService.currentUserId
    );

    widget.dataService.addTransaction(widget.friend.id, transaction);
    setState(() {
      _selectedDescription = null;
      _isCustomDescriptionSelected = false;
      _customDescriptionController.clear();
      _amountController.clear();
      _selectedDate = DateTime.now();
    });
    widget.onAddTransaction();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Transaction added successfully'),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _isCustomDescriptionSelected
              ? Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue.shade200),
              borderRadius: BorderRadius.circular(12),
              color: Colors.blue.shade50,
            ),
            child: Row(
              children: [
                Icon(Icons.description, color: Colors.blue.shade700),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Custom Description',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _selectedDescription ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedDescription = null;
                      _isCustomDescriptionSelected = false;
                      _customDescriptionController.clear();
                    });
                  },
                  icon: Icon(Icons.close, color: Colors.blue.shade700),
                  tooltip: 'Clear custom description',
                ),
              ],
            ),
          )
              : DropdownButtonFormField<String>(
            value: _selectedDescription,
            hint: Text(
              'Select description',
              style: TextStyle(color: Colors.blue.shade400),
            ),
            decoration: InputDecoration(
              labelText: 'Description',
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
              prefixIcon: Icon(Icons.description, color: Colors.blue.shade700),
              fillColor: Colors.blue.shade50,
              filled: true,
            ),
            items: _descriptionOptions.map((String description) {
              return DropdownMenuItem<String>(
                value: description,
                child: Text(
                  description,
                  style: TextStyle(color: Colors.blue.shade900),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue == 'other things') {
                _showCustomDescriptionDialog();
              } else {
                setState(() {
                  _selectedDescription = newValue;
                  _isCustomDescriptionSelected = false;
                });
              }
            },
          ),
          SizedBox(height: 16),
          GestureDetector(
            onTap: () => _selectDate(context),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date',
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
                prefixIcon: Icon(Icons.calendar_today, color: Colors.blue.shade700),
                fillColor: Colors.blue.shade50,
                filled: true,
              ),
              child: Text(
                DateFormat('dd/MM/yyyy').format(_selectedDate),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.blue.shade900,
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Amount (₹)',
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
              prefixIcon: Icon(Icons.currency_rupee, color: Colors.blue.shade700),
              fillColor: Colors.blue.shade50,
              filled: true,
            ),
            cursorColor: Colors.blue.shade700,
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _addTransaction(widget.dataService.currentUserId, 'expense'),
                  icon: Icon(Icons.add, color: Colors.white),
                  label: Text(
                    'I Paid',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _addTransaction(widget.friend.id, 'expense'),
                  icon: Icon(Icons.add, color: Colors.white),
                  label: Text(
                    '${widget.friend.name.split(' ')[0]} Paid',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: widget.onSettle,
            icon: Icon(Icons.account_balance_wallet, color: Colors.white),
            label: Text(
              'Settle Up',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }
}