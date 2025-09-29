import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:friendsbook/dataservice.dart';
import 'package:friendsbook/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class AddTransactionPage extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String paidById;
  final String paidByName;
  final double currentBalance;
  final String transactionType;
  final Transaction? editingTransaction;
  final bool isEditing;

  const AddTransactionPage({
    required this.friendId,
    required this.friendName,
    required this.paidById,
    required this.paidByName,
    required this.currentBalance,
    required this.transactionType,
    this.editingTransaction,
    this.isEditing = false,
    super.key,
  });

  @override
  _AddTransactionPageState createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> with TickerProviderStateMixin {
  final DataService _dataService = DataService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedDescription;
  List<String> _customDescriptions = [];
  List<Friend> _allFriends = [];
  Set<String> _selectedFriendsForMultiple = {};
  bool _isLoading = false;
  bool _isLoadingFriends = false;
  bool _isCustomInput = false;
  bool _showMultipleFriendsOption = false;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  StreamSubscription<List<Friend>>? _friendsSubscription;

  final List<String> _staticDescriptions = [
    // Add your default static descriptions here
  ];

  @override
  void initState() {
    super.initState();
    _debugFriends();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    _loadCustomDescriptions();
    _loadAllFriends();

    if (widget.isEditing && widget.editingTransaction != null) {
      _amountController.text = widget.editingTransaction!.amount.toStringAsFixed(2);
      _descriptionController.text = widget.editingTransaction!.description;
      _selectedDescription = widget.editingTransaction!.description;
      _isCustomInput = false;
      if (!_customDescriptions.contains(_selectedDescription)) {
        _customDescriptions.add(_selectedDescription!);
        _saveCustomDescriptions();
      }
    }
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _descriptionController.dispose();
    _scaleController.dispose();
    _friendsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAllFriends() async {
    if (mounted) {
      setState(() {
        _isLoadingFriends = true;
      });
    }

    try {
      // Cancel any existing subscription
      await _friendsSubscription?.cancel();

      _friendsSubscription = _dataService.getLocalFriends().listen(
            (friends) {
          if (mounted) {
            setState(() {
              _allFriends = friends.where((friend) => friend.id != widget.friendId).toList();
              _isLoadingFriends = false;
              print('Loaded ${_allFriends.length} friends: ${_allFriends.map((f) => f.name).toList()}');
            });
          }
        },
        onError: (error) {
          print('Error in friends stream: $error');
          if (mounted) {
            setState(() {
              _isLoadingFriends = false;
            });
            _showErrorSnackBar('Error loading friends: $error');
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      print('Error setting up friends stream: $e');
      if (mounted) {
        setState(() {
          _isLoadingFriends = false;
        });
        _showErrorSnackBar('Error loading friends: $e');
      }
    }
  }

  // Debug method to test DataService
  Future<void> _debugFriends() async {
    try {
      print('Testing DataService...');
      final stream = _dataService.getFriendsStream();
      stream.listen((friends) {
        print('DataService returned ${friends.length} friends');
        for (var friend in friends) {
          print('Friend: ${friend.name} (ID: ${friend.id})');
        }
      });
    } catch (e) {
      print('DataService error: $e');
    }
  }

  Future<void> _loadCustomDescriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDescriptions = prefs.getStringList('custom_descriptions');
    setState(() {
      if (savedDescriptions == null || savedDescriptions.isEmpty) {
        _customDescriptions = List.from(_staticDescriptions);
        _saveCustomDescriptions();
      } else {
        _customDescriptions = savedDescriptions;
      }
    });
  }

  Future<void> _saveCustomDescriptions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('custom_descriptions', _customDescriptions);
  }

  void _onAmountChanged() {
    setState(() {
      _enteredAmount = double.tryParse(_amountController.text) ?? 0.0;
    });
  }

  double _enteredAmount = 0.0;

  Future<void> _addTransaction() async {
    if (_descriptionController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter a description');
      return;
    }

    if (_amountController.text.isEmpty) {
      _showErrorSnackBar('Please enter an amount');
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showErrorSnackBar('Please enter a valid amount greater than 0');
      return;
    }

    setState(() {
      _isLoading = true;
    });
    HapticFeedback.lightImpact();

    try {
      final description = _descriptionController.text.trim();

      final transaction = Transaction(
          id: widget.isEditing
              ? widget.editingTransaction!.id
              : DateTime.now().millisecondsSinceEpoch.toString(),
          description: description,
          amount: amount,
          paidBy: widget.paidById,
          date: _selectedDate,
          type: widget.transactionType,
          createdBy: _dataService.currentUserId
      );

      if (widget.isEditing) {
        final temp = await _dataService.updateTransaction(widget.friendId, transaction);

        if (temp) {
          _showSuccessSnackBar('Transaction updated successfully');
        } else {
          _showErrorSnackBar('You Don\'t have access');
        }
      } else {
        // Add transaction to primary friend (now returns immediately after local save)
        await _dataService.addTransaction(widget.friendId, transaction);

        // Add transaction to selected multiple friends if any
        if (_selectedFriendsForMultiple.isNotEmpty) {
          // Process multiple friends in parallel for better performance
          final List<Future<void>> addTransactionFutures = [];

          for (String friendId in _selectedFriendsForMultiple) {
            final multipleTransaction = Transaction(
                id: DateTime.now().millisecondsSinceEpoch.toString() + friendId,
                description: description,
                amount: amount,
                paidBy: widget.paidById,
                date: _selectedDate,
                type: widget.transactionType,
                createdBy: _dataService.currentUserId
            );
            addTransactionFutures.add(_dataService.addTransaction(friendId, multipleTransaction));
          }

          // Wait for all local additions to complete
          await Future.wait(addTransactionFutures);

          _showSuccessSnackBar('Transaction added to ${_selectedFriendsForMultiple.length + 1} friends successfully');
        } else {
          _showSuccessSnackBar('Transaction added successfully');
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error ${widget.isEditing ? 'updating' : 'adding'} transaction: $e');
      _showErrorSnackBar('Error ${widget.isEditing ? 'updating' : 'adding'} transaction: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }

  String get _displayBalance {
    if (_enteredAmount == 0.0) {
      return '₹0';
    }
    return '₹${_enteredAmount.toStringAsFixed(0)}';
  }

  String get _titleText {
    if (widget.isEditing) {
      return 'Edit Transaction';
    } else if (widget.transactionType == 'user_paid') {
      return 'You paid $_displayBalance for ${widget.friendName}';
    } else {
      return '${widget.friendName} paid $_displayBalance for you';
    }
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
              surface: Colors.white,
              onSurface: Colors.black,
            ),
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
    HapticFeedback.selectionClick();
  }

  String _formatDate(DateTime date) {
    String day = date.day.toString().padLeft(2, '0');
    String month = date.month.toString().padLeft(2, '0');
    String year = date.year.toString().substring(2);
    return '$day ${_getMonthName(date.month)} $year';
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  void _saveDescriptionAsStatic() {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      _showErrorSnackBar('Please enter a description to save');
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Save Description', style: TextStyle(color: Color(0xFF1976D2))),
          content: Text('Do you want to save "$description" for future use?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            TextButton(
              onPressed: () {
                if (!_customDescriptions.contains(description)) {
                  setState(() {
                    _customDescriptions.add(description);
                    _saveCustomDescriptions();
                  });
                  _showSuccessSnackBar('Description saved for future use');
                } else {
                  _showErrorSnackBar('Description already saved');
                }
                Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(color: Color(0xFF1976D2))),
            ),
          ],
        );
      },
    );
  }

  void _showMultipleFriendsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text(
                'Add to Multiple Friends',
                style: TextStyle(color: Color(0xFF1976D2)),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: Column(
                  children: [
                    Text(
                      'Select friends to add this transaction:',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _isLoadingFriends
                          ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF1976D2)),
                            SizedBox(height: 16),
                            Text('Loading friends...'),
                          ],
                        ),
                      )
                          : _allFriends.isEmpty
                          ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No friends found',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                _loadAllFriends();
                                _debugFriends(); // Call debug method
                              },
                              child: const Text('Retry', style: TextStyle(color: Color(0xFF1976D2))),
                            ),
                          ],
                        ),
                      )
                          : ListView.builder(
                        itemCount: _allFriends.length,
                        itemBuilder: (context, index) {
                          final friend = _allFriends[index];
                          final isSelected = _selectedFriendsForMultiple.contains(friend.id);
                          return CheckboxListTile(
                            title: Text(friend.name),
                            value: isSelected,
                            activeColor: Colors.blue.shade700,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  _selectedFriendsForMultiple.add(friend.id);
                                } else {
                                  _selectedFriendsForMultiple.remove(friend.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedFriendsForMultiple.clear();
                    });
                    Navigator.pop(context);
                  },
                  child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {});
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Done (${_selectedFriendsForMultiple.length})',
                    style: const TextStyle(color: Color(0xFF1976D2)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.blue.shade50,
          appBar: AppBar(
            backgroundColor: Colors.blue.shade50,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.blue),
              onPressed: _isLoading
                  ? null
                  : () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
            ),
            title: Text(
              _titleText,
              style: const TextStyle(
                color: Color(0xFF1976D2),
                fontSize: 23,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              if (_isCustomInput)
                IconButton(
                  icon: const Icon(Icons.bookmark_add, color: Color(0xFF1976D2)),
                  onPressed: _isLoading ? null : _saveDescriptionAsStatic,
                  tooltip: 'Save description for future use',
                ),
              if (!widget.isEditing)
                IconButton(
                  icon: Icon(
                    Icons.group_add,
                    color: _selectedFriendsForMultiple.isEmpty
                        ? const Color(0xFF1976D2)
                        : Colors.green.shade600,
                  ),
                  onPressed: _isLoading ? null : _showMultipleFriendsDialog,
                  tooltip: 'Add to multiple friends',
                ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Selected Friends Display
                if (_selectedFriendsForMultiple.isNotEmpty && !widget.isEditing)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.group, color: Colors.green.shade600, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Adding to ${_selectedFriendsForMultiple.length + 1} friends:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Chip(
                              label: Text(widget.friendName),
                              backgroundColor: Colors.blue.shade100,
                              labelStyle: const TextStyle(fontSize: 12),
                            ),
                            ..._selectedFriendsForMultiple.map((friendId) {
                              final friend = _allFriends.firstWhere((f) => f.id == friendId);
                              return Chip(
                                label: Text(friend.name),
                                backgroundColor: Colors.green.shade100,
                                labelStyle: const TextStyle(fontSize: 12),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () {
                                  setState(() {
                                    _selectedFriendsForMultiple.remove(friendId);
                                  });
                                },
                              );
                            }).toList(),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (_selectedFriendsForMultiple.isNotEmpty && !widget.isEditing)
                  const SizedBox(height: 16),
                // Amount Display Section
                AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _amountController.text.isNotEmpty ? _scaleAnimation.value : 1.0,
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          child: TextField(
                            controller: _amountController,
                            enabled: !_isLoading,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1976D2),
                            ),
                            decoration: InputDecoration(
                              prefixText: '₹',
                              prefixStyle: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1976D2),
                              ),
                              hintText: '0',
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            onTap: () => _scaleController.forward().then((_) => _scaleController.reverse()),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Description Input (Dropdown or TextField)
                AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _descriptionController.text.isNotEmpty ? _scaleAnimation.value : 1.0,
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _isCustomInput
                            ? Column(
                          children: [
                            TextField(
                              controller: _descriptionController,
                              enabled: !_isLoading,
                              decoration: InputDecoration(
                                hintText: 'Enter details (Items, bill no., quantity, etc.)',
                                border: InputBorder.none,
                                hintStyle: TextStyle(color: Colors.grey[600]),
                              ),
                              style: TextStyle(color: Colors.grey[800]),
                              maxLength: 50,
                              onTap: () => _scaleController.forward().then((_) => _scaleController.reverse()),
                            ),
                          ],
                        )
                            : DropdownButtonFormField<String>(
                          value: _selectedDescription != null &&
                              _customDescriptions.contains(_selectedDescription)
                              ? _selectedDescription
                              : null,
                          decoration: InputDecoration(
                            hintText: 'Select or enter details',
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.grey[600]),
                          ),
                          dropdownColor: Colors.white,
                          items: [
                            ..._customDescriptions.map((String description) {
                              return DropdownMenuItem<String>(
                                value: description,
                                child: Text(
                                  description,
                                  style: TextStyle(color: Colors.grey[800]),
                                ),
                              );
                            }),
                            const DropdownMenuItem<String>(
                              value: 'custom',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 16, color: Color(0xFF1976D2)),
                                  SizedBox(width: 8),
                                  Text(
                                    'Enter Custom',
                                    style: TextStyle(color: Color(0xFF1976D2)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          onChanged: _isLoading
                              ? null
                              : (String? newValue) {
                            setState(() {
                              if (newValue == 'custom') {
                                _isCustomInput = true;
                                _selectedDescription = null;
                                _descriptionController.clear();
                              } else {
                                _isCustomInput = false;
                                _selectedDescription = newValue;
                                _descriptionController.text = newValue!;
                              }
                              _scaleController.forward().then((_) => _scaleController.reverse());
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Date Selection
                AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: GestureDetector(
                          onTap: _isLoading ? null : () => _selectDate(context),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, color: Color(0xFF1976D2), size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  _formatDate(_selectedDate),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                // Save Button
                AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                            _scaleController.forward().then((_) => _scaleController.reverse());
                            _addTransaction();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : Text(
                            widget.isEditing ? 'UPDATE' : 'SAVE',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        // Full-screen loading overlay
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.2),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const CircularProgressIndicator(
                  color: Color(0xFF1976D2),
                  strokeWidth: 3,
                ),
              ),
            ),
          ),
      ],
    );
  }
}