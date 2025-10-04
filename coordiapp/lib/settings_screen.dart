import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart'; // 로그인 화면으로 돌아가기 위해 import

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // 로그아웃 로직을 처리하는 함수
  Future<void> _logout(BuildContext context) async {
    // 저장된 로그인 상태를 삭제
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);

    // context가 여전히 유효한지 확인 후 화면 이동
    if (context.mounted) {
      // 로그인 화면으로 이동하고 이전의 모든 화면(경로)을 제거
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('설정', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                // 메뉴 항목들을 ListTile로 구현
                _buildSectionHeader('내 계정'),
                _buildMenuRow(Icons.person_outline, '계정정보'),
                _buildMenuRow(Icons.shield_outlined, '개인정보 변경'),
                _buildMenuRow(Icons.lock_outline, '비밀번호 변경'),
                _buildMenuRow(Icons.article_outlined, '옷 설문 변경'),

                _buildDivider(),
                _buildSectionHeader('앱 관리'),
                _buildMenuRow(Icons.notifications_outlined, '알림'),
                _buildMenuRow(Icons.calendar_today_outlined, '캘린더 설정'),
                _buildMenuRow(Icons.devices_other_outlined, '기기 권한'),
                _buildMenuRow(Icons.language_outlined, '언어'),

                _buildDivider(),
                _buildSectionHeader('지원'),
                _buildMenuRow(Icons.description_outlined, '이용약관'),
                _buildMenuRow(Icons.verified_user_outlined, '개인정보처리방침'),
                _buildMenuRow(Icons.business_center_outlined, '사업자정보'),
                _buildMenuRow(Icons.headset_mic_outlined, '고객센터'),
                _buildMenuRow(Icons.help_outline, '도움말'),
              ],
            ),
          ),
          // 하단 로그아웃 버튼 및 저작권
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                TextButton(
                  onPressed: () => _logout(context), // 로그아웃 함수 호출
                  child: const Text(
                    '로그아웃',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Copyright © Team WD. All rights reserved.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 각 메뉴 섹션의 헤더
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title, style: const TextStyle(color: Colors.grey)),
    );
  }

  // 각 메뉴 항목의 행
  Widget _buildMenuRow(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.black54),
      title: Text(title),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey,
      ),
      onTap: () {
        // 각 메뉴 항목 클릭 시 동작 (필요 시 구현)
      },
    );
  }

  // 섹션 구분선
  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      child: Divider(color: Color.fromARGB(255, 240, 240, 240), height: 30),
    );
  }
}
