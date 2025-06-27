import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:track_health_case/models/user.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  final String _baseUrl = 'https://health-case-tracker-backend.onrender.com/api';

  User? get user => _user;
  bool get isLoggedIn => _user != null;

  Future<void> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _user = User.fromJson(data);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(data));

      notifyListeners();
    } else {
      throw Exception('Login failed');
    }
  }

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('user')) return;

    final userData = jsonDecode(prefs.getString('user')!);
    _user = User.fromJson(userData);
    notifyListeners();
  }

  Future<void> logout() async {
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
