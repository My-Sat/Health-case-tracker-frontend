// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'dashboard_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController usernameCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();

  bool _autoValidate = false;
  bool _passwordVisible = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      setState(() => _autoValidate = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the errors highlighted above.')),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isSubmitting = true);
    try {
      await auth.login(usernameCtrl.text.trim(), passwordCtrl.text);
      final role = auth.user?.role;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => role == 'admin' ? const HomeScreen() : const DashboardScreen(),
        ),
      );
    } catch (e) {
      final msg = (e.toString().trim().isNotEmpty) ? e.toString() : 'Login failed';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildInput({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String? Function(String?) validator,
    bool obscure = false,
    bool showToggle = false,
    VoidCallback? toggle,
    TextInputAction? textInputAction,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      autovalidateMode:
          _autoValidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: showToggle
            ? IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: toggle,
              )
            : null,
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
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.95 * 255).toInt()),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(2, 4),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                autovalidateMode:
                    _autoValidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_hospital, size: 64, color: Colors.teal),
                    const SizedBox(height: 24),

                    // Username
                    _buildInput(
                      label: 'Username',
                      icon: Icons.person,
                      controller: usernameCtrl,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Username is required';
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // Password
                    _buildInput(
                      label: 'Password',
                      icon: Icons.lock,
                      controller: passwordCtrl,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password is required';
                        return null;
                      },
                      obscure: !_passwordVisible,
                      showToggle: true,
                      toggle: () => setState(() => _passwordVisible = !_passwordVisible),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 24),

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 14),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Login'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Register
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RegisterScreen()),
                              );
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.teal.shade700,
                      ),
                      child: const Text("Don't have an account? Register now"),
                    ),

                    // Forgot password
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                              );
                            },
                      child: const Text('Forgot Password?'),
                    ),
                    const SizedBox(height: 12),
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
