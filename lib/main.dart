import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'providers/auth_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _determineStartScreen(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.tryAutoLogin();
    if (!auth.isLoggedIn) return LoginScreen();
    return auth.user!.role == 'admin' ? HomeScreen() : DashboardScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Case Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal),
      home: FutureBuilder<Widget>(
        future: _determineStartScreen(context),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          } else {
            return snapshot.data!;
          }
        },
      ),
    );
  }
}
