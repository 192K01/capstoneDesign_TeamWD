// 📂 lib/main.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:io' show File, Platform; // File import 추가
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:table_calendar/table_calendar.dart';
import 'splash_screen.dart';
import 'camera.dart';

//로그인 관련
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

import 'calendar_screen.dart';
import 'profile_screen.dart';
import 'schedule_add.dart';
import 'search_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  await initializeDateFormatting();

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(), // isLoggedIn 전달
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _isMenuOpen = false;

  final GlobalKey<ProfileScreenState> _profileScreenKey =
      GlobalKey<ProfileScreenState>();
  final GlobalKey<CalendarScreenState> _calendarScreenKey =
      GlobalKey<CalendarScreenState>();
  final GlobalKey<_HomeScreenState> _homeScreenKey =
      GlobalKey<_HomeScreenState>(); // HomeScreen 키 추가

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      HomeScreen(
        key: _homeScreenKey, // HomeScreen에 Key 전달
        onNavigateToCalendar: () => _navigateToCalendarTab(), // 캘린더 이동 콜백
      ),
      const SearchScreen(),
      CalendarScreen(key: _calendarScreenKey),
      ProfileScreen(key: _profileScreenKey),
    ];
  }

  void _navigateToCalendarTab() {
    setState(() {
      _selectedIndex = 2;
    });
    // Key를 사용하여 CalendarScreen의 refreshData 호출 (존재 여부 확인)
    _calendarScreenKey.currentState?.refreshData();
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      setState(() => _isMenuOpen = !_isMenuOpen);
    } else {
      int pageIndex = index > 2 ? index - 1 : index;
      bool needsRefresh = _selectedIndex != pageIndex;
      setState(() {
        _selectedIndex = pageIndex;
        if (_isMenuOpen) _isMenuOpen = false;
      });
      if (needsRefresh) {
        // ▼▼▼ [수정됨] 'else if' -> 'if'로 변경 ▼▼▼
        if (pageIndex == 2) {
          // 캘린더 탭
          _calendarScreenKey.currentState?.refreshData();
        } else if (pageIndex == 3) {
          // 프로필 탭 (옷장)
          _profileScreenKey.currentState?.performSearch();
        }
      }
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
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddClothingScreen(imagePath: image.path),
          ),
        );
        if (result == true) {
          _profileScreenKey.currentState?.performSearch();
          _homeScreenKey.currentState?.refreshAllData();
          setState(() {
            _selectedIndex = 3;
          });
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${source == ImageSource.camera ? '카메라' : '갤러리'} 권한이 없어 기능을 실행할 수 없습니다.',
            ),
          ),
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
              BottomNavigationBarItem(
                icon: Icon(Icons.add_circle_outline),
                label: '추가',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today_outlined),
                label: '캘린더',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                label: '프로필',
              ),
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
          bottom: 10,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMenuItem(
                icon: Icons.checkroom,
                label: '옷 추가하기',
                onTap: _addClothingItem,
              ),
              const SizedBox(height: 16),
              _buildMenuItem(
                icon: Icons.dry_cleaning,
                label: '룩 추가하기',
                onTap: () {},
              ),
              const SizedBox(height: 16),
              _buildMenuItem(
                icon: Icons.calendar_today,
                label: '일정 추가하기',
                onTap: () async {
                  if (_isMenuOpen) setState(() => _isMenuOpen = false);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ScheduleAddScreen(),
                    ),
                  );
                  if (result == true) {
                    _calendarScreenKey.currentState?.refreshData();
                    setState(() {
                      _selectedIndex = 2;
                    });
                  }
                },
              ),
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
}

// --- ▼▼▼ [수정] HomeScreen: StatefulWidget으로 변경 및 추천 로직 추가 ▼▼▼ ---
class HomeScreen extends StatefulWidget {
  final VoidCallback onNavigateToCalendar;
  // key를 받도록 생성자 수정
  const HomeScreen({Key? key, required this.onNavigateToCalendar})
    : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 추천 코디 상태 변수
  List<Map<String, dynamic>> _recommendedOutfitsList = [];
  bool _isRecommendLoading = false;
  String _recommendStatus = '오늘의 코디를 불러오는 중...';
  String _recommendedTpo = ''; // 추천 기준 TPO
  double? _currentRawTemp; // 추천 API에 보낼 원본 온도

