// 📂 lib/profile_screen.dart

import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isClosetTabSelected = true;
  int _selectedFilterIndex = 1;
  // 보유 옷, 저장 룩 개수
  int cloth_num = 0;
  int saved_look = 0;

  final List<dynamic> _filterItems = [
    Icons.favorite,
    '전체',
    '상의',
    '하의',
    '신발',
  ];

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
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(),
          _buildProfileTabs(),
          if (_isClosetTabSelected) _buildFilterBar(),
          _isClosetTabSelected ? _buildClosetGrid() : _buildBookmarkScreen(),
        ],
      ),
    );
  }

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
                const Text(
                  'User Name',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 1),
                Text(
                  '보유 옷 $cloth_num개 • 저장 룩 $saved_look개',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 1),
                // 아이콘 추가된 코드
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
                  // icon 속성 추가
                  icon: const Icon(
                    Icons.edit, // 연필 모양 아이콘
                    size: 15,     // 아이콘 크기
                    color: Colors.black,
                  ),
                  // 기존 child를 label 속성으로 변경
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

  // ▼▼▼ 이 함수 부분을 수정했습니다 ▼▼▼
  Widget _buildProfileTabs() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        // // 전체 영역에 회색 밑줄을 다시 추가합니다.
        // border: Border(
        //   bottom: BorderSide(color: Colors.grey[300]!, width: 2),
        // ),
      ),
      child: Row(
        children: [
          // 옷장 탭
          _buildTabItem(
            icon: Icons.checkroom,
            isSelected: _isClosetTabSelected,
            onTap: () {
              if (!_isClosetTabSelected) {
                setState(() => _isClosetTabSelected = true);
              }
            },
          ),
          // 북마크 탭
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

  // 탭 아이템을 만드는 함수 (새로 추가)
  Widget _buildTabItem({required IconData icon, required bool isSelected, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          color: Colors.transparent, // 터치 영역을 확장하기 위해 색상을 투명으로 설정
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 아이콘과 하단 선 사이에 공간을 만들기 위해 Expanded를 사용합니다.
              Expanded(
                child: Icon(
                  icon,
                  size: 28,
                  color: isSelected ? Colors.black : Colors.grey,
                ),
              ),
              // 선택되었을 때만 검은색 선을 표시합니다.
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
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_filterItems.length, (index) {
                    var item = _filterItems[index];
                    bool isSelected = _selectedFilterIndex == index;
                    bool isIcon = item is IconData;

                    final buttonPadding = const EdgeInsets.symmetric(horizontal: 12);
                    final buttonMinSize = const Size(0, 36);

                    final ButtonStyle selectedStyle = ElevatedButton.styleFrom(
                        backgroundColor: Colors.black, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: buttonPadding, minimumSize: buttonMinSize,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap);

                    final ButtonStyle unselectedStyle = OutlinedButton.styleFrom(
                        foregroundColor: Colors.black, side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: buttonPadding, minimumSize: buttonMinSize,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap);

                    Widget button;
                    if (isSelected) {
                      button = ElevatedButton(onPressed: () {}, style: selectedStyle,
                          child: isIcon ? Icon(item, size: 20) : Text(item as String));
                    } else {
                      button = OutlinedButton(onPressed: () => setState(() => _selectedFilterIndex = index),
                          style: unselectedStyle, child: isIcon ? Icon(item, size: 20) : Text(item as String));
                    }
                    return Padding(padding: const EdgeInsets.only(right: 8.0), child: button);
                  }),
                ),
              ),
            ),
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black, side: const BorderSide(color: Colors.grey),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.zero, minimumSize: const Size(36, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Icon(Icons.swap_vert, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClosetGrid() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
            childAspectRatio: 1 / 1.2,
          ),
          itemCount: 15,
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.image, color: Colors.white, size: 40),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBookmarkScreen() {
    return const Expanded(
      child: Center(
        child: Text('Bookmark Screen',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }
}