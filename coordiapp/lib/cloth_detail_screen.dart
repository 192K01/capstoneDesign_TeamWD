import 'dart:io';
import 'dart:convert'; // http 통신용
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // http 통신용
import 'package:shared_preferences/shared_preferences.dart';

class ClothDetailScreen extends StatelessWidget {
  final Map<String, dynamic> cloth;

  const ClothDetailScreen({super.key, required this.cloth});

  // 옷 삭제 함수
  Future<void> _deleteCloth(BuildContext context) async {
    final clothId = cloth['cloth_id'];
    // ▲▲▲ [수정됨] 'cloth_id' -> 'id'로 변경 ▲▲▲

    if (clothId == null) {
      // clothId가 없는 경우 오류 메시지 표시
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('삭제 오류: 옷 ID를 찾을 수 없습니다.')));
    }

    // 삭제 확인 다이얼로그 표시
    final bool? confirmed = await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('삭제 확인'),
          content: const Text('정말로 이 옷을 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false), // 취소
              child: const Text('아니요'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true), // 확인
              child: const Text('예'),
            ),
          ],
        );
      },
    );

    // 사용자가 '아니요'를 선택했거나 다이얼로그 밖을 탭한 경우
    if (confirmed != true) {
      return;
    }

    // 사용자가 '예'를 선택한 경우, 서버에 DELETE 요청 전송
    try {
      // profile_screen.dart에 정의된 서버 IP
      const String serverIp = '3.36.66.130';
      final uri = Uri.parse('http://$serverIp:5000/clothes/$clothId');

      final response = await http.delete(uri);

      if (response.statusCode == 200) {
        // 삭제 성공
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('옷이 삭제되었습니다.')));
        //         ScaffoldMessenger.of(context).showSnackBar(
        //           const SnackBar(content: Text('옷이 삭제되었습니다.')),
        //         );
        // 화면을 닫고 profile_screen에 true를 반환하여 새로고침 신호 보냄
        if (context.mounted) {
          Navigator.pop(context, true);
        }
      } else {
        // 서버 측 삭제 실패
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패 (서버 오류): ${response.body}')),
        );
      }
    } catch (e) {
      // 네트워크 오류 또는 기타 예외
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('삭제 중 오류 발생: $e')));
      //       ScaffoldMessenger.of(context).showSnackBar(
      //         SnackBar(content: Text('삭제 중 오류 발생: $e')),
      //       );
    }
  }

  @override
  Widget build(BuildContext context) {
    // cloth 맵에서 데이터를 추출합니다. 데이터가 null일 경우를 대비하여 기본값을 설정합니다.
    final String imagePath = cloth['clothingImg'] ?? '';
    final String name = cloth['name'] ?? '이름 없음';
    final String subCategory = cloth['subCategory'] ?? '분류 없음';
    final String articleType = cloth['articleType'] ?? '종류 없음';
    final String color = cloth['color'] ?? '색상 없음';
    final String memo = cloth['memo'] ?? '메모가 없어요. 클릭하여 수정할 수 있어요.';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // 뒤로가기 버튼 제거
        title: const Text(
          '옷 상세정보',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black),
            onPressed: () {},
          ),
          // onPressed에 _deleteCloth 함수 연결
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.black),
            onPressed: () => _deleteCloth(context),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 옷 이미지와 정보 섹션
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 왼쪽 옷 이미지
                Expanded(
                  flex: 2,
                  child: AspectRatio(
                    aspectRatio: 1 / 1.5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        image: imagePath.isNotEmpty
                            ? DecorationImage(
                                image: FileImage(File(imagePath)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: imagePath.isEmpty
                          ? const Center(
                              child: Icon(
                                Icons.checkroom,
                                size: 50,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // 오른쪽 옷 정보
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(Icons.label_outline, name),
                      _buildInfoRow(
                        Icons.category_outlined,
                        '$subCategory > $articleType',
                      ),
                      _buildInfoRow(Icons.color_lens_outlined, color),
                      _buildInfoRow(
                        Icons.calendar_today_outlined,
                        '24. 12. 17. 등록',
                      ), // 등록일은 예시 데이터입니다.
                      _buildInfoRow(
                        Icons.history,
                        '착용기록 4회',
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(memo),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 새로운 룩 생성하기 버튼
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_circle_outline, color: Colors.white),
              label: const Text(
                '이 옷으로 새로운 룩 생성하기',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 24),

            // Discovery 섹션
            const Text(
              'Discovery',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: List.generate(3, (index) => _buildDiscoveryItem()),
              ),
            ),
            const SizedBox(height: 24),

            // Review 섹션
            const Text(
              'Review',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ...List.generate(
                  4,
                  (index) =>
                      const Icon(Icons.star, color: Colors.amber, size: 28),
                ),
                const Icon(Icons.star_half, color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                const Text(
                  '4.5',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('좋았음.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // 옷 정보 행을 만드는 위젯
  Widget _buildInfoRow(IconData icon, String text, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black54),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // Discovery 아이템 위젯
  Widget _buildDiscoveryItem() {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.checkroom, color: Colors.white, size: 40),
      ),
    );
  }
}
