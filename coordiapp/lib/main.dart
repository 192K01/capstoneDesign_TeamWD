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
        // [수정됨] SizedBox로 감싸서 스크롤 영역의 높이를 220으로 지정
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
      const lat = 37.5665; // 서울 위도
      const lon = 126.9780; // 서울 경도
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

// --- 메인 화면 위젯 ---
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: '검색'),
          BottomNavigationBarItem(
              icon: Icon(Icons.add_box_outlined), label: '추가'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined), label: '캘린더'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: '프로필'),
        ],
      ),
    );
  }
}