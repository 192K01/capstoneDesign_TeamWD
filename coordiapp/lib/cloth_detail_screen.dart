// 📂 lib/cloth_detail_screen.dart (최종 전체 코드)

import 'dart:io';
import 'dart:convert'; // http 통신 및 jsonEncode/Decode용
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // http 통신용
import 'package:shared_preferences/shared_preferences.dart'; // SharedPreferences 임포트

// (StatefulWidget 및 _ClothDetailScreenState 클래스 상단은 이전과 동일)
class ClothDetailScreen extends StatefulWidget {
  final Map<String, dynamic> cloth;

  const ClothDetailScreen({super.key, required this.cloth});

  @override
  State<ClothDetailScreen> createState() => _ClothDetailScreenState();
}

class _ClothDetailScreenState extends State<ClothDetailScreen> {
  // 'Discovery' 섹션을 위한 상태 변수
  List<Map<String, dynamic>> _discoveryOutfits = [];
  bool _isLoadingDiscovery = true;
  String _discoveryStatus = '이 옷이 포함된 코디를 찾는 중...';

  // 서버 IP 상수
  static const String serverIp = '3.36.66.130';
  static const String serverBaseUrl = 'http://$serverIp:5000';
  late String memo;
  late final dynamic clothId;
  

  @override
  void initState() {
    super.initState();
    // 화면이 로드될 때 'Discovery' 코디 목록 가져오기
    // 'memo' 키가 null이거나 비어있을 경우를 모두 처리
    memo = widget.cloth['memo'] ?? '메모가 없어요. 클릭하여 수정할 수 있어요.';
    if (memo.isEmpty) {
      memo = '메모가 없어요. 클릭하여 수정할 수 있어요.';
    }
    clothId = widget.cloth['cloth_id'];
    _fetchDiscoveryOutfits();
  }

  // 'Discovery' 코디 목록을 가져오는 함수 (서버에서 outfits 로드 후 필터링)
  Future<void> _fetchDiscoveryOutfits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('userEmail');
      if (userEmail == null) {
        throw Exception('로그인 정보 없음');
      }

      // 현재 옷의 ID
      final currentClothId = widget.cloth['cloth_id'];
      if (currentClothId == null) {
        throw Exception('현재 옷 ID 정보 없음');
      }

      // 서버에서 사용자의 '모든' 코디 목록을 가져옴 (GET /outfits/<email>)
      final uri = Uri.parse('$serverBaseUrl/outfits/$userEmail');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> allOutfits = jsonDecode(
          utf8.decode(response.bodyBytes),
        );

        // 클라이언트 측에서 '현재 옷이 포함된' 코디만 필터링
        final List<Map<String, dynamic>> filteredOutfits = allOutfits
            .where((outfit) {
              final topId =
                  (outfit['top'] as Map<String, dynamic>?)?['cloth_id'];
              final bottomId =
                  (outfit['bottom'] as Map<String, dynamic>?)?['cloth_id'];
              final shoesId =
                  (outfit['shoes'] as Map<String, dynamic>?)?['cloth_id'];

              // 현재 옷의 ID와 일치하는 것이 하나라도 있는지 확인
              return topId == currentClothId ||
                  bottomId == currentClothId ||
                  shoesId == currentClothId;
            })
            .map((outfit) => outfit as Map<String, dynamic>)
            .toList();

        if (mounted) {
          setState(() {
            _discoveryOutfits = filteredOutfits;
            _isLoadingDiscovery = false;
            if (filteredOutfits.isEmpty) {
              _discoveryStatus = '이 옷이 포함된 저장된 코디가 없습니다.';
            }
          });
        }
      } else {
        throw Exception('서버에서 코디 목록 로드 실패');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDiscovery = false;
          _discoveryStatus = '코디를 불러오는 중 오류 발생: $e';
        });
      }
    }
  }

  /// 옷 삭제 함수
  Future<void> _deleteCloth(BuildContext context) async {
    // StatefulWidget이므로 'widget.cloth'로 접근
    final clothId = widget.cloth['cloth_id'];

    if (clothId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('삭제 오류: 옷 ID를 찾을 수 없습니다.')));
      return; // ID가 없으면 함수 종료
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
      // serverBaseUrl 상수 사용
      final uri = Uri.parse('$serverBaseUrl/clothes/$clothId');
      final response = await http.delete(uri);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('옷이 삭제되었습니다.')));
        // 화면을 닫고 profile_screen에 true를 반환하여 새로고침 신호 보냄
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
    // StatefulWidget이므로 'widget.cloth'로 접근
    // (데이터 추출 로직은 이전과 동일)
    final String imagePath = widget.cloth['clothingImg'] ?? '';
    final String name = widget.cloth['name'] ?? '이름 없음';
    final String subCategory = widget.cloth['subCategory'] ?? '분류 없음';
    final String articleType = widget.cloth['articleType'] ?? '종류 없음';
    final String color = widget.cloth['color'] ?? '색상 없음';
