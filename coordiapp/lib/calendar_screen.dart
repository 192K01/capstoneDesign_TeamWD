import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:convert';
import '../data/database_helper.dart'; // 데이터베이스 헬퍼 import
import 'dart:math';
import 'package:geolocator/geolocator.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Map<String, dynamic>> _scheduleData = []; // 타입을 명확히 지정
  bool _isLoading = true;

  final dbHelper = DatabaseHelper.instance;

  String _dateString = "";
  String _currentTemp = "";
  String _skyCondition = "로딩 중...";
  IconData _skyIcon = Icons.cloud_outlined;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadSchedulesFromDb(),
      _setDateString(),
      _fetchWeather(),
    ]);
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // DB에서 스케줄 데이터를 불러오는 함수
  Future<void> _loadSchedulesFromDb() async {
    final data = await dbHelper.getSchedules();
    if (mounted) {
      setState(() {
        _scheduleData = data;
      });
    }
  }

  Future<void> _setDateString() async {
    _dateString = DateFormat('M. d. E', 'ko_KR').format(DateTime.now());
  }

  Future<void> _fetchWeather() async {
    try {
      final position = await _getCurrentLocation();
      await _fetchCurrentWeather(position.latitude, position.longitude);
    } catch (e) {
      if (mounted) setState(() => _skyCondition = e.toString());
    }
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
      const apiKey = 'ymOBx1J3Se-jgcdSdynvFg'; // 기상청 API 키
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

  void _showScheduleDetails(Map<String, dynamic> schedule) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return ScheduleDetailDialog(schedule: schedule);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(Icons.menu, color: Colors.black),
            const Text(
              'Calender',
              style: TextStyle(
                color: Color.fromARGB(255, 96, 21, 112),
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            const Icon(Icons.notifications_outlined, color: Colors.black),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                _buildCalendar(),
                const SizedBox(height: 24),
                _buildScheduleHeader(),
                const SizedBox(height: 16),
                _buildCombinedScheduleCard(),
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
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
    );
  }

  Widget _buildScheduleHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "Today's schedule",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Icon(Icons.add, color: Colors.black),
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
                const SizedBox(height: 12),
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
      child: Column(
        children: [
          Text(
            _dateString,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_skyIcon, color: Colors.grey[800], size: 20),
              const SizedBox(width: 8),
              Text(
                '$_currentTemp $_skyCondition',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[800], fontSize: 14),
              ),
            ],
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
            const Text(
              'Looks',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Icon(Icons.add, size: 20),
          ],
        ),
        const SizedBox(height: 8),
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
    if (_scheduleData.isEmpty) {
      return const SizedBox(
        height: 100, // 일정이 없을 때도 최소 높이를 주어 UI가 깨지지 않게 함
        child: Center(child: Text('일정이 없습니다.')),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _scheduleData.length,
      itemBuilder: (context, index) {
        final schedule = _scheduleData[index];
        Color itemColor = Colors.purple; // 기본 색상

        return GestureDetector(
          onTap: () => _showScheduleDetails(schedule),
          child: _buildScheduleItem(
            itemColor,
            schedule['title'].toString(),
            schedule['startDate'].toString(),
            schedule['location'].toString(),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 4, height: 50, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                location,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// 상세 일정 팝업 Dialog 위젯
class ScheduleDetailDialog extends StatelessWidget {
  final Map<String, dynamic> schedule;
  const ScheduleDetailDialog({super.key, required this.schedule});

  @override
  Widget build(BuildContext context) {
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
                  const Text(
                    '내 일정',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
                        Text(
                          schedule['title'],
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${schedule['startDate']} - ${schedule['endDate']}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_outlined),
                ],
              ),
              const SizedBox(height: 20),

              _buildDetailSection(title: '알림설정', content: '시작시간 알림\n10분 전 알림'),
              _buildDetailSection(
                title: '참가자',
                content: 'ava9797@hs.ac.kr\nkdhok2285@hs.ac.kr',
              ),
              _buildDetailSection(title: '위치', content: schedule['location']),
              _buildDetailSection(
                title: 'TPO',
                content: schedule['category'].toString(),
              ),
              _buildDetailSection(title: '날씨', content: '날씨 정보 불러오는 중...'),
              _buildDetailSection(
                title: '설명',
                content: schedule['explanation'],
              ),
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
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(content),
          const SizedBox(height: 8),
          const Divider(),
        ],
      ),
    );
  }
}
