// 📂 lib/main.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';         // ▼▼▼ [수정] import 추가 ▼▼▼
import 'package:permission_handler/permission_handler.dart'; // ▼▼▼ [수정] import 추가 ▼▼▼
import 'camera.dart';

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

// (ClothingItem, RecommendationSection 위젯은 변경 없음)
class ClothingItem extends StatelessWidget {
// ... 기존 코드 ...
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

class RecommendationSection extends StatelessWidget {
// ... 기존 코드 ...
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

// (TodayInfoCard 위젯은 변경 없음)
class TodayInfoCard extends StatefulWidget {
// ... 기존 코드 ...
  const TodayInfoCard({super.key});

  @override
  State<TodayInfoCard> createState() => _TodayInfoCardState();
}

class _TodayInfoCardState extends State<TodayInfoCard> {
// ... 기존 코드 ...
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
    // 2025년 9월 15일은 월요일입니다.
    const todayString = '9. 15. 월';
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
                          todayString,
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

// --- 메인 화면 위젯 ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isMenuOpen = false;
  int _selectedIndex = 0;

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      _toggleMenu();
    } else {
      setState(() {
        _selectedIndex = index;
        if (_isMenuOpen) {
          _isMenuOpen = false;
        }
      });
    }
  }

  // ▼▼▼▼▼▼ [수정] 카메라 실행 및 화면 이동을 위한 함수 추가 ▼▼▼▼▼▼
  Future<void> _addClothingItem() async {
    // 팝업 메뉴를 먼저 닫아줍니다.
    _toggleMenu();

    // 카메라 권한을 확인하고, 없다면 요청합니다.
    final cameraStatus = await Permission.camera.request();

    if (cameraStatus.isGranted) {
      // 권한이 있으면 카메라를 실행합니다.
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);

      // 사진을 성공적으로 찍었다면, camera.dart의 AddClothingScreen으로 이동합니다.
      if (image != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddClothingScreen(imagePath: image.path),
          ),
        );
      }
    } else {
      // 권한이 거부된 경우 사용자에게 안내합니다.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카메라 권한이 없어 기능을 실행할 수 없습니다.')),
        );
      }
    }
  }
  // ▲▲▲▲▲▲ [수정] 함수 추가 끝 ▲▲▲▲▲▲

  Widget _buildPopupMenu() {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _toggleMenu,
            child: Container(
              color: Colors.black.withOpacity(0.7),
            ),
          ),
        ),
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMenuItem(
                icon: Icons.checkroom,
                label: '옷 추가하기',
                // ▼▼▼ [수정] onTap에 위에서 만든 함수를 연결합니다 ▼▼▼
                onTap: _addClothingItem,
              ),
              const SizedBox(height: 16),
              _buildMenuItem(
                icon: Icons.dry_cleaning,
                label: '룩 추가하기',
                onTap: () {
                  print('룩 추가하기 Tapped');
                  _toggleMenu();
                },
              ),
              const SizedBox(height: 16),
              _buildMenuItem(
                icon: Icons.calendar_today,
                label: '일정 추가하기',
                onTap: () {
                  print('일정 추가하기 Tapped');
                  _toggleMenu();
                },
              ),
              _buildcancelIcon(
                icon: Icons.cancel_outlined,
                onTap: _toggleMenu,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // (나머지 _buildcancelIcon, _buildMenuItem, build 메서드는 변경 없음)
  Widget _buildcancelIcon({
// ... 기존 코드 ...
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

  Widget _buildMenuItem({
// ... 기존 코드 ...
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
// ... 기존 코드 ...
    return Stack(
      children: [
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
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
              BottomNavigationBarItem(icon: Icon(Icons.search), label: '검색'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.add_circle_outline), label: '추가'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today_outlined), label: '캘린더'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline), label: '프로필'),
            ],
          ),
        ),
        IgnorePointer(
          ignoring: !_isMenuOpen,
          child: AnimatedOpacity(
            opacity: _isMenuOpen ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: _buildPopupMenu(),
          ),
        ),
      ],
    );
  }
}