//     final String memo = widget.cloth['memo'] ?? '메모가 없어요. 클릭하여 수정할 수 있어요.';

    

    // --- ▼▼▼ [추가] 메모 플레이스홀더 여부 확인 ▼▼▼ ---
    const String defaultMemo = '메모가 없어요. 클릭하여 수정할 수 있어요.';
    final bool isPlaceholder = (memo == defaultMemo);
    // --- ▲▲▲ [추가] 메모 플레이스홀더 여부 확인 ▲▲▲ ---

    const String serverBaseUrl = 'http://3.36.66.130:5000';
    // [수정됨] 이미지 URL 생성 로직 (profile_screen.dart와 동일하게)
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
                        // [수정됨] FileImage -> NetworkImage로 변경
                        image: imageUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(imageUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      // [수정됨] imageUrl.isEmpty로 조건 변경
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
                // 오른쪽 옷 정보 (간소화된 버전)
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

            // [수정됨] Discovery 섹션 UI 변경
            const Text(
              'Discovery',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220, // main.dart와 높이 통일
              child: _isLoadingDiscovery
                  ? Center(
                      // 로딩 중
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 10),
                          Text(
                            _discoveryStatus,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : _discoveryOutfits.isEmpty
                  ? Center(
                      // 코디 없음
                      child: Text(
                        _discoveryStatus,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      // 코디 목록
                      scrollDirection: Axis.horizontal,
                      itemCount: _discoveryOutfits.length,
                      itemBuilder: (context, index) {
                        final outfitData = _discoveryOutfits[index];
                        // main.dart에서 가져온 위젯 사용
                        return RecommendedOutfitCard(outfitData: outfitData);
                      },
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

  // _buildDiscoveryItem 위젯은 삭제됨
}

// ▼▼▼ [추가됨] main.dart에서 복사해 온 'RecommendedOutfitCard' 위젯 ▼▼▼
class RecommendedOutfitCard extends StatelessWidget {
  final Map<String, dynamic> outfitData;
  const RecommendedOutfitCard({super.key, required this.outfitData});

  // (상수) main.dart와 동일한 서버 URL
  static const String serverBaseUrl = 'http://3.36.66.130:5000';

  @override
  Widget build(BuildContext context) {
    final topData = outfitData['top'] as Map<String, dynamic>?;
    final bottomData = outfitData['bottom'] as Map<String, dynamic>?;
    final shoesData = outfitData['shoes'] as Map<String, dynamic>?;

    return Container(
      width: 160, // main.dart의 추천 카드와 너비 통일
      margin: const EdgeInsets.only(right: 12.0),
      child: Card(
        elevation: 0,
        color: Colors.grey[200], // 카드 배경색
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // 자식들 꽉 채우기
          children: [
            // --- 상의 (1/2 높이) ---
            Expanded(
              flex: 2, // 비율 2
              child: _buildImage(topData),
            ),
            // --- 하의 (1/2 높이) ---
            Expanded(
              flex: 2, // 비율 2
              child: _buildImage(bottomData),
            ),
            // --- 신발 (1/1 높이) ---
            Expanded(
              flex: 1, // 비율 1 (더 작게)
              child: _buildImage(shoesData),
            ),
          ],
        ),
      ),
    );
  }

  // 이미지 위젯 생성 헬퍼 (contain 적용, 흰색 배경)
  Widget _buildImage(Map<String, dynamic>? itemData) {
    final imagePath = itemData?['clothingImg'] as String?;
    final bgColor = Colors.grey[200]; // 배경색을 카드의 grey[200]으로 통일

    if (itemData == null || imagePath == null || imagePath.isEmpty) {
      return Container(width: double.infinity, color: bgColor);
    }

    final imageUrl = imagePath.startsWith('http')
        ? imagePath
        : '$serverBaseUrl/$imagePath';
    return Container(
      width: double.infinity,
      color: bgColor,
      child: Image.network(
        imageUrl,
        fit: BoxFit.contain, // contain 적용
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        },
        errorBuilder: (context, error, stackTrace) {
          print("Image load error for $imageUrl: $error");
          return const Center(
            child: Icon(Icons.error_outline, color: Colors.grey),
          );
        },
      ),
    );
  }
}