import 'dart:convert'; // JSON 데이터를 다루기 위해 필요
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // HTTP 패키지

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}

// --- 옷 사진 카드 하나를 위한 재사용 위젯 ---
class ClothingItem extends StatelessWidget {
  const ClothingItem({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        print("Tapped on an item!");
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12.0),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: const Center(
            child: Icon(
              Icons.checkroom,
              color: Colors.white,
              size: 50,
            ),
          ),
        ),
      ),
    );
  }
}

// --- 제목 + 가로 스크롤 목록을 위한 재사용 위젯 ---
class RecommendationSection extends StatelessWidget {
  final String title;

  const RecommendationSection({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: const [
                ClothingItem(),
                ClothingItem(),
                ClothingItem(),
                ClothingItem(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- 날씨 & 일정 카드 위젯 (StatefulWidget) ---
class TodayInfoCard extends StatefulWidget {
  const TodayInfoCard({super.key});

  @override
  State<TodayInfoCard> createState() => _TodayInfoCardState();
}

class _TodayInfoCardState extends State<TodayInfoCard> {
  String _weatherInfo = "날씨 로딩 중...";

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    try {
      const apiKey = 'aea983582fed66f091aad69100146ccd';
      const lat = 37.3911; // 시흥시청 위도
      const lon = 126.8093; // 시흥시청 경도
      final url = Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=kr');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final description = data['weather'][0]['description'];
        final temp = data['main']['temp'];

        if (mounted) {
          setState(() {
            _weatherInfo = "$description, ${temp.toStringAsFixed(1)}°C";
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _weatherInfo = "날씨를 불러올 수 없습니다";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _weatherInfo = "날씨 로딩 중 오류 발생";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                        child: Text(
                          '9. 13. 토',
                          style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        )),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(_weatherInfo),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: VerticalDivider(color: Colors.grey, thickness: 1),
          ),
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Text('일정 정보')),
            ),
          ),
        ],
      ),
    );
  }
}

// --- [수정됨] 메인 화면 위젯을 StatefulWidget으로 변경 ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 팝업 메뉴의 표시 상태를 관리하는 변수
  bool _isMenuOpen = false;
  int _selectedIndex = 0; // BottomNavigationBar의 현재 선택된 인덱스

  // 팝업 메뉴를 토글하는 함수
  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
  }

  // BottomNavigationBar 아이템 탭 처리 함수
  void _onItemTapped(int index) {
    // '추가' 버튼(인덱스 2)을 눌렀을 경우, 메뉴를 토글
    if (index == 2) {
      _toggleMenu();
    } else {
      // 다른 버튼을 누르면, 해당 탭으로 이동하고 메뉴가 열려있다면 닫음
      setState(() {
        _selectedIndex = index;
        if (_isMenuOpen) {
          _isMenuOpen = false;
        }
      });
    }
  }

  // 팝업 메뉴 위젯을 빌드하는 함수
  Widget _buildPopupMenu() {
    return Stack(
      children: [
        // 1. 검은색 반투명 배경 (쉐이딩 처리)
        // 화면 전체를 덮고, 탭하면 메뉴가 닫히도록 GestureDetector 사용
        Positioned.fill(
          child: GestureDetector(
            onTap: _toggleMenu, // 배경을 탭하면 메뉴 닫기
            child: Container(
              color: Colors.black.withOpacity(0.7),
            ),
          ),
        ),
        // 2. 팝업 버튼들
        // 화면 하단 중앙에 위치
        Positioned(
          bottom: 10, // BottomNavigationBar 위쪽으로 위치 조정
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              _buildMenuItem(
                icon: Icons.checkroom, // T-shirt icon
                label: '옷 추가하기',
                onTap: () {
                  print('옷 추가하기 Tapped');
                  _toggleMenu();
                },
              ),
              const SizedBox(height: 16),
              _buildMenuItem(
                icon: Icons.dry_cleaning, // Dress icon
                label: '룩 추가하기',
                onTap: () {
                  print('룩 추가하기 Tapped');
                  _toggleMenu();
                },
              ),
              const SizedBox(height: 16),
              _buildMenuItem(
                icon: Icons.calendar_today, // Calendar icon
                label: '일정 추가하기',
                onTap: () {
                  print('일정 추가하기 Tapped');
                  _toggleMenu();
                },
              ),
              _buildcancelIcon(
                icon:Icons.cancel_outlined,

                onTap: () {
                  print('팝업 나가기 Tapped');
                  _toggleMenu();
                },
              ),

            ],
          ),
        ),
      ],
    );
  }

  Widget _buildcancelIcon({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: FloatingActionButton(
        onPressed: onTap,
        backgroundColor: Colors.black, // 배경색을 검정으로 변경
        foregroundColor: Colors.white, // 아이콘 색상을 흰색으로 변경
        shape: const CircleBorder(),   // 모양을 원형으로 명시
        elevation: 4.0,
        child: Icon(icon, size: 30),

      ),
    );
  }
  // 개별 팝업 메뉴 아이템을 만드는 헬퍼 함수
  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(color: Colors.black, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // [수정됨] Stack을 사용하여 기본 화면 위에 팝업 메뉴를 오버레이
    return Stack(
      children: [
        // 1. 기본 화면 UI
        Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text(
              'App Name',
              style: TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.black),
                onPressed: () {},
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: const [
              TodayInfoCard(),
              SizedBox(height: 30),
              RecommendationSection(title: '오늘의 추천'),
              SizedBox(height: 30),
              RecommendationSection(title: '내가 즐겨입는 룩'),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.black,
            unselectedItemColor: Colors.grey,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            items: [
              const BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
              const BottomNavigationBarItem(icon: Icon(Icons.search), label: '검색'),
              // [수정됨] 메뉴 상태에 따라 아이콘 변경 (추가 <-> 닫기)
              BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: '추가'),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today_outlined), label: '캘린더'),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline), label: '프로필'),
            ],
          ),
        ),
        // 2. [추가됨] _isMenuOpen 상태가 true일 때만 팝업 메뉴를 보여줌
        IgnorePointer(
          ignoring: !_isMenuOpen,
          child: AnimatedOpacity(
            // _isMenuOpen 상태에 따라 투명도를 조절
            opacity: _isMenuOpen ? 1.0 : 0.0,
            // 애니메이션 지속 시간
            duration: const Duration(milliseconds: 300),
            // 팝업 메뉴 위젯
            child: _buildPopupMenu(),
          ),
        ),
      ],
    );
  }
}