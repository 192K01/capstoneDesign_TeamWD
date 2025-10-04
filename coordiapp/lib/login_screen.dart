import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart'; // MainScreen으로 이동하기 위해 import

//회원가입 관련
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 이메일과 비밀번호 입력을 관리하기 위한 컨트롤러
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // 로그인 성공 시 홈 화면으로 이동하는 함수
  Future<void> _loginAndNavigate() async {
    // 실제 앱에서는 여기서 이메일과 비밀번호가 맞는지 서버와 통신해야 합니다.
    // 지금은 로그인 버튼을 누르면 무조건 성공하는 것으로 가정합니다.

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          // 키보드가 올라올 때 화면이 깨지지 않도록 스크롤 가능하게 만듭니다.
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 50.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. 로고 (임시 텍스트)
              const Text(
                'coordiapp', // 어플 이름
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 48.0),

              // 2. 이메일 주소 입력 칸
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: '이메일 주소',
                  hintText: 'email@example.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
              ),
              const SizedBox(height: 12.0),

              // 3. 비밀번호 입력 칸
              TextField(
                controller: _passwordController,
                obscureText: true, // 비밀번호를 가려줍니다.
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
              ),
              const SizedBox(height: 24.0),

              // 4. 로그인 버튼
              ElevatedButton(
                onPressed: _loginAndNavigate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black, // 버튼 색상
                  foregroundColor: Colors.white, // 글자 색상
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: const Text('로그인', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16.0),

              // 5. 아이디 찾기, 비밀번호 찾기, 회원가입
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      '아이디 찾기',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                  const Text('|', style: TextStyle(color: Colors.black26)),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      '비밀번호 찾기',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                  const Text('|', style: TextStyle(color: Colors.black26)),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SignupScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      '회원가입',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24.0),

              // 6. 소셜 로그인 버튼들
              // 구글로 로그인하기
              ElevatedButton.icon(
                onPressed: _loginAndNavigate, // 임시로 홈으로 이동
                icon: const Icon(
                  Icons.g_mobiledata,
                  color: Colors.black,
                ), // 구글 아이콘으로 교체 필요
                label: const Text(
                  '구글로 로그인하기',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    side: const BorderSide(color: Colors.black26),
                  ),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 12.0),

              // 네이버로 로그인하기
              ElevatedButton.icon(
                onPressed: _loginAndNavigate, // 임시로 홈으로 이동
                icon: const Icon(
                  Icons.ac_unit,
                  color: Colors.white,
                ), // 네이버 아이콘으로 교체 필요
                label: const Text(
                  '네이버로 로그인하기',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF03C75A), // 네이버 초록색
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
