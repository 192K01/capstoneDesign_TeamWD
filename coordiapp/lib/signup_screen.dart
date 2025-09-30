// lib/signup_screen.dart

import 'dart:convert'; // JSON 인코딩을 위해 import
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http; // HTTP 통신을 위해 import
import 'package:intl/intl.dart';

class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (newText.length > 11) {
      return oldValue;
    }
    String formattedText = '';
    if (newText.length < 4) {
      formattedText = newText;
    } else if (newText.length < 8) {
      formattedText = '${newText.substring(0, 3)}-${newText.substring(3)}';
    } else {
      formattedText =
          '${newText.substring(0, 3)}-${newText.substring(3, 7)}-${newText.substring(7)}';
    }
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  // 1. ▼▼▼ 각 입력 필드의 값을 가져오기 위한 컨트롤러 선언 ▼▼▼
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();

  String? _selectedGender;
  bool _isLoading = false; // 로딩 상태를 위한 변수

  // 2. ▼▼▼ 회원가입 버튼을 눌렀을 때 서버와 통신하는 함수 ▼▼▼
  Future<void> _handleSignup() async {
    // 모든 입력 필드의 유효성 검사
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // 비밀번호와 비밀번호 확인이 일치하는지 검사
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')));
      return;
    }

    setState(() => _isLoading = true); // 로딩 시작

    try {
      // EC2 서버의 IP 주소
      const serverIp = '3.36.66.130';
      final url = Uri.parse('http://$serverIp:5000/register');

      // 서버로 보낼 데이터를 Map 형태로 구성
      final Map<String, String?> userData = {
        'email': _emailController.text,
        'password': _passwordController.text,
        'name': _nameController.text,
        'gender': _selectedGender,
        'birth_date': _birthDateController.text,
        'phone_number': _phoneNumberController.text,
      };

      // HTTP POST 요청 보내기
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );

      if (mounted) {
        // 서버로부터 받은 응답을 JSON으로 파싱
        final responseData = jsonDecode(response.body);
        final message = responseData['message'];

        if (response.statusCode == 200) {
          // 성공
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
          Navigator.of(context).pop(); // 회원가입 성공 시 로그인 화면으로 돌아가기
        } else {
          // 실패 (예: 이메일 중복 등)
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
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false); // 로딩 종료
    }
  }

  // ... 나머지 함수들 (_validatePassword, _selectDate 등)은 그대로 유지 ...
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return '비밀번호를 입력하세요.';
    String pattern = r'^(?=.*[a-z])(?=.*[0-9])(?=.*[!@#\$%\^&\*])(?=.{8,})';
    RegExp regExp = RegExp(pattern);
    if (!regExp.hasMatch(value)) return '소문자, 숫자, 특수문자를 포함하여 8자리 이상 입력해주세요.';
    return null;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  void dispose() {
    // 컨트롤러 메모리 해제
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _birthDateController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 3. ▼▼▼ 각 TextFormField에 컨트롤러 연결 ▼▼▼
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: '아이디 (이메일 주소)'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) =>
                      (value?.isEmpty ?? true) ? '이메일을 입력하세요.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: '비밀번호'),
                  obscureText: true,
                  validator: _validatePassword,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(labelText: '비밀번호 확인'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return '비밀번호를 다시 입력하세요.';
                    if (value != _passwordController.text)
                      return '비밀번호가 일치하지 않습니다.';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '이름'),
                  validator: (value) =>
                      (value?.isEmpty ?? true) ? '이름을 입력하세요.' : null,
                ),
                const SizedBox(height: 24),
                const Text(
                  '성별',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('남'),
                        value: '남',
                        groupValue: _selectedGender,
                        onChanged: (value) =>
                            setState(() => _selectedGender = value),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('여'),
                        value: '여',
                        groupValue: _selectedGender,
                        onChanged: (value) =>
                            setState(() => _selectedGender = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _birthDateController,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: '생년월일'),
                  onTap: () => _selectDate(context),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneNumberController,
                  decoration: const InputDecoration(labelText: '휴대폰 번호'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    PhoneNumberFormatter(),
                  ],
                ),
                const SizedBox(height: 32),
                // 4. ▼▼▼ 회원가입 버튼 클릭 시 _handleSignup 함수 호출 ▼▼▼
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : _handleSignup, // 로딩 중에는 버튼 비활성화
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text('회원가입', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
