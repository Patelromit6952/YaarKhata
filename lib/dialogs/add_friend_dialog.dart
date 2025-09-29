import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../dataservice.dart';

class AddFriendDialog {
  static void show(BuildContext context, DataService dataService) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final avatars = ['👤', '👨', '👩', '👦', '👧', '🧑', '👶', '🧓'];

    showDialog(
      context: context,
      builder: (context) => _AddFriendDialogWidget(
        nameController: nameController,
        phoneController: phoneController,
        avatars: avatars,
        dataService: dataService,
      ),
    );
  }
}

class _AddFriendDialogWidget extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final List<String> avatars;
  final DataService dataService;

  const _AddFriendDialogWidget({
    required this.nameController,
    required this.phoneController,
    required this.avatars,
    required this.dataService,
  });

  @override
  _AddFriendDialogWidgetState createState() => _AddFriendDialogWidgetState();
}

class _AddFriendDialogWidgetState extends State<_AddFriendDialogWidget>
    with SingleTickerProviderStateMixin {
  String selectedAvatar = '👤';
  bool isLoading = false;
  late AnimationController scaleController;
  late Animation<double> scaleAnimation;

  @override
  void initState() {
    super.initState();
    scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: Colors.white,
      title: Row(
        children: [
          Icon(Icons.person_add, color: Colors.blue.shade700),
          SizedBox(width: 12),
          Text(
            'Add Friend',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
              fontSize: 20,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNameField(),
            SizedBox(height: 16),
            _buildPhoneField(),
            SizedBox(height: 20),
            _buildAvatarSelector(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: isLoading ? Colors.grey : Colors.blue.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: isLoading ? null : _addFriend,
          style: ElevatedButton.styleFrom(
            backgroundColor: isLoading ? Colors.grey : Colors.blue.shade700,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            elevation: 2,
          ),
          child: isLoading
              ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : Text(
            'Add Friend',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: widget.nameController,
      enabled: !isLoading,
      decoration: InputDecoration(
        labelText: 'Friend Name',
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
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        prefixIcon: Icon(Icons.person, color: isLoading ? Colors.grey : Colors.blue.shade700),
        fillColor: isLoading ? Colors.grey.shade100 : Colors.blue.shade50,
        filled: true,
      ),
      cursorColor: Colors.blue.shade700,
      textCapitalization: TextCapitalization.words,
    );
  }

  Widget _buildPhoneField() {
    return TextField(
      controller: widget.phoneController,
      enabled: !isLoading,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      decoration: InputDecoration(
        labelText: 'Phone Number (Optional)',
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
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        prefixIcon: Icon(Icons.phone, color: isLoading ? Colors.grey : Colors.blue.shade700),
        prefixText: '+91 ',
        prefixStyle: TextStyle(color: isLoading ? Colors.grey : Colors.blue.shade700),
        hintText: '9876543210',
        hintStyle: TextStyle(color: Colors.blue.shade400),
        fillColor: isLoading ? Colors.grey.shade100 : Colors.blue.shade50,
        filled: true,
      ),
      cursorColor: Colors.blue.shade700,
    );
  }

  Widget _buildAvatarSelector() {
    return Column(
      children: [
        Text(
          'Choose Avatar:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isLoading ? Colors.grey : Colors.blue.shade900,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 12),
        Container(
          width: double.maxFinite,
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: widget.avatars.map((avatar) => GestureDetector(
              onTap: () {
                if (!isLoading) {
                  setState(() {
                    selectedAvatar = avatar;
                  });
                  scaleController.forward().then((_) => scaleController.reverse());
                  HapticFeedback.selectionClick();
                }
              },
              child: AnimatedBuilder(
                animation: scaleAnimation,
                builder: (context, child) {
                  bool isSelected = selectedAvatar == avatar;
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    transform: Matrix4.identity()
                      ..scale(isSelected ? scaleAnimation.value : 1.0),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? Colors.blue.shade100
                          : (isLoading ? Colors.grey.shade200 : Colors.blue.shade50),
                      border: Border.all(
                        color: isSelected
                            ? Colors.blue.shade700
                            : (isLoading ? Colors.grey.shade300 : Colors.blue.shade200),
                        width: isSelected ? 3 : 2,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: Colors.blue.shade300.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                            offset: Offset(0, 2),
                          ),
                        BoxShadow(
                          color: (isLoading ? Colors.grey : Colors.blue).shade100.withOpacity(0.2),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: AnimatedDefaultTextStyle(
                      duration: Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: isSelected ? 26 : 24,
                        color: isLoading ? Colors.grey : null,
                      ),
                      child: Text(avatar),
                    ),
                  );
                },
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _addFriend() async {
    String name = widget.nameController.text.trim();
    String phone = widget.phoneController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a name'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      String friendPhone = phone.isNotEmpty
          ? phone
          : 'temp_${DateTime.now().millisecondsSinceEpoch}';

      await widget.dataService.addFriend(friendPhone, name, selectedAvatar);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('$name added successfully!'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(milliseconds: 2000),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Failed to add friend: $e')),
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
    }
  }
}