  @override
  void initState() {
    super.initState();
    refreshAllData(); // 화면 로드 시 데이터 가져오기
  }

  // HomeScreen 데이터 새로고침 (날씨, 일정(TPO), 코디 추천)
  Future<void> refreshAllData() async {
    if (!mounted) return; // 위젯이 화면에 없으면 중단
    setState(() {
      _isRecommendLoading = true;
      _recommendStatus = '오늘의 정보 확인 중...';
      _recommendedOutfitsList = [];
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('userEmail');
      if (userEmail == null) throw Exception('로그인 정보 없음');

      // 1. 날씨 정보 가져오기
      final position = await _getCurrentLocation();
      final weatherData = await _fetchCurrentWeather(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return; // 비동기 작업 후 확인
      _currentRawTemp = weatherData['rawTemp']; // 원본 온도 저장

      // 2. 오늘 날짜 및 TPO 가져오기
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final determinedTpo = await _fetchTodayTPO(userEmail, today);
      if (!mounted) return;
      setState(() {
        _recommendStatus = "'$determinedTpo' 코디 찾는 중...";
        _recommendedTpo = determinedTpo;
      });

      // 3. 코디 추천 요청
      await _getRecommendation(
        userEmail,
        determinedTpo,
        _currentRawTemp,
        today,
      );
    } catch (e) {
      debugPrint("HomeScreen 데이터 로딩 오류: $e");
      if (mounted) {
        setState(() {
          _isRecommendLoading = false;
          _recommendStatus = e.toString().contains('로그인 정보 없음')
              ? '로그인이 필요합니다.'
              : '데이터 로딩 오류';
        });
      }
    }
    // _getRecommendation 함수에서 최종적으로 _isRecommendLoading = false 처리
  }

  // 오늘의 TPO 가져오기 (서버 API 호출)
  Future<String> _fetchTodayTPO(String userEmail, String todayDateStr) async {
    const serverIp = '3.36.66.130';
    final url = Uri.parse('http://$serverIp:5000/schedule/$userEmail');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> allSchedules = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        // 오늘 날짜와 일치하는 '첫 번째' 일정 찾기
        final todaySchedule = allSchedules.firstWhere((schedule) {
          try {
            final scheduleDateStr = schedule['startDate']?.split(' ')[0];
            return scheduleDateStr == todayDateStr;
          } catch (e) {
            return false;
          }
        }, orElse: () => null);

        // TPO 이름 매핑 (서버 TPO_SCORES 키와 일치)
        const tpoMapping = {
          '일상&캐주얼': 'Casual & Daily',
          '비즈니스&포멀': 'Business & Formal',
          '특별한 날&데이트': 'Special Occasion & Date',
          '활동적인 날': 'Active Day',
        };

        if (todaySchedule != null) {
          final String? tpo1 = todaySchedule['tpo1'];
          final String? tpo2 = todaySchedule['tpo2'];
          final String rawTpo = (tpo1 != null && tpo1.isNotEmpty)
              ? tpo1
              : (tpo2 != null && tpo2.isNotEmpty)
              ? tpo2
              : '일상&캐주얼';
          return tpoMapping[rawTpo] ?? 'Casual & Daily'; // 매핑 안되면 기본값
        }
      }
    } catch (e) {
      debugPrint("오늘 일정(TPO) 로딩 중 오류 발생: $e");
    }
    print("오늘 일정이 없어 기본 TPO(Casual & Daily) 사용");
    return 'Casual & Daily'; // 기본 TPO
  }

