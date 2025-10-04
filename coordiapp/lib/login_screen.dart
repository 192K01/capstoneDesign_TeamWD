import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart'; // MainScreen으로 이동하기 위해 import
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
  bool _isLoading = false; // 로딩 상태를 위한 변수

  // ▼▼▼ 서버와 통신하여 로그인을 처리하는 함수 ▼▼▼
  Future<void> _handleLogin() async {
    // 이메일 또는 비밀번호가 비어있는지 확인
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이메일과 비밀번호를 모두 입력해주세요.')));
      return;
    }

    setState(() => _isLoading = true); // 로딩 시작

    try {
      // EC2 서버의 IP 주소와 로그인 엔드포인트
      const serverIp = '3.36.66.130';
      final url = Uri.parse('http://$serverIp:5000/login');

      // 서버로 보낼 데이터를 Map 형태로 구성
      final Map<String, String> loginData = {
        'email': _emailController.text,
        'password': _passwordController.text,
      };

      // HTTP POST 요청 보내기
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(loginData),
      );

      if (mounted) {
        // 서버로부터 받은 응답을 JSON으로 파싱
        final responseData = jsonDecode(response.body);

        if (response.statusCode == 200) {
          final message = responseData['message'];
          final userName = responseData['userName'];
          // 로그인 성공 시
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true); // 로그인 상태 저장
          await prefs.setString('userEmail', _emailController.text);
          await prefs.setString('userName', userName);

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
          // MainScreen으로 이동하고 이전 화면(로그인 화면)은 스택에서 제거
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        } else {
          final message = responseData['message'];
          // 로그인 실패 시 (예: 아이디 없음, 비밀번호 틀림 등)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      // 네트워크 오류 등 예외 발생 시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false); // 로딩 종료
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
                'CodiApp',
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
                onPressed: _isLoading ? null : _handleLogin, // 로딩 중에는 버튼 비활성화
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black, // 버튼 색상
                  foregroundColor: Colors.white, // 글자 색상
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        // 로딩 중일 때 인디케이터 표시
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text('로그인', style: TextStyle(fontSize: 16)),
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
                onPressed: _isLoading ? null : _handleLogin, // 임시로 일반 로그인 함수 연결
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
                onPressed: _isLoading ? null : _handleLogin, // 임시로 일반 로그인 함수 연결
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
