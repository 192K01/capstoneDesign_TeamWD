// 📂 lib/calendar_screen.dart

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
    await _loadSchedulesFromServer();
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

  Future<void> _loadSchedulesFromServer() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail');

    if (userEmail == null) {
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
            _filterSchedules(_selectedDay ?? DateTime.now());
          });
        }
      } else {
        debugPrint('Failed to load schedules: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error loading schedules: $e');
    }
  }

  void _filterSchedules(DateTime selectedDate) {
    _selectedDaySchedules = _allSchedules.where((schedule) {
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

  void _navigateAndRefresh() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScheduleAddScreen()),
    );

    if (result == true) {
      setState(() {
        _isLoading = true;
      });
      await _loadSchedulesFromServer();
      setState(() {
        _isLoading = false;
      });
    }
  }

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
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildCalendar(),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildScheduleHeader(),
          ),
          const SizedBox(height: 0),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 3, 16, 16),
              children: [
                _buildCombinedScheduleCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
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
      // ▼▼▼ [수정] calendarStyle에 markerDecoration 속성 추가 ▼▼▼
      calendarStyle: const CalendarStyle(
        todayDecoration: BoxDecoration(
          color: Colors.grey,
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        // 마커(점)의 스타일을 지정합니다.
        markerDecoration: BoxDecoration(
          color: Colors.lightBlue, // 이 부분을 원하는 색상으로 변경하세요. (예: Colors.blue)
          shape: BoxShape.circle,
        ),
      ),
      // ▲▲▲ [수정] calendarStyle에 markerDecoration 속성 추가 ▲▲▲
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: _onDaySelected,
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
        IconButton(
          icon: const Icon(Icons.add, color: Colors.black),
          onPressed: _navigateAndRefresh,
        ),
      ],
    );
  }

  Widget _buildCombinedScheduleCard() {
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
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Looks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(
                onPressed: () { /* TODO: Looks 추가 기능 */},
                icon: const Icon(Icons.add, size: 20)
            ),
          ],
        ),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
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
    // ▼▼▼ [수정] 서버에서 받아온 participants 키 사용 ▼▼▼
    final location = schedule['location']?.toString() ?? '정보 없음';
    final explanation = schedule['explanation']?.toString() ?? '설명 없음';
    final startDate = schedule['startDate']?.toString() ?? '';
    final endDate = schedule['endDate']?.toString() ?? '';
    final participants = schedule['participants']?.toString() ?? '참가자 없음';
    // ▲▲▲ [수정] 서버에서 받아온 participants 키 사용 ▲▲▲

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
              // ▼▼▼ [수정] 하드코딩된 이메일 대신 서버에서 받은 participants 데이터 표시 ▼▼▼
              _buildDetailSection(title: '참가자', content: participants),
              // ▲▲▲ [수정] 하드코딩된 이메일 대신 서버에서 받은 participants 데이터 표시 ▲▲▲
              _buildDetailSection(title: '위치', content: location),
              _buildDetailSection(title: 'TPO', content: '정보 없음'),
              _buildDetailSection(title: '날씨', content: '날씨 정보 불러오는 중...'),
              _buildDetailSection(title: '설명', content: explanation),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection({required String title, required String content}) {
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