  // 날씨 정보 가져오기 (기상청 API)
  Future<Map<String, dynamic>> _fetchCurrentWeather(
    double lat,
    double lng,
  ) async {
    try {
      const apiKey = 'ymOBx1J3Se-jgcdSdynvFg';
      final now = DateTime.now();
      DateTime targetTime = now.subtract(const Duration(minutes: 45));
      String baseDate = DateFormat('yyyyMMdd').format(targetTime);
      String baseTime = '${DateFormat('HH').format(targetTime)}30';
      final gridCoords = _convertToGrid(lat, lng);
      final nx = gridCoords['x'];
      final ny = gridCoords['y'];
      final url = Uri.parse(
        'https://apihub.kma.go.kr/api/typ02/openApi/VilageFcstInfoService_2.0/getUltraSrtFcst'
        '?pageNo=1&numOfRows=60&dataType=JSON&base_date=$baseDate&base_time=$baseTime&nx=$nx&ny=$ny&authKey=$apiKey',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['response']['header']['resultCode'] == '00') {
          final items = data['response']['body']['items']['item'] as List;
          if (items.isNotEmpty) {
            final firstFcstTime = items[0]['fcstTime'];
            Map<String, String> weatherData = {};
            for (var item in items) {
              if (item['fcstTime'] == firstFcstTime) {
                weatherData[item['category']] = item['fcstValue'];
              }
            }
            String temp = weatherData['T1H'] ?? '0';
            String sky = weatherData['SKY'] ?? '';
            String pty = weatherData['PTY'] ?? '';
            final ptyString = _getPtyString(pty);
            final skyString = _getSkyString(sky);
            return {
              'rawTemp': double.tryParse(temp), // double? 타입
              'displayTemp':
                  "${double.tryParse(temp)?.toStringAsFixed(1) ?? 'N/A'}°",
              'skyCondition': ptyString.isNotEmpty ? ptyString : skyString,
              'skyIcon': _getWeatherIcon(sky, pty),
            };
          }
        }
      }
    } catch (e) {
      debugPrint("현재 날씨 로딩 중 오류: $e");
    }
    return {
      'rawTemp': null,
      'displayTemp': 'N/A',
      'skyCondition': '날씨 오류',
      'skyIcon': Icons.error_outline,
    };
  }

  // 코디 추천 API 호출
  Future<void> _getRecommendation(
    String userEmail,
    String tpoCategory,
    double? temperature,
    String dateString,
  ) async {
    try {
      const String serverIp = '3.36.66.130';
      final uri = Uri.parse('http://$serverIp:5000/recommend_today');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': userEmail,
          'tpo': tpoCategory,
          'date': dateString,
          'temperature': temperature, // double? 타입 전달
        }),
      );
      if (mounted) {
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          setState(() {
            _recommendedOutfitsList = List<Map<String, dynamic>>.from(
              data['recommended_outfits_list'] ?? [],
            );
            _recommendedTpo = data['tpo'] ?? tpoCategory;
            _recommendStatus = _recommendedOutfitsList.isEmpty
                ? "'$_recommendedTpo'에 맞는 코디가 없습니다."
                : "'$_recommendedTpo' 추천 코디";
          });
        } else {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          setState(() => _recommendStatus = data['message'] ?? '추천 실패');
        }
      }
    } catch (e) {
      debugPrint("추천 요청 오류: $e");
      if (mounted) setState(() => _recommendStatus = '네트워크 오류');
    } finally {
      if (mounted) setState(() => _isRecommendLoading = false); // 로딩 종료
    }
  }

  // --- ▼▼▼ 날씨 관련 헬퍼 함수들 (기존 TodayInfoCard에서 가져옴) ▼▼▼ ---
  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('위치 서비스 비활성화');
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied)
        return Future.error('위치 권한 거부');
    }
    if (permission == LocationPermission.deniedForever)
      return Future.error('위치 권한 영구 거부');
    return await Geolocator.getCurrentPosition();
  }

  String _getPtyString(String ptyCode) {
    switch (ptyCode) {
      case '0':
        return '';
      case '1':
        return '비';
      case '2':
        return '비/눈';
      case '3':
        return '눈';
      case '4':
        return '소나기';
      case '5':
        return '빗방울';
      case '6':
        return '빗방울/눈날림';
      case '7':
        return '눈날림';
      default:
        return '';
    }
  }

  String _getSkyString(String skyCode) {
    switch (skyCode) {
      case '1':
        return '맑음';
      case '3':
        return '구름많음';
      case '4':
        return '흐림';
      default:
        return '정보 없음';
    }
  }

  IconData _getWeatherIcon(String skyCode, String ptyCode) {
    if (ptyCode.isNotEmpty && ptyCode != '0') {
      switch (ptyCode) {
        case '1':
          return Icons.umbrella;
        case '2':
          return Icons.cloudy_snowing;
        case '3':
          return Icons.snowing;
        case '4':
          return Icons.thunderstorm;
        default:
          return Icons.grain;
      }
    }
    switch (skyCode) {
      case '1':
        return Icons.wb_sunny;
      case '3':
        return Icons.cloud;
      case '4':
        return Icons.cloud_queue;
      default:
        return Icons.help_outline;
    }
  }

  Map<String, int> _convertToGrid(double lat, double lng) {
    const double RE = 6371.00877, GRID = 5.0, SLAT1 = 30.0, SLAT2 = 60.0;
    const double OLON = 126.0, OLAT = 38.0;
    const int XO = 43, YO = 136;
    final double DEGRAD = pi / 180.0;
    final double re = RE / GRID;
    final double slat1 = SLAT1 * DEGRAD, slat2 = SLAT2 * DEGRAD;
    final double olon = OLON * DEGRAD, olat = OLAT * DEGRAD;
    double sn = tan(pi * 0.25 + slat2 * 0.5) / tan(pi * 0.25 + slat1 * 0.5);
    sn = log(cos(slat1) / cos(slat2)) / log(sn);
    double sf = tan(pi * 0.25 + slat1 * 0.5);
    sf = pow(sf, sn) * cos(slat1) / sn;
    double ro = tan(pi * 0.25 + olat * 0.5);
    ro = re * sf / pow(ro, sn);
    double ra = tan(pi * 0.25 + (lat) * DEGRAD * 0.5);
    ra = re * sf / pow(ra, sn);
    double theta = lng * DEGRAD - olon;
    if (theta > pi) theta -= 2.0 * pi;
    if (theta < -pi) theta += 2.0 * pi;
    theta *= sn;
    final x = (ra * sin(theta) + XO + 0.5).floor();
    final y = (ro - ra * cos(theta) + YO + 0.5).floor();
    return {'x': x, 'y': y};
  }
  // --- ▲▲▲ 날씨 관련 헬퍼 함수들 ▲▲▲ ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'coordiapp',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ▼▼▼ TodayInfoCard는 그대로 사용 (자체적으로 날씨/일정 로드) ▼▼▼
            TodayInfoCard(onNavigateToCalendar: widget.onNavigateToCalendar),
            const SizedBox(height: 30),
            // --- ▼▼▼ [수정] '오늘의 추천' 섹션 UI ▼▼▼ ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(/* ... (제목, 새로고침 버튼 - 기존과 동일) ... */),
                const SizedBox(height: 12),
                _isRecommendLoading
                    ? SizedBox(
                        height: 220,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 10),
                              Text(
                                _recommendStatus,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    // ▼▼▼ [수정] _recommendedOutfitsList.isNotEmpty 로 확인 ▼▼▼
                    : _recommendedOutfitsList.isNotEmpty
                    ? _buildRecommendedOutfitSlides(
                        _recommendedOutfitsList,
                      ) // 리스트 전달
                    : Container(
                        height: 220,
                        alignment: Alignment.center,
                        child: Text(
                          _recommendStatus.isNotEmpty
                              ? _recommendStatus
                              : '추천 코디를 불러올 수 없습니다.',
                          style: TextStyle(
                            color:
                                _recommendStatus.contains('오류') ||
                                    _recommendStatus.contains('실패') ||
                                    _recommendStatus.contains('없음')
                                ? Colors.red
                                : Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 30),
            const RecommendationSection(title: '내가 즐겨입는 룩'), // 기존 섹션 유지
          ],
        ),
      ),
    );
  }

  // --- ▼▼▼ [수정] 추천 코디 '리스트'를 받아 가로 슬라이드로 만듦 ▼▼▼ ---
  Widget _buildRecommendedOutfitSlides(List<Map<String, dynamic>> outfits) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            "오늘의 TPO: $_recommendedTpo",
            style: const TextStyle(
              color: Colors.deepPurple,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 220, // 슬라이드 높이
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            // 서버에서 받은 추천 코디 '개수'만큼 아이템 생성
            itemCount: outfits.length,
            itemBuilder: (context, index) {
              final outfitData = outfits[index]; // N번째 코디 조합
              // ClothingItem 위젯이 아닌, 새로운 '코디 조합 카드' 위젯 사용
              return RecommendedOutfitCard(outfitData: outfitData);
            },
          ),
        ),
      ],
    );
  }

  // --- ▲▲▲ [수정] 추천 코디 '리스트'를 받아 가로 슬라이드로 만듦 ▲▲▲ ---
} // _HomeScreenState End

