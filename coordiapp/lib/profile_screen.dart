import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

// --- ▼▼▼ [수정] State 클래스 이름 변경 및 기능 추가 ▼▼▼ ---
class ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  bool _isClosetTabSelected = true;
  int saved_look = 0;

  // --- ▼▼▼ [수정] 필터링 기능 추가 ▼▼▼ ---
  List<Map<String, dynamic>> _allClosetItems = []; // 서버에서 받은 모든 옷
  List<Map<String, dynamic>> _filteredClosetItems = []; // 현재 필터가 적용된 옷
  bool _isLoading = true;
  String _userName = "User Name";
  String _selectedCategory = '전체'; // 현재 선택된 카테고리
  final List<String> _filterCategories = ['전체', '상의', '하의', '신발'];

  // --- ▲▲▲ [추가] 옷장 데이터를 위한 변수들 ▲▲▲ ---

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserDataAndClothes();
  }

  Future<void> _loadUserDataAndClothes() async {
    await _loadUserName();
    await performSearch();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    // 저장된 이름이 있으면 가져오고, 없으면 기본값을 사용합니다.
    setState(() {
      _userName = prefs.getString('userName') ?? 'User Name';
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      performSearch();
    }
  }

  // --- ▼▼▼ [추가] 서버에서 옷 목록을 가져오는 함수 ▼▼▼ ---
  Future<void> performSearch() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('userEmail');
      if (userEmail == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      const String serverIp = '3.36.66.130';
      final uri = Uri.parse('http://$serverIp:5000/clothes/$userEmail');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        if (mounted) {
          setState(() {
            _allClosetItems = results.cast<Map<String, dynamic>>();
            _applyFilter(); // 데이터를 받은 후 필터 적용
          });
        }
      }
    } catch (e) {
      debugPrint("옷 목록 로딩 중 오류 발생: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- ▲▲▲ [추가] 서버에서 옷 목록을 가져오는 함수 ▲▲▲ ---
  void _applyFilter() {
    if (_selectedCategory == '전체') {
      _filteredClosetItems = List.from(_allClosetItems);
    } else {
      _filteredClosetItems = _allClosetItems
          .where((item) => item['subCategory'] == _selectedCategory)
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(),
          _buildProfileTabs(),
          if (_isClosetTabSelected) _buildFilterBar(),
          // --- ▼▼▼ [수정] Expanded로 감싸서 남은 공간을 채우도록 변경 ▼▼▼ ---
          Expanded(
            child: _isClosetTabSelected
                ? _buildClosetGrid()
                : _buildBookmarkScreen(),
          ),
          // --- ▲▲▲ [수정] Expanded로 감싸서 남은 공간을 채우도록 변경 ▲▲▲ ---
        ],
      ),
    );
  }

  // (이하 _buildProfileHeader, _buildProfileTabs, _buildTabItem, _buildFilterBar는 기존 코드와 동일)
  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 45,
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, size: 40, color: Colors.white),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '보유 옷 ${_allClosetItems.length}개 • 저장 룩 $saved_look개',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 1),
                ElevatedButton.icon(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.edit, size: 15, color: Colors.black),
                  label: const Text(
                    '프로필 편집',
                    style: TextStyle(color: Colors.black, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTabs() {
    return Container(
      height: 50,
      decoration: BoxDecoration(),
      child: Row(
        children: [
          _buildTabItem(
            icon: Icons.checkroom,
            isSelected: _isClosetTabSelected,
            onTap: () {
              if (!_isClosetTabSelected) {
                setState(() => _isClosetTabSelected = true);
              }
            },
          ),
          _buildTabItem(
            icon: Icons.bookmark_border,
            isSelected: !_isClosetTabSelected,
            onTap: () {
              if (_isClosetTabSelected) {
                setState(() => _isClosetTabSelected = false);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          color: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Icon(
                  icon,
                  size: 28,
                  color: isSelected ? Colors.black : Colors.grey,
                ),
              ),
              Container(
                height: 2,
                color: isSelected ? Colors.black : Colors.grey[300]!,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 4.0),
      child: SizedBox(
        height: 36,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filterCategories.map((category) {
              bool isSelected = _selectedCategory == category;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = category;
                      _applyFilter(); // 필터를 누를 때마다 적용
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected ? Colors.black : Colors.white,
                    foregroundColor: isSelected ? Colors.white : Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? Colors.black : Colors.grey,
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: Text(category),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // --- ▼▼▼ [수정] _buildClosetGrid 함수를 서버 데이터와 연동 ▼▼▼ ---
  Widget _buildClosetGrid() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_filteredClosetItems.isEmpty) {
      return Center(child: Text('해당 카테고리에 옷이 없습니다.'));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1 / 1.2,
        ),
        itemCount: _filteredClosetItems.length,
        itemBuilder: (context, index) {
          final cloth = _filteredClosetItems[index];
          final imagePath = cloth['clothingImg'] as String?;
          return Card(
            elevation: 0,
            color: Colors.grey[200],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: (imagePath != null && imagePath.isNotEmpty)
                ? Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(Icons.error_outline, color: Colors.white),
                      );
                    },
                  )
                : const Center(
                    child: Icon(Icons.checkroom, size: 40, color: Colors.white),
                  ),
          );
        },
      ),
    );
  }
  // --- ▲▲▲ [수정] _buildClosetGrid 함수를 서버 데이터와 연동 ▲▲▲ ---

  Widget _buildBookmarkScreen() {
    return const Center(
      child: Text(
        'Bookmark Screen',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }
}
