import 'package:flutter/material.dart';
import '../../services/email_service.dart';
import 'reset_password.dart';

class VerifyOTPScreen extends StatefulWidget {
  final String email;
  const VerifyOTPScreen({super.key, required this.email});

  @override
  State<VerifyOTPScreen> createState() => _VerifyOTPScreenState();
}

class _VerifyOTPScreenState extends State<VerifyOTPScreen> {
  final _otpController = TextEditingController();
  final _emailService = EmailService();
  bool _isLoading = false;

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter OTP'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final isValid = await _emailService.verifyOTP(widget.email, otp);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (isValid) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: widget.email)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid or expired OTP'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D47A1),
              Color(0xFF1565C0),
              Color(0xFF1976D2),
              Color(0xFF42A5F5),
              Color(0xFF90CAF9),
            ],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  children: [
                    Icon(Icons.verified_user, size: 80, color: Colors.white),
                    SizedBox(height: 24),
                    Text(
                      'Verify OTP',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Enter the 6-digit code sent to ${widget.email}',
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 40),
                    Container(
                      padding: EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 30,
                            offset: Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 24, letterSpacing: 8),
                            decoration: InputDecoration(
                              labelText: 'OTP Code',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                              counterText: '',
                            ),
                          ),
                          SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _verifyOTP,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF42A5F5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              child: _isLoading
                                  ? CircularProgressIndicator(color: Colors.white)
                                  : Text('Verify', style: TextStyle(fontSize: 16, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Back', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
