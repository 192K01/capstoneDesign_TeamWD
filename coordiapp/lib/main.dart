// 📂 lib/main.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:io' show Platform;
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
      home: const SplashScreen(),
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

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      HomeScreen(onNavigateToCalendar: () => _navigateToCalendarTab()),
      const SearchScreen(),
      CalendarScreen(key: _calendarScreenKey),
      ProfileScreen(key: _profileScreenKey),
    ];
  }

  void _navigateToCalendarTab() {
    setState(() {
      _selectedIndex = 2;
    });
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      setState(() => _isMenuOpen = !_isMenuOpen);
    } else {
      int pageIndex = index > 2 ? index - 1 : index;
      setState(() {
        _selectedIndex = pageIndex;
        if (_isMenuOpen) _isMenuOpen = false;
      });
      if (pageIndex == 3) {
        _profileScreenKey.currentState?.performSearch();
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

class HomeScreen extends StatelessWidget {
  final VoidCallback onNavigateToCalendar;
  const HomeScreen({super.key, required this.onNavigateToCalendar});

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
          children: [
            TodayInfoCard(onNavigateToCalendar: onNavigateToCalendar),
            const SizedBox(height: 30),
            const RecommendationSection(title: '오늘의 추천'),
            const SizedBox(height: 30),
            const RecommendationSection(title: '내가 즐겨입는 룩'),
          ],
        ),
      ),
    );
  }
}

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
        final List<dynamic> allSchedules =
        jsonDecode(utf8.decode(response.bodyBytes));
        final today = DateTime.now();

        final todaySchedules = allSchedules.where((schedule) {
          try {
            final startDate = DateTime.parse(schedule['startDate']);
            final endDate = DateTime.parse(schedule['endDate']);
            final normalizedToday =
            DateTime(today.year, today.month, today.day);
            return (normalizedToday.isAtSameMomentAs(startDate) ||
                normalizedToday.isAfter(startDate)) &&
                (normalizedToday.isAtSameMomentAs(endDate) ||
                    normalizedToday.isBefore(endDate));
          } catch (e) {
            return false;
          }
        }).toList();

        todaySchedules.sort((a, b) {
          int getScheduleType(Map<String, dynamic> schedule, DateTime selected) {
            final startDate = DateTime.parse(schedule['startDate']);
            final endDate = DateTime.parse(schedule['endDate']);
            final selectedDay =
            DateTime(selected.year, selected.month, selected.day);

            final isTrueAllDay =
                schedule['startTime'] == '00:00' && schedule['endTime'] == '23:59';
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
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
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
                              mainAxisAlignment:
                              MainAxisAlignment.center,
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
                  vertical: 8.0, horizontal: 12.0),
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
        ]
      ],
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
        timeText = '${startDateFormat.format(startDate)} - ${endDateFormat.format(endDate)}';
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
                style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
            child: Icon(Icons.checkroom, color: Colors.white, size: 50),
          ),
        ),
      ),
    );
  }
}