import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:convert';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'schedule_add.dart'; // 일정 추가 화면 import

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Map<String, dynamic>> _allSchedules = [];
  List<Map<String, dynamic>> _selectedDaySchedules = [];
  bool _isLoading = true;
  bool _isWeatherLoading = false;

  String _dateString = "";
  String _skyCondition = "로딩 중...";
  IconData _skyIcon = Icons.cloud_outlined;
  String? _minTemp;
  String? _maxTemp;

  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // ▼▼▼ [수정] 서버에서 일정 데이터를 불러오도록 변경 ▼▼▼
    await _loadSchedulesFromServer();
    // ▲▲▲ [수정] 서버에서 일정 데이터를 불러오도록 변경 ▲▲▲
    try {
      _currentPosition = await _getCurrentLocation();
    } catch (e) {
      if (mounted) setState(() => _skyCondition = e.toString());
    }
    await _onDaySelected(_selectedDay!, _focusedDay);
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- ▼▼▼ [수정] 서버에서 스케줄 데이터를 불러오는 함수 ▼▼▼ ---
  Future<void> _loadSchedulesFromServer() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail');

    if (userEmail == null) {
      // 이메일이 없으면 더 이상 진행하지 않음
      if (mounted) {
        setState(() {
          _allSchedules = [];
        });
      }
      return;
    }

    const serverIp = '3.36.66.130';
    final url = Uri.parse('http://$serverIp:5000/schedule/$userEmail');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _allSchedules = List<Map<String, dynamic>>.from(data);
            // 화면이 처음 로드될 때 오늘 날짜의 일정을 필터링
            _filterSchedules(_selectedDay ?? DateTime.now());
          });
        }
      } else {
        // 오류 처리
        debugPrint('Failed to load schedules: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error loading schedules: $e');
    }
  }
  // --- ▲▲▲ [수정] 서버에서 스케줄 데이터를 불러오는 함수 ▲▲▲ ---


  void _filterSchedules(DateTime selectedDate) {
    _selectedDaySchedules = _allSchedules.where((schedule) {
      // startDate 키가 null이 아니고 유효한 날짜 형식인지 확인
      if (schedule['startDate'] == null) return false;
      try {
        final startDate = DateTime.parse(schedule['startDate']);
        return isSameDay(startDate, selectedDate);
      } catch (e) {
        return false;
      }
    }).toList();
  }


  Future<void> _setDateString(DateTime date) async {
    _dateString = DateFormat('M. d. E', 'ko_KR').format(date);
  }

  Future<void> _onDaySelected(DateTime selectedDay, DateTime focusedDay) async {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      _isWeatherLoading = true;
      _filterSchedules(selectedDay);
      _setDateString(selectedDay);
    });

    if (_currentPosition != null) {
      await _fetchWeather(_currentPosition!, selectedDay);
    }

    if (mounted) {
      setState(() {
        _isWeatherLoading = false;
      });
    }
  }

  // ... (날씨 관련 함수들은 기존과 동일하여 생략) ...
  Future<void> _fetchWeather(Position position, DateTime date) async {
    await Future.wait([
      _fetchCurrentWeather(position.latitude, position.longitude, date),
      _fetchMinMaxTemp(position.latitude, position.longitude, date)
    ]);
  }
  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('위치 서비스 비활성화');
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('위치 권한 거부');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return Future.error('위치 권한 영구 거부');
    }
    return await Geolocator.getCurrentPosition();
  }
  Future<void> _fetchCurrentWeather(double lat, double lng, DateTime date) async {
    try {
      const apiKey = 'ymOBx1J3Se-jgcdSdynvFg';
      String baseDate = DateFormat('yyyyMMdd').format(date);
      String baseTime = DateFormat('HH').format(date) + '00';
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
  Future<void> _fetchMinMaxTemp(double lat, double lng, DateTime date) async {
    try {
      const apiKey = 'ymOBx1J3Se-jgcdSdynvFg';
      final baseDate = DateFormat('yyyyMMdd').format(date);
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
          String tmn = '', tmx = '';
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
      case '0': return ''; case '1': return '비'; case '2': return '비/눈';
      case '3': return '눈'; case '4': return '소나기'; case '5': return '빗방울';
      case '6': return '빗방울/눈날림'; case '7': return '눈날림';
      default: return '';
    }
  }
  String _getSkyString(String skyCode) {
    switch (skyCode) {
      case '1': return '맑음'; case '3': return '구름많음'; case '4': return '흐림';
      default: return '정보 없음';
    }
  }
  IconData _getWeatherIcon(String skyCode, String ptyCode) {
    if (ptyCode.isNotEmpty && ptyCode != '0') {
      switch (ptyCode) {
        case '1': return Icons.umbrella; case '2': return Icons.cloudy_snowing;
        case '3': return Icons.snowing; case '4': return Icons.thunderstorm;
        default: return Icons.grain;
      }
    }
    switch (skyCode) {
      case '1': return Icons.wb_sunny; case '3': return Icons.cloud;
      case '4': return Icons.cloud_queue; default: return Icons.help_outline;
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


  void _showScheduleDetails(Map<String, dynamic> schedule) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return ScheduleDetailDialog(schedule: schedule);
      },
    );
  }

  // --- ▼▼▼ [추가] 일정 추가 화면으로 이동하고, 돌아왔을 때 새로고침하는 함수 ▼▼▼ ---
  void _navigateAndRefresh() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScheduleAddScreen()),
    );

    // 일정 추가 화면에서 '저장'을 성공적으로 마치고 돌아왔을 때 (result == true)
    // 서버에서 데이터를 다시 불러와 화면을 새로고침합니다.
    if (result == true) {
      setState(() {
        _isLoading = true; // 로딩 시작
      });
      await _loadSchedulesFromServer(); // 서버에서 최신 데이터 다시 로드
      setState(() {
        _isLoading = false; // 로딩 종료
      });
    }
  }
  // --- ▲▲▲ [추가] 일정 추가 화면으로 이동하고, 돌아왔을 때 새로고침하는 함수 ▲▲▲ ---

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const IconButton(
          icon: Icon(Icons.menu, color: Colors.black),
          onPressed: null,
        ),
        title: const Text('Calendar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.today, color: Colors.black),
            onPressed: () => _onDaySelected(DateTime.now(), DateTime.now()),
          ),
          const IconButton(
            icon: Icon(Icons.notifications_outlined, color: Colors.black),
            onPressed: null,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
      // ▼▼▼ [수정] 원하시는 대로 레이아웃 재구성 ▼▼▼
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 달력 (스크롤 X, 좌우 여백 16)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildCalendar(),
          ),
          const SizedBox(height: 3),

          // 2. Schedule 헤더 (스크롤 X, 좌우 여백 16)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildScheduleHeader(),
          ),
          // const SizedBox(height: 8),

          // 3. 스크롤이 필요한 나머지 카드 부분만 Expanded와 ListView로 처리
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                _buildCombinedScheduleCard(),
              ],
            ),
          ),
        ],
      ),
      // ▲▲▲ [수정] 원하시는 대로 레이아웃 재구성 ▲▲▲
    );
  }

  Widget _buildCalendar() {
    // ... (기존과 동일) ...
    return TableCalendar(
      locale: 'ko_KR',
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      headerStyle: const HeaderStyle(
        titleCentered: true,
        formatButtonVisible: false,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        leftChevronIcon: Icon(Icons.chevron_left, color: Colors.black),
        rightChevronIcon: Icon(Icons.chevron_right, color: Colors.black),
      ),
      calendarStyle: const CalendarStyle(
        todayDecoration: BoxDecoration(
          color: Colors.grey,
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: _onDaySelected,
      // ▼▼▼ [추가] 이벤트 마커 표시를 위한 설정 ▼▼▼
      eventLoader: (day) {
        return _allSchedules.where((schedule) {
          if (schedule['startDate'] == null) return false;
          try {
            final startDate = DateTime.parse(schedule['startDate']);
            return isSameDay(startDate, day);
          } catch(e) {
            return false;
          }
        }).toList();
      },
      // ▲▲▲ [추가] 이벤트 마커 표시를 위한 설정 ▲▲▲
    );
  }

  Widget _buildScheduleHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "Schedule",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        // ▼▼▼ [수정] '+' 아이콘을 누르면 일정 추가 화면으로 이동 ▼▼▼
        IconButton(
          icon: const Icon(Icons.add, color: Colors.black),
          onPressed: _navigateAndRefresh,
        ),
        // ▲▲▲ [수정] '+' 아이콘을 누르면 일정 추가 화면으로 이동 ▲▲▲
      ],
    );
  }

  Widget _buildCombinedScheduleCard() {
    // ... (기존과 동일) ...
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildDateWeatherCard(),
                const SizedBox(height: 3),
                _buildLooksCard(),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(flex: 3, child: _buildScheduleList()),
        ],
      ),
    );
  }

  Widget _buildDateWeatherCard() {
    // ... (기존과 동일) ...
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: _isWeatherLoading
          ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
          : Column(
        children: [
          Text(
            _dateString,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_skyIcon, color: Colors.grey[800], size: 20),
              const SizedBox(width: 8),
              Text(
                _skyCondition,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[800], fontSize: 14),
              ),
            ],
          ),
          if (_minTemp != null && _maxTemp != null)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_minTemp!, style: const TextStyle(fontSize: 10, color: Colors.blue)),
                  Text(' / ', style: TextStyle(fontSize: 10, color: Colors.grey[700])),
                  Text(_maxTemp!, style: const TextStyle(fontSize: 10, color: Colors.red)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLooksCard() {
    // ... (기존과 동일) ...
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Looks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            // ▼▼▼ [수정] '+' 아이콘 버튼으로 변경 ▼▼▼
            IconButton(
                onPressed: () { /* TODO: Looks 추가 기능 */},
                icon: const Icon(Icons.add, size: 20)
            ),
            // ▲▲▲ [수정] '+' 아이콘 버튼으로 변경 ▲▲▲
          ],
        ),
        // const SizedBox(height: 0),
        Container(
          height: 170,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(Icons.checkroom, color: Colors.white, size: 50),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleList() {
    if (_selectedDaySchedules.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: Text('선택된 날짜에 일정이 없습니다.')),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _selectedDaySchedules.length,
      itemBuilder: (context, index) {
        final schedule = _selectedDaySchedules[index];
        // ▼▼▼ [수정] location_name 대신 location을 사용하도록 변경 ▼▼▼
        final location = schedule['location']?.toString() ?? '위치 정보 없음';

        return GestureDetector(
          onTap: () => _showScheduleDetails(schedule),
          child: _buildScheduleItem(
            Colors.lightBlue,
            schedule['title'].toString(),
            schedule['startDate'].toString(),
            location,
          ),
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 16),
    );
  }

  Widget _buildScheduleItem(
      Color color,
      String title,
      String date,
      String location,
      ) {
    return Row(
      // ▼▼▼ [수정] crossAxisAlignment를 center로 변경하여 세로 중앙 정렬 ▼▼▼
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ▼▼▼ [수정] Container에 decoration을 사용하여 둥근 모서리 적용 ▼▼▼
        Container(
          width: 4,
          height: 55, // 높이를 약간 줄여서 중앙에 더 잘 맞게 조정
          decoration: BoxDecoration(
            color: color, // 색상은 여기서 지정
            borderRadius: BorderRadius.circular(10), // 모서리를 둥글게
          ),
        ),
        // ▲▲▲ [수정] Container에 decoration을 사용하여 둥근 모서리 적용 ▲▲▲
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text(date, style: const TextStyle(color: Colors.black54, fontSize: 12)),
              const SizedBox(height: 4),
              Text(location, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class ScheduleDetailDialog extends StatelessWidget {
  final Map<String, dynamic> schedule;
  const ScheduleDetailDialog({super.key, required this.schedule});

  @override
  Widget build(BuildContext context) {
    // ▼▼▼ [수정] 서버에서 받아온 키 이름에 맞게 변경 ▼▼▼
    final location = schedule['location']?.toString() ?? '정보 없음';
    final explanation = schedule['explanation']?.toString() ?? '설명 없음';
    final startDate = schedule['startDate']?.toString() ?? '';
    final endDate = schedule['endDate']?.toString() ?? '';
    // ▲▲▲ [수정] 서버에서 받아온 키 이름에 맞게 변경 ▲▲▲

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.delete_outline),
                  const Text('내 일정', style: TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(width: 5, height: 40, color: Colors.purple),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(schedule['title'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        Text('$startDate - $endDate', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_outlined),
                ],
              ),
              const SizedBox(height: 20),
              _buildDetailSection(title: '알림설정', content: '시작시간 알림\n10분 전 알림'),
              _buildDetailSection(title: '참가자', content: 'ava9797@hs.ac.kr\nkdhok2285@hs.ac.kr'),
              _buildDetailSection(title: '위치', content: location),
              _buildDetailSection(title: 'TPO', content: '정보 없음'), // category 정보가 없으므로 '정보 없음'으로 표시
              _buildDetailSection(title: '날씨', content: '날씨 정보 불러오는 중...'),
              _buildDetailSection(title: '설명', content: explanation),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection({required String title, required String content}) {
    // ... (기존과 동일) ...
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(content),
          const SizedBox(height: 8),
          const Divider(),
        ],
      ),
    );
  }
}