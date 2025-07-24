// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'reset_password_screen.dart';

class VerifyResetCodeScreen extends StatefulWidget {
  final String userId;
  const VerifyResetCodeScreen({super.key, required this.userId});

  @override
  State<VerifyResetCodeScreen> createState() => _VerifyResetCodeScreenState();
}

class _VerifyResetCodeScreenState extends State<VerifyResetCodeScreen> {
  final codeCtrl = TextEditingController();
  bool isLoading = false;

  Future<void> verifyCode() async {
    setState(() => isLoading = true);
    final url = Uri.parse('http://172.20.10.3:5000/api/users/verify-reset-code');

    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': widget.userId, 'code': codeCtrl.text}),
      );

      setState(() => isLoading = false);
      if (res.statusCode == 200) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(userId: widget.userId, token: codeCtrl.text),
          ),
        );
      } else {
        final msg = jsonDecode(res.body)['message'] ?? 'Code verification failed';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error verifying code')));
    }
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
              ),
              child: Column(
                children: [
                  Icon(Icons.verified_user, size: 64, color: Colors.teal),
                  SizedBox(height: 16),
                  Text('Enter the code sent to your email', style: TextStyle(fontSize: 18)),
                  SizedBox(height: 24),
                  TextField(
                    controller: codeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '6-digit Code',
                      prefixIcon: Icon(Icons.password),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isLoading ? null : verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 50, vertical: 14),
                    ),
                    child: Text(isLoading ? 'Verifying...' : 'Verify'),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
