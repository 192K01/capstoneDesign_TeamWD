import 'dart:io';
import 'dart:convert'; // http 통신 및 jsonEncode/Decode용
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // http 통신용
import 'package:shared_preferences/shared_preferences.dart';

// (StatefulWidget 및 _ClothDetailScreenState 클래스 상단은 이전과 동일)
class ClothDetailScreen extends StatefulWidget {
  final Map<String, dynamic> cloth;

  const ClothDetailScreen({super.key, required this.cloth});

  @override
  State<ClothDetailScreen> createState() => _ClothDetailScreenState();
}

class _ClothDetailScreenState extends State<ClothDetailScreen> {
  late String memo;
  late final dynamic clothId;
  final String serverIp = '3.36.66.130'; // 서버 IP

  @override
  void initState() {
    super.initState();
    // 'memo' 키가 null이거나 비어있을 경우를 모두 처리
    memo = widget.cloth['memo'] ?? '메모가 없어요. 클릭하여 수정할 수 있어요.';
    if (memo.isEmpty) {
      memo = '메모가 없어요. 클릭하여 수정할 수 있어요.';
    }
    clothId = widget.cloth['cloth_id'];
  }

  // (옷 삭제 _deleteCloth 함수는 이전과 동일)
  Future<void> _deleteCloth(BuildContext context) async {
    if (clothId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('삭제 오류: 옷 ID를 찾을 수 없습니다.')));
      return;
    }

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

    if (confirmed != true) {
      return;
    }

    try {
      final uri = Uri.parse('http://$serverIp:5000/clothes/$clothId');
      final response = await http.delete(uri);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('옷이 삭제되었습니다.')));
        if (context.mounted) {
          Navigator.pop(context, true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패 (서버 오류): ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('삭제 중 오류 발생: $e')));
    }
  }

  // (메모 수정 다이얼로그 _showEditMemoDialog 함수는 이전과 동일)
  Future<void> _showEditMemoDialog() async {
    // 다이얼로그가 열릴 때, 현재 메모가 플레이스홀더면 빈칸으로 시작
    const String defaultMemo = '메모가 없어요. 클릭하여 수정할 수 있어요.';
    final String currentText = (memo == defaultMemo) ? '' : memo;
    final TextEditingController memoController =
    TextEditingController(text: currentText);

    final String? newMemoText = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('메모 수정'),
          content: TextField(
            controller: memoController,
            autofocus: true,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '메모를 입력하세요...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), // 취소
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, memoController.text);
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    // '저장'을 눌렀고, 텍스트가 변경되었는지 확인
    if (newMemoText != null && newMemoText != memo) {
      // 만약 사용자가 다 지워서 빈 문자열로 저장하면, 다시 플레이스홀더로 설정
      if (newMemoText.isEmpty) {
        _updateMemoOnServer(
            ''); // 서버에는 빈 문자열 저장
        setState(() {
          memo = defaultMemo; // UI는 플레이스홀더로
        });
      } else {
        _updateMemoOnServer(newMemoText); // 서버에 새 텍스트 저장
      }
    }
  }

  // (서버 업데이트 _updateMemoOnServer 함수는 이전과 동일)
  Future<void> _updateMemoOnServer(String newMemo) async {
    if (clothId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오류: 옷 ID를 찾을 수 없습니다.')),
      );
      return;
    }

    try {
      final uri = Uri.parse('http://$serverIp:5000/clothes/$clothId');

      final response = await http.patch(
        uri,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        // 서버에는 실제 텍스트(비어있을 수도 있음)를 보냄
        body: jsonEncode({'memo': newMemo}),
      );

      if (response.statusCode == 200) {
        // 성공 시, 화면의 메모(상태)를 업데이트
        setState(() {
          if (newMemo.isEmpty) {
            memo = '메모가 없어요. 클릭하여 수정할 수 있어요.';
          } else {
            memo = newMemo;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('메모가 저장되었습니다.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패 (서버 오류): ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 중 오류 발생: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // (데이터 추출 로직은 이전과 동일)
    final String imagePath = widget.cloth['clothingImg'] ?? '';
    final String name = widget.cloth['name'] ?? '이름 없음';
    final String subCategory = widget.cloth['subCategory'] ?? '분류 없음';
    final String articleType = widget.cloth['articleType'] ?? '종류 없음';
    final String color = widget.cloth['color'] ?? '색상 없음';

    // --- ▼▼▼ [추가] 메모 플레이스홀더 여부 확인 ▼▼▼ ---
    const String defaultMemo = '메모가 없어요. 클릭하여 수정할 수 있어요.';
    final bool isPlaceholder = (memo == defaultMemo);
    // --- ▲▲▲ [추가] 메모 플레이스홀더 여부 확인 ▲▲▲ ---

    const String serverBaseUrl = 'http://3.36.66.130:5000';
    final String imageUrl = imagePath.isNotEmpty
        ? (imagePath.startsWith('http')
        ? imagePath
        : '$serverBaseUrl/$imagePath')
        : '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // (AppBar 설정은 이전과 동일)
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // (왼쪽 옷 이미지 부분은 이전과 동일)
                Expanded(
                  flex: 2,
                  child: AspectRatio(
                    aspectRatio: 1 / 1.5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        image: imageUrl.isNotEmpty
                            ? DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: imageUrl.isEmpty
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
                // (오른쪽 옷 정보)
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
                      const SizedBox(height: 8),

                      // --- ▼▼▼ [수정] 메모 UI 개선 ▼▼▼ ---
                      InkWell(
                        onTap: _showEditMemoDialog, // 탭하면 다이얼로그 표시
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white, // 1. 회색 배경 제거
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.grey[350]!), // 2. 옅은 테두리 추가
                          ),
                          child: Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start, // 상단 정렬
                            children: [
                              Expanded(
                                // 3. 텍스트 스타일 변경
                                child: Text(
                                  memo, // state 변수 memo 사용
                                  style: TextStyle(
                                    color: isPlaceholder
                                        ? Colors.black54
                                        : Colors.black,
                                    fontStyle: isPlaceholder
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 5. 수정 아이콘 추가
                              Icon(
                                Icons.edit_note_outlined, // 노트 수정 아이콘
                                size: 18,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // --- ▲▲▲ [수정] 메모 UI 개선 ▲▲▲ ---
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // (Discovery 섹션은 이전과 동일)
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
          ],
        ),
      ),
    );
  }

  // ( _buildInfoRow, _buildDiscoveryItem 위젯은 이전과 동일)
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