class TodayInfoCard extends StatefulWidget {
  final VoidCallback onNavigateToCalendar;
  const TodayInfoCard({super.key, required this.onNavigateToCalendar});

  @override
  State<TodayInfoCard> createState() => _TodayInfoCardState();
}

class _TodayInfoCardState extends State<TodayInfoCard> {
  bool _isLoading = true;
  String _dateString = "";
  String _currentTemp = "";
  String _skyCondition = "";
  IconData _skyIcon = Icons.help_outline;
  String? _minMaxTemp;
  String? _minTemp;
  String? _maxTemp;
  List<Map<String, dynamic>> _todaySchedules = [];

  @override
  void initState() {
    super.initState();
    _initializeAllData();
  }

  Future<void> _initializeAllData() async {
    _setDateString();
    await _fetchTodaySchedules();
    try {
      final position = await _getCurrentLocation();
      await _fetchCurrentWeather(position.latitude, position.longitude);
      await _fetchMinMaxTemp(position.latitude, position.longitude);
    } catch (e) {
      if (mounted) setState(() => _skyCondition = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTodaySchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail');
    if (userEmail == null) return;

    const serverIp = '3.36.66.130';
    final url = Uri.parse('http://$serverIp:5000/schedule/$userEmail');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> allSchedules = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        final today = DateTime.now();

        final todaySchedules = allSchedules.where((schedule) {
          try {
            final startDate = DateTime.parse(schedule['startDate']);
            final endDate = DateTime.parse(schedule['endDate']);
            final normalizedToday = DateTime(
              today.year,
              today.month,
              today.day,
            );
            return (normalizedToday.isAtSameMomentAs(startDate) ||
                    normalizedToday.isAfter(startDate)) &&
                (normalizedToday.isAtSameMomentAs(endDate) ||
                    normalizedToday.isBefore(endDate));
          } catch (e) {
            return false;
          }
        }).toList();

        todaySchedules.sort((a, b) {
          int getScheduleType(
            Map<String, dynamic> schedule,
            DateTime selected,
          ) {
            final startDate = DateTime.parse(schedule['startDate']);
            final endDate = DateTime.parse(schedule['endDate']);
            final selectedDay = DateTime(
              selected.year,
              selected.month,
              selected.day,
            );

            final isTrueAllDay =
                schedule['startTime'] == '00:00' &&
                schedule['endTime'] == '23:59';
            final isFirstDay = isSameDay(startDate, selectedDay);
            final isLastDay = isSameDay(endDate, selectedDay);
            final isMultiDay = !isSameDay(startDate, endDate);

            if (isTrueAllDay) return 1;
            if (isMultiDay && !isFirstDay && !isLastDay) return 1;
            if (isMultiDay && isLastDay) return 2;
            return 3;
          }

          final typeA = getScheduleType(a, today);
          final typeB = getScheduleType(b, today);
          if (typeA != typeB) return typeA.compareTo(typeB);

          final startTimeA = a['startTime'] ?? '00:00';
          final startTimeB = b['startTime'] ?? '00:00';
          return startTimeA.compareTo(startTimeB);
        });

        if (mounted) {
          setState(() {
            _todaySchedules = List<Map<String, dynamic>>.from(todaySchedules);
          });
        }
      }
    } catch (e) {
      debugPrint("오늘 일정 로딩 중 오류 발생: $e");
    }
  }

