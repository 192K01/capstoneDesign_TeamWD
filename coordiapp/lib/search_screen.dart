import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SearchScreen extends StatefulWidget {
  // Key를 받을 수 있도록 수정
  const SearchScreen({Key? key}) : super(key: key);

  @override
  // State 클래스 이름을 공개로 변경
  SearchScreenState createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen>
    with WidgetsBindingObserver {
  // 상태 변수
  List<Map<String, dynamic>> _savedOutfits = []; // 서버에서 받아온 저장된 코디 목록
  bool _isLoading = true;
  String _selectedTpoFilter = '전체'; // 현재 선택된 TPO 필터

  // --- ▼▼▼ [추가됨] 코디 선택 관련 상태 변수 ▼▼▼ ---
  bool _isSelectionMode = false;
  Set<int> _selectedOutfitIds = {};
  // --- ▲▲▲ [추가됨] 코디 선택 관련 상태 변수 ▲▲▲ --

  // TPO 필터 옵션 정의 (UI 표시용 한국어, 서버 요청용 영어 매핑)
  final Map<String, String> _tpoFilterOptions = {
    '전체': '', // '전체'는 쿼리 파라미터 없이 요청
    '캐주얼': 'Casual & Daily',
    '포멀': 'Business & Formal',
    '특별한 날': 'Special Occasion & Date',
    '활동적인 날': 'Active Day',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchSavedOutfits(); // 화면 로드 시 전체 코디 목록 불러오기
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 앱 상태 변경 감지 (화면 다시 활성화 시 새로고침)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchSavedOutfits();
    }
  }

  // 서버에서 저장된 코디 목록을 가져오는 함수
  Future<void> _fetchSavedOutfits() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('userEmail');
      if (userEmail == null) {
        throw Exception('로그인 정보 없음'); // 로그인 안되어 있으면 오류 발생
      }

      const String serverIp = '3.36.66.130';
      String apiUrl = 'http://$serverIp:5000/outfits/$userEmail'; // 기본 API URL

      // 선택된 필터가 '전체'가 아니면 쿼리 파라미터 추가
      if (_selectedTpoFilter != '전체' &&
          _tpoFilterOptions.containsKey(_selectedTpoFilter)) {
        final tpoQueryParam = Uri.encodeComponent(
          _tpoFilterOptions[_selectedTpoFilter]!,
        );
        apiUrl += '?tpo=$tpoQueryParam';
      }
      print("Fetching outfits from: $apiUrl"); // 요청 URL 로그

      final uri = Uri.parse(apiUrl);
      final response = await http.get(uri);

      if (mounted) {
        if (response.statusCode == 200) {
          final List<dynamic> results = jsonDecode(
            utf8.decode(response.bodyBytes),
          );
          setState(() {
            _savedOutfits = results.cast<Map<String, dynamic>>();
          });
        } else {
          // 서버 오류 처리
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          print(
            "Failed to load outfits: ${response.statusCode}, ${errorData['message']}",
          );
          setState(() {
            _savedOutfits = []; // 오류 시 빈 목록
            // 사용자에게 오류 메시지 표시 (예: SnackBar)
          });
        }
      }
    } catch (e) {
      print("Error fetching saved outfits: $e");
      if (mounted) {
        setState(() {
          _savedOutfits = []; // 오류 시 빈 목록
          // 사용자에게 오류 메시지 표시
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // performSearch 함수는 SearchScreen에서는 더 이상 사용하지 않음 (main.dart 호출 대비용)
  Future<void> performSearch() async {
    _fetchSavedOutfits(); // ProfileScreen의 옷 목록 로드 함수 호출
  }

  // --- ▼▼▼ [추가됨] 코디 선택/해제 토글 함수 ▼▼▼ ---
  void _toggleSelection(int outfitId) {
    setState(() {
      if (_selectedOutfitIds.contains(outfitId)) {
        _selectedOutfitIds.remove(outfitId);
      } else {
        _selectedOutfitIds.add(outfitId);
      }
      // 선택된 항목이 1개 이상이면 선택 모드 유지, 0개면 선택 모드 해제
      _isSelectionMode = _selectedOutfitIds.isNotEmpty;
    });
  }
  // --- ▲▲▲ [추가됨] 코디 선택/해제 토글 함수 ▲▲▲ ---

  // --- ▼▼▼ [추가됨] 코디 선택 모드 취소 함수 ▼▼▼ ---
  void _cancelSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedOutfitIds.clear();
    });
  }
  // --- ▲▲▲ [추가됨] 코디 선택 모드 취소 함수 ▲▲▲ ---

  // --- ▼▼▼ [추가됨] 삭제 확인 다이얼로그 표시 함수 ▼▼▼ ---
  Future<void> _showDeleteConfirmation() async {
    final int count = _selectedOutfitIds.length;
    if (count == 0) return;

    final bool? confirmed = await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('삭제 확인'),
          content: Text('$count개의 코디를 정말 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false), // 아니요
              child: const Text('아니요'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true), // 예
              child: const Text('예', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteSelectedOutfits();
    }
  }
  // --- ▲▲▲ [추가됨] 삭제 확인 다이얼로그 표시 함수 ▲▲▲ ---

  // --- ▼▼▼ [추가됨] 선택된 코디 삭제 API 호출 함수 ▼▼▼ ---
  Future<void> _deleteSelectedOutfits() async {
    // !중요: 이 API는 서버(server.py)에 새로 구현해야 합니다.
    // (이 코드는 서버에 POST /outfits/delete 엔드포인트가 있다고 가정합니다.)
    const String serverIp = '3.36.66.130';
    final uri = Uri.parse('http://$serverIp:5000/outfits/delete');
    final idsToDelete = _selectedOutfitIds.toList();

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        // 'outfit_ids'라는 키로 ID 리스트를 JSON 본문에 담아 전송
        body: jsonEncode({'outfit_ids': idsToDelete}),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('코디가 삭제되었습니다.')));
          // 삭제 성공 후, 선택 모드 해제 및 목록 새로고침
          _cancelSelection();
          await _fetchSavedOutfits();
        } else {
          throw Exception('서버 삭제 실패: ${response.body}');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('삭제 중 오류 발생: $e')));
      }
    }
  }
  // --- ▲▲▲ [추가됨] 선택된 코디 삭제 API 호출 함수 ▲▲▲ ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // --- ▼▼▼ [수정됨] 선택 모드에 따라 AppBar 변경 ▼▼▼ ---
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // 선택 모드일 때 'X' 버튼(취소) 표시
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.black),
                onPressed: _cancelSelection,
              )
            : null,
        // 선택 모드일 때 선택된 개수 표시
        title: Text(
          _isSelectionMode ? '${_selectedOutfitIds.length}개 선택' : '저장된 코디',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      // --- ▲▲▲ [수정됨] 선택 모드에 따라 AppBar 변경 ▲▲▲ ---
      body: Column(
        children: [
          _buildTpoFilterBar(), // TPO 필터 버튼 바
          const Divider(height: 1), // 구분선
          Expanded(
            child: _buildResultsGrid(), // 저장된 코디 그리드
          ),
        ],
      ),
      bottomNavigationBar: _isSelectionMode ? _buildDeleteButton() : null,
    );
  }

  // TPO 필터 버튼 UI 생성
  Widget _buildTpoFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: SizedBox(
        height: 36,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _tpoFilterOptions.length,
          itemBuilder: (context, index) {
            String category = _tpoFilterOptions.keys.elementAt(index);
            bool isSelected = _selectedTpoFilter == category;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedTpoFilter = category; // 선택된 필터 업데이트
                  });
                  _fetchSavedOutfits(); // 선택된 필터로 다시 데이터 로드
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? Colors.black : Colors.white,
                  foregroundColor: isSelected ? Colors.white : Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18), // 더 둥근 버튼
                    side: BorderSide(
                      color: isSelected ? Colors.black : Colors.grey[300]!,
                    ),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Text(category),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- ▼▼▼ [추가됨] 하단 삭제 버튼 위젯 ▼▼▼ ---
  Widget _buildDeleteButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.of(context).padding.bottom / 2,
      ),
      color: Colors.white,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.delete_outline, color: Colors.white),
        label: Text(
          '삭제하기 (${_selectedOutfitIds.length})',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        onPressed: _showDeleteConfirmation,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
  // --- ▲▲▲ [추가됨] 하단 삭제 버튼 위젯 ▲▲▲ ---

  // --- ▼▼▼ [수정됨] 그리드 아이템에 GestureDetector 및 선택 효과 추가 ▼▼▼ ---
  Widget _buildResultsGrid() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_savedOutfits.isEmpty) {
      return Center(child: Text('\'$_selectedTpoFilter\' 카테고리에 저장된 코디가 없습니다.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.7,
      ),
      itemCount: _savedOutfits.length,
      itemBuilder: (context, index) {
        final outfit = _savedOutfits[index];
        // 'outfit_id'가 null일 경우를 대비하여 기본값(예: -1) 설정
        final int outfitId = outfit['outfit_id'] as int? ?? -1;
        final bool isSelected = _selectedOutfitIds.contains(outfitId);

        return GestureDetector(
          onLongPress: () {
            if (outfitId != -1) _toggleSelection(outfitId); // 꾹 눌러서 선택
          },
          onTap: () {
            if (_isSelectionMode && outfitId != -1) {
              _toggleSelection(outfitId); // 선택 모드에서 탭하여 선택/해제
            } else {
              // TODO: (선택 사항) 선택 모드가 아닐 때 탭하면 코디 상세 화면으로 이동
            }
          },
          child: Stack(
            fit: StackFit.expand, // Stack이 Card 크기에 맞게 꽉 차도록
            children: [
              // 1. 코디 카드
              SavedOutfitCard(outfitData: outfit),

              // 2. 선택됐을 때 보여줄 오버레이
              if (isSelected)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5), // 반투명 검은색
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle, // 체크 아이콘
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // --- ▲▲▲ [수정됨] 그리드 아이템에 GestureDetector 및 선택 효과 추가 ▲▲▲ ---
} // SearchScreenState End

// --- ▼▼▼ [수정됨] 저장된 코디 카드 위젯 (main.dart와 동일한 레이아웃) ▼▼▼ ---
class SavedOutfitCard extends StatelessWidget {
  final Map<String, dynamic> outfitData;
  const SavedOutfitCard({super.key, required this.outfitData});

  @override
  Widget build(BuildContext context) {
    // 서버 응답에서 top, bottom, shoes 데이터 추출
    final topData = outfitData['top'] as Map<String, dynamic>? ?? {};
    final bottomData = outfitData['bottom'] as Map<String, dynamic>? ?? {};
    final shoesData = outfitData['shoes'] as Map<String, dynamic>? ?? {};

    // 코디 이름 (outfits 테이블의 name 컬럼)
    final outfitName = outfitData['outfit_name'] as String? ?? '이름 없는 코디';

    return Card(
      elevation: 0,
      // ▼▼▼ [수정] main.dart와 동일하게 grey[200]으로 변경 ▼▼▼
      color: Colors.grey[200], // 카드 배경색
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        // Outer column
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- 옷 이미지 영역 (Expanded) ---
          Expanded(
            // ▼▼▼ [수정] main.dart와 동일한 Column 레이아웃으로 변경 ▼▼▼
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
            // ▲▲▲ [수정] main.dart와 동일한 Column 레이아웃으로 변경 ▲▲▲
          ),
          // --- 코디 이름 영역 (기존과 동일) ---
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
            color: Colors.grey[200], // 이름 영역 배경
            child: Text(
              outfitName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // 이미지 위젯 생성 헬퍼 (기존과 동일, main.dart와 호환됨)
  Widget _buildImage(Map<String, dynamic> itemData) {
    const String serverBaseUrl = 'http://3.36.66.130:5000';
    // 서버 API 응답에 clothingImg 키가 있는지 확인
    final imagePath = itemData['clothingImg'] as String?;
    final bgColor = Colors.white; // 이미지 배경은 흰색

    // itemData 자체가 비어있거나 이미지 경로가 없는 경우
    if (itemData.isEmpty || imagePath == null || imagePath.isEmpty) {
      return Container(
        color: bgColor,
        child: const Center(
          child: Icon(Icons.question_mark, color: Colors.grey, size: 24),
        ),
      );
    }

    final imageUrl = imagePath.startsWith('http')
        ? imagePath
        : '$serverBaseUrl/$imagePath';
    return Container(
      color: bgColor,
      child: Image.network(
        imageUrl,
        fit: BoxFit.contain, // contain으로 표시
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

// --- ▲▲▲ [수정됨] 저장된 코디 카드 위젯 ---
