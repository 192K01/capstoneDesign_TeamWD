// 📂 lib/main.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:io' show Platform;

import 'camera.dart';
import 'calendar_screen.dart'; // 이 파일이 없다면 제거해야 합니다.
import 'profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainScreen(),
    );
  }
}

// --- 페이지 전환, 팝업 메뉴 등 앱의 전체 상태를 관리하는 위젯 ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _isMenuOpen = false;

  static const List<Widget> _pages = <Widget>[
    HomeScreen(),
    Scaffold(body: Center(child: Text('Search Page'))),
    CalendarScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    if (index == 2) {
      setState(() => _isMenuOpen = !_isMenuOpen);
    } else {
      int pageIndex = index > 2 ? index - 1 : index;
      setState(() {
        _selectedIndex = pageIndex;
        if (_isMenuOpen) _isMenuOpen = false;
      });
    }
  }

  Future<void> _addClothingItem() async {
    if (_isMenuOpen) setState(() => _isMenuOpen = false);
    await Future.delayed(const Duration(milliseconds: 300));
    
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('사진 가져오기'),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, ImageSource.camera);
              },
              child: const Text('카메라로 촬영'),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, ImageSource.gallery);
              },
              child: const Text('갤러리에서 선택'),
            ),
          ],
        );
      },
    );

    if (source == null) return;

    PermissionStatus status;
    if (source == ImageSource.camera) {
      status = await Permission.camera.request();
    } else {
      if (Platform.isIOS) {
        status = await Permission.photos.request();
      } else {
        status = await Permission.storage.request();
      }
    }
    
    if (status.isGranted) {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      if (image != null && mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => AddClothingScreen(imagePath: image.path),
        ));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${source == ImageSource.camera ? '카메라' : '갤러리'} 권한이 없어 기능을 실행할 수 없습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int navIndex = _selectedIndex >= 2 ? _selectedIndex + 1 : _selectedIndex;

    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(index: _selectedIndex, children: _pages),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.black,
            unselectedItemColor: Colors.grey,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            currentIndex: navIndex,
            onTap: _onItemTapped,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
              BottomNavigationBarItem(icon: Icon(Icons.search), label: '검색'),
              BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: '추가'),
              BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), label: '캘린더'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '프로필'),
            ],
          ),
        ),
        if (_isMenuOpen) _buildPopupMenu(),
      ],
    );
  }

  Widget _buildPopupMenu() {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => setState(() => _isMenuOpen = false),
            child: Container(color: Colors.black.withOpacity(0.7)),
          ),
        ),
        Positioned(
          bottom: 10, left: 0, right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMenuItem(icon: Icons.checkroom, label: '옷 추가하기', onTap: _addClothingItem),
              const SizedBox(height: 16),
              _buildMenuItem(icon: Icons.dry_cleaning, label: '룩 추가하기', onTap: () {}),
              const SizedBox(height: 16),
              _buildMenuItem(icon: Icons.calendar_today, label: '일정 추가하기', onTap: () {}),
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: FloatingActionButton(
                  onPressed: () => setState(() => _isMenuOpen = false),
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.cancel_outlined, size: 30),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.black, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// --- 홈 화면 UI 위젯 ---
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('coordiapp', style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.black), onPressed: () {}),
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
    );
  }
}


// --- 홈 화면에서 사용하는 재사용 위젯들 ---
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
      const lat = 37.1498;
      const lon = 127.0772;
        final url = Uri.parse('https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=kr');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final description = data['weather'][0]['description'];
        final temp = data['main']['temp'];
        if (mounted) {
          setState(() { _weatherInfo = "$description, ${temp.toStringAsFixed(1)}°C"; });
        }
      } else {
        if (mounted) { setState(() { _weatherInfo = "날씨를 불러올 수 없습니다"; }); }
      }
    } catch (e) {
      if (mounted) { setState(() { _weatherInfo = "날씨 로딩 중 오류 발생"; }); }
    }
  }
  @override
  Widget build(BuildContext context) {
    const todayString = '9. 17. 수';
    return Container(
      height: 160,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Text(todayString, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text(_weatherInfo)),
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
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Text('일정 정보')),
            ),
          ),
        ],
      ),
    );
  }
}

class RecommendationSection extends StatelessWidget {
  final String title;
  const RecommendationSection({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: const [
                ClothingItem(), ClothingItem(), ClothingItem(), ClothingItem(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ClothingItem extends StatelessWidget {
  const ClothingItem({super.key});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { print("Tapped on an item!"); },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12.0),
        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: const Center(child: Icon(Icons.checkroom, color: Colors.white, size: 50)),
        ),
      ),
    );
  }
}