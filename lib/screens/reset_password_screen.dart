// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ResetPasswordScreen extends StatefulWidget {
  final String userId;
  final String token;

  const ResetPasswordScreen({
    super.key,
    required this.userId,
    required this.token,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final newPasswordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();
  bool isLoading = false;
  bool passwordVisible = false;

  Future<void> resetPassword() async {
    if (newPasswordCtrl.text != confirmPasswordCtrl.text) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Passwords do not match')));
      return;
    }

    setState(() => isLoading = true);
    final url = Uri.parse('https://health-case-tracker-backend-o82a.onrender.com/api/users/reset-password');

    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': widget.userId,
          'token': widget.token,
          'newPassword': newPasswordCtrl.text,
        }),
      );

      setState(() => isLoading = false);
      final msg = jsonDecode(res.body)['message'] ?? 'Password reset';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

      if (res.statusCode == 200) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (_) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reset failed')));
    }
  }

  Widget buildPasswordField({
    required String label,
    required TextEditingController controller,
    bool isConfirm = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: !passwordVisible,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(isConfirm ? Icons.lock_outline : Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(passwordVisible ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => passwordVisible = !passwordVisible),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade800, Colors.teal.shade300],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 24),
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.95 * 255).toInt()),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(2, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_reset, size: 64, color: Colors.teal),
                  SizedBox(height: 24),
                  Text(
                    'Set New Password',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                    ),
                  ),
                  SizedBox(height: 24),
                  buildPasswordField(label: 'New Password', controller: newPasswordCtrl),
                  SizedBox(height: 16),
                  buildPasswordField(
                    label: 'Confirm Password',
                    controller: confirmPasswordCtrl,
                    isConfirm: true,
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isLoading ? null : resetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 50, vertical: 14),
                    ),
                    child: Text(isLoading ? 'Resetting...' : 'Reset Password'),
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
