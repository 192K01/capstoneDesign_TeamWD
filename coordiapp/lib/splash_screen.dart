// 📂 lib/splash_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'main.dart'; // MainScreen을 가져오기 위해 import

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // 화면이 켜지고 잠시 후 _checkLoginStatus 함수를 실행
    Timer(const Duration(seconds: 3), _checkLoginStatus);
  }

  // --- ▼▼▼ [수정] 로그인 상태를 확인하고 화면을 이동시키는 함수 ▼▼▼ ---
  Future<void> _checkLoginStatus() async {
    // SharedPreferences를 이용해 저장된 로그인 상태를 불러옵니다.
    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (!mounted) return; // 위젯이 화면에 없으면 실행 중단

    // 로그인 상태에 따라 다른 화면으로 이동합니다.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        // isLoggedIn이 true이면 MainScreen으로, false이면 LoginScreen으로 이동
        builder: (context) =>
            isLoggedIn ? const MainScreen() : const LoginScreen(),
      ),
    );
  }
  // --- ▲▲▲ [수정] 로그인 상태를 확인하고 화면을 이동시키는 함수 ▲▲▲ ---

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'coordiapp',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 24),

            CircularProgressIndicator(color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
