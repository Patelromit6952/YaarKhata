import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dataservice.dart';
import 'FriendsListPage.dart';

class LoginRegisterPage extends StatefulWidget {
  const LoginRegisterPage({super.key});

  @override
  _LoginRegisterPageState createState() => _LoginRegisterPageState();
}

class _LoginRegisterPageState extends State<LoginRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isRegistering = true;
  bool _showOTP = false;
  String? _verificationId;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your name';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    String cleanPhone = value.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.length != 10) {
      return 'Please enter a valid 10-digit phone number';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validateOTP(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter the OTP';
    }
    if (value.length != 6) {
      return 'OTP must be 6 digits';
    }
    return null;
  }

  Future<void> _handleSubmitEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final phone = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
      final email = _emailController.text.trim();

      // Check if phone is registered (for login) or not registered (for registration)
      bool isRegistered = await DataService().isPhoneNumberRegistered(phone);

      if (_isRegistering && isRegistered) {
        _showErrorMessage('Phone number already registered. Please use login instead.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (!_isRegistering && !isRegistered) {
        _showErrorMessage('Phone number not registered. Please register first.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      await DataService().sendOTP(
        email,
            (verificationId) {
          setState(() {
            _showOTP = true;
            _verificationId = verificationId;
            _isLoading = false;
          });
        },
            (error) {
          _showErrorMessage(error);
          setState(() {
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      _showErrorMessage('Error: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSubmitOTP() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final phone = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
      final email = _emailController.text.trim();
      final otp = _otpController.text.trim();

      bool success = false;

      if (_isRegistering) {
        final name = _nameController.text.trim();
        await DataService().registerUserWithOTP(phone, name, email, _verificationId ?? '', otp);
        success = true;
      } else {
        await DataService().loginUserWithOTP(phone, email, _verificationId ?? '', otp);
        success = true;
      }

      if (success) {
        _showSuccessMessage(_isRegistering ? 'Registration successful!' : 'Login successful!');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => FriendsListPage()),
          );
        }
      }
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11);
      }
      _showErrorMessage(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _switchMode() {
    setState(() {
      _isRegistering = !_isRegistering;
      _showOTP = false;
      _otpController.clear();
      _emailController.clear();
      _phoneController.clear();
      _verificationId = null;
    });
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade600,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade400, Colors.blue.shade800],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      size: 50,
                      color: Colors.blue.shade600,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Friends Transaction',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Track expenses with friends easily',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 50),
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Mode Switcher (Register/Login)
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (!_isRegistering) {
                                      setState(() {
                                        _isRegistering = true;
                                        _showOTP = false;
                                        _otpController.clear();
                                        _emailController.clear();
                                        _phoneController.clear();
                                        _verificationId = null;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _isRegistering
                                          ? Colors.blue.shade600
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Register',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _isRegistering
                                            ? Colors.white
                                            : Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (_isRegistering) {
                                      setState(() {
                                        _isRegistering = false;
                                        _showOTP = false;
                                        _otpController.clear();
                                        _emailController.clear();
                                        _phoneController.clear();
                                        _verificationId = null;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: !_isRegistering
                                          ? Colors.blue.shade600
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Login',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: !_isRegistering
                                            ? Colors.white
                                            : Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),

                          // Name field (only for registration)
                          if (!_showOTP && _isRegistering) ...[
                            TextFormField(
                              controller: _nameController,
                              validator: _validateName,
                              cursorColor: Colors.blue.shade600,
                              decoration: InputDecoration(
                                labelText: 'Full Name',
                                labelStyle: TextStyle(color: Colors.blue.shade600),
                                prefixIcon: Icon(Icons.person_outline, color: Colors.blue.shade600),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.blue.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.blue.shade300),
                                ),
                              ),
                              textCapitalization: TextCapitalization.words,
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Email field (for both registration and login)
                          if (!_showOTP) ...[
                            TextFormField(
                              controller: _emailController,
                              validator: _validateEmail,
                              keyboardType: TextInputType.emailAddress,
                              cursorColor: Colors.blue.shade600,
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                labelStyle: TextStyle(color: Colors.blue.shade600),
                                prefixIcon: Icon(Icons.email_outlined, color: Colors.blue.shade600),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.blue.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.blue.shade300),
                                ),
                                hintText: 'example@domain.com',
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Phone field (for both registration and login)
                          if (!_showOTP) ...[
                            TextFormField(
                              controller: _phoneController,
                              validator: _validatePhone,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              cursorColor: Colors.blue.shade600,
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                labelStyle: TextStyle(color: Colors.blue.shade600),
                                prefixIcon: Icon(Icons.phone_outlined, color: Colors.blue.shade600),
                                prefixText: '+91 ',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.blue.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.blue.shade300),
                                ),
                                hintText: '9876543210',
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Send OTP Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleSubmitEmail,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                                    : const Text(
                                  'Send OTP to Email',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],

                          // OTP field and verification
                          if (_showOTP) ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: _otpController,
                                  validator: _validateOTP,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(6),
                                  ],
                                  cursorColor: Colors.blue.shade600,
                                  decoration: InputDecoration(
                                    labelText: 'Enter OTP',
                                    labelStyle: TextStyle(color: Colors.blue.shade600),
                                    prefixIcon: Icon(Icons.lock_outline, color: Colors.blue.shade600),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.blue.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.blue.shade300),
                                    ),
                                    hintText: '123456',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    letterSpacing: 4,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Verify OTP Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleSubmitOTP,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade600,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                        : Text(
                                      _isRegistering ? 'Register' : 'Login',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Your data is stored securely and never shared',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}