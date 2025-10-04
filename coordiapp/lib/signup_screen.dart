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

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();

  String? _selectedGender;
  bool _isLoading = false;

  // --- ▼▼▼ 비밀번호 유효성 검사를 위한 상태 변수 추가 ▼▼▼ ---
  bool _isPasswordLengthOk = false;
  bool _hasLetter = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;
  bool _passwordsMatch = false;
  // --- ▲▲▲ 비밀번호 유효성 검사를 위한 상태 변수 추가 ▲▲▲ ---

  @override
  void initState() {
    super.initState();
    // 컨트롤러에 리스너 추가하여 입력 변경 감지
    _passwordController.addListener(_updatePasswordValidation);
    _confirmPasswordController.addListener(_updateConfirmPasswordValidation);
  }

  // 비밀번호 규칙 실시간 검사 함수
  void _updatePasswordValidation() {
    final password = _passwordController.text;
    setState(() {
      _isPasswordLengthOk = password.length >= 8;
      _hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
      _hasNumber = RegExp(r'[0-9]').hasMatch(password);
      _hasSpecialChar = RegExp(r'[!@#\$%\^&\*]').hasMatch(password);
    });
    // 비밀번호가 변경될 때마다 비밀번호 확인 필드도 다시 검사
    _updateConfirmPasswordValidation();
  }

  // 비밀번호 일치 여부 실시간 검사 함수
  void _updateConfirmPasswordValidation() {
    setState(() {
      _passwordsMatch =
          _passwordController.text.isNotEmpty &&
          _passwordController.text == _confirmPasswordController.text;
    });
  }

  Future<void> _handleSignup() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_passwordsMatch) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')));
      return;
    }
    // 모든 비밀번호 규칙이 충족되었는지 확인
    if (!(_isPasswordLengthOk && _hasLetter && _hasNumber && _hasSpecialChar)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호 규칙을 모두 만족해주세요.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      const serverIp = '3.36.66.130';
      final url = Uri.parse('http://$serverIp:5000/register');

      final Map<String, String?> userData = {
        'email': _emailController.text,
        'password': _passwordController.text,
        'name': _nameController.text,
        'gender': _selectedGender,
        'birth_date': _birthDateController.text,
        'phone_number': _phoneNumberController.text,
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );

      if (mounted) {
        final responseData = jsonDecode(response.body);
        final message = responseData['message'];

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
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
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _birthDateController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  // --- ▼▼▼ 유효성 검사 결과를 보여줄 위젯 추가 ▼▼▼ ---
  Widget _buildValidationRow(String text, bool isValid) {
    return Row(
      children: [
        Icon(
          isValid ? Icons.check_circle : Icons.check_circle_outline,
          color: isValid ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(color: isValid ? Colors.green : Colors.red),
        ),
      ],
    );
  }
  // --- ▲▲▲ 유효성 검사 결과를 보여줄 위젯 추가 ▲▲▲ ---

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
                  // validator는 제출 시에만 동작하므로 실시간 UI는 리스너로 처리
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '비밀번호를 입력하세요.';
                    }
                    if (!(_isPasswordLengthOk &&
                        _hasLetter &&
                        _hasNumber &&
                        _hasSpecialChar)) {
                      return '비밀번호 규칙을 모두 만족해주세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // --- ▼▼▼ 비밀번호 규칙 UI 표시 ▼▼▼ ---
                _buildValidationRow('8자 이상', _isPasswordLengthOk),
                _buildValidationRow('영문 포함', _hasLetter),
                _buildValidationRow('숫자 포함', _hasNumber),
                _buildValidationRow('특수문자 포함', _hasSpecialChar),

                // --- ▲▲▲ 비밀번호 규칙 UI 표시 ▲▲▲ ---
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(labelText: '비밀번호 확인'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '비밀번호를 다시 입력하세요.';
                    }
                    if (value != _passwordController.text) {
                      return '비밀번호가 일치하지 않습니다.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // --- ▼▼▼ 비밀번호 일치 여부 UI 표시 ▼▼▼ ---
                Text(
                  _confirmPasswordController.text.isEmpty
                      ? '' // 확인 칸이 비어있으면 아무것도 표시하지 않음
                      : _passwordsMatch
                      ? '비밀번호가 일치합니다'
                      : '비밀번호가 일치하지 않습니다',
                  style: TextStyle(
                    color: _passwordsMatch ? Colors.green : Colors.red,
                  ),
                ),

                // --- ▲▲▲ 비밀번호 일치 여부 UI 표시 ▲▲▲ ---
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
                        value: 'M', // 서버 요구사항에 맞게 '남' -> 'M' 등으로 변경 가능
                        groupValue: _selectedGender,
                        onChanged: (value) =>
                            setState(() => _selectedGender = value),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('여'),
                        value: 'F', // 서버 요구사항에 맞게 '여' -> 'F' 등으로 변경 가능
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
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignup,
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