  void _setDateString() {
    setState(() {
      _dateString = DateFormat('M. d. E', 'ko_KR').format(DateTime.now());
    });
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('위치 서비스 비활성화');
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied)
        return Future.error('위치 권한 거부');
    }
    if (permission == LocationPermission.deniedForever)
      return Future.error('위치 권한 영구 거부');
    return await Geolocator.getCurrentPosition();
  }

  Future<void> _fetchCurrentWeather(double lat, double lng) async {
    try {
      const apiKey = 'ymOBx1J3Se-jgcdSdynvFg';
      final now = DateTime.now();
      String baseDate;
      String baseTime;
      DateTime targetTime = now.subtract(const Duration(minutes: 45));
      baseDate = DateFormat('yyyyMMdd').format(targetTime);
      baseTime = DateFormat('HH').format(targetTime) + '30';
      final gridCoords = _convertToGrid(lat, lng);
      final nx = gridCoords['x'];
      final ny = gridCoords['y'];
      final url = Uri.parse(
        'https://apihub.kma.go.kr/api/typ02/openApi/VilageFcstInfoService_2.0/getUltraSrtFcst'
        '?pageNo=1&numOfRows=60&dataType=JSON&base_date=$baseDate&base_time=$baseTime&nx=$nx&ny=$ny&authKey=$apiKey',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['response']['header']['resultCode'] == '00') {
          final items = data['response']['body']['items']['item'] as List;
          if (items.isEmpty) {
            if (mounted) setState(() => _skyCondition = "정보 없음");
            return;
          }
          final firstFcstTime = items[0]['fcstTime'];
          Map<String, String> weatherData = {};
          for (var item in items) {
            if (item['fcstTime'] == firstFcstTime) {
              weatherData[item['category']] = item['fcstValue'];
            }
          }
          String temp = weatherData['T1H'] ?? '';
          String sky = weatherData['SKY'] ?? '';
          String pty = weatherData['PTY'] ?? '';
          if (temp.isNotEmpty && mounted) {
            final ptyString = _getPtyString(pty);
            final skyString = _getSkyString(sky);
            setState(() {
              _currentTemp = "${double.parse(temp).toStringAsFixed(1)}°";
              _skyCondition = ptyString.isNotEmpty ? ptyString : skyString;
              _skyIcon = _getWeatherIcon(sky, pty);
            });
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _skyCondition = "오류 발생");
    }
  }

  Future<void> _fetchMinMaxTemp(double lat, double lng) async {
    try {
      const apiKey = 'ymOBx1J3Se-jgcdSdynvFg';
      final now = DateTime.now();
      final baseDate = DateFormat('yyyyMMdd').format(now);
      const baseTime = '0200';

      final gridCoords = _convertToGrid(lat, lng);
      final nx = gridCoords['x'];
      final ny = gridCoords['y'];

      final url = Uri.parse(
        'https://apihub.kma.go.kr/api/typ02/openApi/VilageFcstInfoService_2.0/getVilageFcst'
        '?authKey=$apiKey&pageNo=1&numOfRows=300&dataType=JSON&base_date=$baseDate&base_time=$baseTime&nx=$nx&ny=$ny',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['response']['header']['resultCode'] == '00') {
          final items = data['response']['body']['items']['item'] as List;
          String tmn = '';
          String tmx = '';

          for (var item in items) {
            if (item['fcstDate'] == baseDate) {
              if (item['category'] == 'TMN') tmn = item['fcstValue'];
              if (item['category'] == 'TMX') tmx = item['fcstValue'];
            }
          }
          if (tmn.isNotEmpty && tmx.isNotEmpty && mounted) {
            setState(() {
              _minTemp = "최저 ${double.parse(tmn).toStringAsFixed(1)}°";
              _maxTemp = "최고 ${double.parse(tmx).toStringAsFixed(1)}°";
            });
          }
        }
      }
    } catch (e) {
      debugPrint("최저/최고기온 API 오류: $e");
    }
  }

  String _getPtyString(String ptyCode) {
    switch (ptyCode) {
      case '0':
        return '';
      case '1':
        return '비';
      case '2':
        return '비/눈';
      case '3':
        return '눈';
      case '4':
        return '소나기';
      case '5':
        return '빗방울';
      case '6':
        return '빗방울/눈날림';
      case '7':
        return '눈날림';
      default:
        return '';
    }
  }

  String _getSkyString(String skyCode) {
    switch (skyCode) {
      case '1':
        return '맑음';
      case '3':
        return '구름많음';
      case '4':
        return '흐림';
      default:
        return '정보 없음';
    }
  }

  IconData _getWeatherIcon(String skyCode, String ptyCode) {
    if (ptyCode.isNotEmpty && ptyCode != '0') {
      switch (ptyCode) {
        case '1':
          return Icons.umbrella;
        case '2':
          return Icons.cloudy_snowing;
        case '3':
          return Icons.snowing;
        case '4':
          return Icons.thunderstorm;
        default:
          return Icons.grain;
      }
    }
    switch (skyCode) {
      case '1':
        return Icons.wb_sunny;
      case '3':
        return Icons.cloud;
      case '4':
        return Icons.cloud_queue;
      default:
        return Icons.help_outline;
    }
  }

  Map<String, int> _convertToGrid(double lat, double lng) {
    const double RE = 6371.00877;
    const double GRID = 5.0;
    const double SLAT1 = 30.0;
    const double SLAT2 = 60.0;
    const double OLON = 126.0;
    const double OLAT = 38.0;
    const int XO = 43;
    const int YO = 136;
    final double DEGRAD = pi / 180.0;
    final double re = RE / GRID;
    final double slat1 = SLAT1 * DEGRAD;
    final double slat2 = SLAT2 * DEGRAD;
    final double olon = OLON * DEGRAD;
    final double olat = OLAT * DEGRAD;
    double sn = tan(pi * 0.25 + slat2 * 0.5) / tan(pi * 0.25 + slat1 * 0.5);
    sn = log(cos(slat1) / cos(slat2)) / log(sn);
    double sf = tan(pi * 0.25 + slat1 * 0.5);
    sf = pow(sf, sn) * cos(slat1) / sn;
    double ro = tan(pi * 0.25 + olat * 0.5);
    ro = re * sf / pow(ro, sn);
    double ra = tan(pi * 0.25 + (lat) * DEGRAD * 0.5);
    ra = re * sf / pow(ra, sn);
    double theta = lng * DEGRAD - olon;
    if (theta > pi) theta -= 2.0 * pi;
    if (theta < -pi) theta += 2.0 * pi;
    theta *= sn;
    final x = (ra * sin(theta) + XO + 0.5).floor();
    final y = (ro - ra * cos(theta) + YO + 0.5).floor();
    return {'x': x, 'y': y};
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              _dateString,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _skyIcon,
                                    size: 45,
                                    color: Colors.grey[800],
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _currentTemp,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _skyCondition,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (_minTemp != null && _maxTemp != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _minTemp!,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.blue,
                                        ),
                                      ),
                                      Text(
                                        ' / ',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      Text(
                                        _maxTemp!,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 12.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _buildTodayScheduleSection(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildScheduleItem(Map<String, dynamic> schedule) {
    final String title = schedule['title'] ?? '제목 없음';
    final String startTime = schedule['startTime'] ?? '';
    final String endTime = schedule['endTime'] ?? '';
    final isTrueAllDay = startTime == '00:00' && endTime == '23:59';

    String timeText;
    try {
      final startDate = DateTime.parse(schedule['startDate']);
      final endDate = DateTime.parse(schedule['endDate']);
      final today = DateTime.now();
      final selectedDay = DateTime(today.year, today.month, today.day);

      final isFirstDay = isSameDay(startDate, selectedDay);
      final isLastDay = isSameDay(endDate, selectedDay);
      final isMultiDay = !isSameDay(startDate, endDate);

      if (isTrueAllDay) {
        final startDateFormat = DateFormat('M. d');
        final endDateFormat = DateFormat('M. d');
        timeText =
            '${startDateFormat.format(startDate)} - ${endDateFormat.format(endDate)}';
      } else if (isMultiDay) {
        if (isLastDay) {
          timeText = '00:00 - $endTime';
        } else if (isFirstDay) {
          timeText = '$startTime 부터';
        } else {
          timeText = "하루종일";
        }
      } else {
        timeText = '$startTime - $endTime';
      }
    } catch (e) {
      timeText = "시간 정보 없음";
    }

    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.lightBlue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                timeText,
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTodayScheduleSection() {
    const int maxDisplayCount = 4;
    final int remainingCount = _todaySchedules.length - maxDisplayCount;

    if (_todaySchedules.isEmpty) {
      return const Center(child: Text('오늘 일정이 없습니다.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._todaySchedules.take(maxDisplayCount).map((schedule) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: _buildScheduleItem(schedule),
          );
        }).toList(),
        if (remainingCount > 0) ...[
          const Spacer(),
          GestureDetector(
            onTap: widget.onNavigateToCalendar,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, size: 16, color: Colors.black54),
                const SizedBox(width: 4),
                Text(
                  '$remainingCount개 일정 더보기',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ],
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

// --- ▼▼▼ [수정] ClothingItem 위젯 (서버 이미지 표시) ▼▼▼ ---
class ClothingItem extends StatelessWidget {
  final Map<String, dynamic>? clothData;
  const ClothingItem({super.key, this.clothData});

  @override
  Widget build(BuildContext context) {
    final imagePathOrUrl = clothData?['clothingImg'] as String?;
    const String serverBaseUrl = 'http://3.36.66.130:5000';

    return GestureDetector(
      onTap: () {
        if (clothData != null) {
          // TODO: 상세 화면으로 이동 (profile_screen.dart의 로직 참고)
          print("Tapped on item: ${clothData!['name'] ?? 'Unknown'}");
          // 예: Navigator.push(context, MaterialPageRoute(builder: (context) => ClothDetailScreen(cloth: clothData!)));
        }
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12.0),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: (imagePathOrUrl != null && imagePathOrUrl.isNotEmpty)
            ? Image.network(
                imagePathOrUrl.startsWith('http')
                    ? imagePathOrUrl
                    : '$serverBaseUrl/$imagePathOrUrl',
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  print("Image load error for $imagePathOrUrl: $error");
                  return const Center(
                    child: Icon(Icons.error_outline, color: Colors.grey),
                  );
                },
              )
            : const Center(
                child: Icon(Icons.checkroom, color: Colors.white, size: 50),
              ),
      ),
    );
  }
}

// --- ▲▲▲ [수정] ClothingItem: '내가 즐겨입는 룩'에서만 사용 ▲▲▲ ---

// --- ▼▼▼ [추가] '오늘의 추천'을 위한 새로운 카드 위젯 ▼▼▼ ---
// (상의/하의/신발 조합 레이아웃)
class RecommendedOutfitCard extends StatelessWidget {
  final Map<String, dynamic> outfitData;
  const RecommendedOutfitCard({super.key, required this.outfitData});

  @override
  Widget build(BuildContext context) {
    final topData = outfitData['top'] as Map<String, dynamic>?;
    final bottomData = outfitData['bottom'] as Map<String, dynamic>?;
    final shoesData = outfitData['shoes'] as Map<String, dynamic>?;

    return Container(
      width: 160, // '내가 즐겨입는 룩'의 ClothingItem과 너비 통일
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
    const String serverBaseUrl = 'http://3.36.66.130:5000';
    final imagePath = itemData?['clothingImg'] as String?;
    final bgColor = Colors.grey[200];

    // --- ▼▼▼ [수정] 이미지가 없는 경우 흰색 배경 + 아이콘 ▼▼▼ ---
    if (itemData == null || imagePath == null || imagePath.isEmpty) {
      return Container(
        width: double.infinity,
        color: bgColor, // 흰색 배경
      );
    }
    // --- ▲▲▲ [수정] 이미지가 없는 경우 흰색 배경 + 아이콘 ▲▲▲ ---

    final imageUrl = imagePath.startsWith('http')
        ? imagePath
        : '$serverBaseUrl/$imagePath';
    return Container(
      width: double.infinity,
      color: Colors.grey[200], // 흰색 배경
      child: Image.network(
        imageUrl,
        fit: BoxFit.contain, // <<< 요청하신대로 contain 적용
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

// --- ▲▲▲ [추가] '오늘의 추천'을 위한 새로운 카드 위젯 ▲▲▲ ---
