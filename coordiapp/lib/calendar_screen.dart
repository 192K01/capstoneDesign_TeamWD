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
  CalendarScreenState createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
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

  Future<void> refreshData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    await _loadSchedulesFromServer();
    if (mounted) {
      await _onDaySelected(_selectedDay ?? DateTime.now(), _focusedDay);
      setState(() {
        _isLoading = false;
      });
    }
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
    // 1. 선택된 날짜에 해당하는 일정 필터링
    _selectedDaySchedules = _allSchedules.where((schedule) {
      if (schedule['startDate'] == null || schedule['endDate'] == null) {
        return false;
      }
      try {
        final startDate = DateTime.parse(schedule['startDate']);
        final endDate = DateTime.parse(schedule['endDate']);

        final normalizedSelectedDate =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        final normalizedStartDate =
        DateTime(startDate.year, startDate.month, startDate.day);
        final normalizedEndDate =
        DateTime(endDate.year, endDate.month, endDate.day);

        return (normalizedSelectedDate.isAtSameMomentAs(normalizedStartDate) ||
            normalizedSelectedDate.isAfter(normalizedStartDate)) &&
            (normalizedSelectedDate.isAtSameMomentAs(normalizedEndDate) ||
                normalizedSelectedDate.isBefore(normalizedEndDate));
      } catch (e) {
        return false;
      }
    }).toList();

    // 2. 새로운 정렬 로직 적용
    _selectedDaySchedules.sort((a, b) {
      // 각 일정이 선택된 날짜(selectedDate)를 기준으로 어떤 유형인지 판단하는 함수
      int getScheduleType(Map<String, dynamic> schedule, DateTime selected) {
        final startDate = DateTime.parse(schedule['startDate']);
        final endDate = DateTime.parse(schedule['endDate']);
        final selectedDay = DateTime(selected.year, selected.month, selected.day);

        final isTrueAllDay = schedule['startTime'] == '00:00' && schedule['endTime'] == '23:59';
        final isFirstDay = isSameDay(startDate, selectedDay);
        final isLastDay = isSameDay(endDate, selectedDay);
        final isMultiDay = !isSameDay(startDate, endDate);

        if (isTrueAllDay) return 1; // 1: 진짜 하루종일 일정
        if (isMultiDay && !isFirstDay && !isLastDay) return 1; // 1: 연속 일정의 중간 날짜
        if (isMultiDay && isLastDay) return 2; // 2: 연속 일정의 마지막 날
        return 3; // 3: 그 외 시간 지정 일정
      }

      final typeA = getScheduleType(a, selectedDate);
      final typeB = getScheduleType(b, selectedDate);

      // 유형에 따라 정렬 (1 -> 2 -> 3 순서)
      if (typeA != typeB) {
        return typeA.compareTo(typeB);
      }

      // 유형이 같다면 시작 시간으로 정렬
      final startTimeA = a['startTime'] ?? '00:00';
      final startTimeB = b['startTime'] ?? '00:00';
      int compare = startTimeA.compareTo(startTimeB);
      if (compare != 0) {
        return compare;
      }

      // 시작 시간도 같으면 기존 순서 유지
      return 0;
    });
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
      barrierColor: Colors.black.withOpacity(0.5),
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
      refreshData();
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
      calendarStyle: const CalendarStyle(
        todayDecoration: BoxDecoration(
          color: Colors.grey,
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        markerDecoration: BoxDecoration(
          color: Colors.lightBlue,
          shape: BoxShape.circle,
        ),
      ),
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: _onDaySelected,
      eventLoader: (day) {
        return _allSchedules.where((schedule) {
          if (schedule['startDate'] == null || schedule['endDate'] == null) {
            return false;
          }
          try {
            final startDate = DateTime.parse(schedule['startDate']);
            final endDate = DateTime.parse(schedule['endDate']);

            final normalizedDay = DateTime.utc(day.year, day.month, day.day);
            final normalizedStartDate =
            DateTime.utc(startDate.year, startDate.month, startDate.day);
            final normalizedEndDate =
            DateTime.utc(endDate.year, endDate.month, endDate.day);

            return (normalizedDay.isAtSameMomentAs(normalizedStartDate) ||
                normalizedDay.isAfter(normalizedStartDate)) &&
                (normalizedDay.isAtSameMomentAs(normalizedEndDate) ||
                    normalizedDay.isBefore(normalizedEndDate));
          } catch (e) {
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
        final location = (schedule['location'] as String?)?.isNotEmpty == true ? schedule['location'] : '위치 정보 없음';
        final startTime = schedule['startTime']?.toString() ?? '';
        final endTime = schedule['endTime']?.toString() ?? '';
        final startDateStr = schedule['startDate']?.toString() ?? '';
        final endDateStr = schedule['endDate']?.toString() ?? '';

        String dateTimeString;

        try {
          final selectedDate = _selectedDay!;
          final startDate = DateTime.parse(startDateStr);
          final endDate = DateTime.parse(endDateStr);

          final isAllDay = (startTime == '00:00' && endTime == '23:59');
          final isSingleDay = isSameDay(startDate, endDate);
          final isFirstDay = isSameDay(selectedDate, startDate);
          final isLastDay = isSameDay(selectedDate, endDate);

          final formattedDate = DateFormat('yy.MM.dd').format(selectedDate);
          final formattedLastDate = DateFormat('yy.MM.dd').format(endDate);
          if (isSingleDay) {
            dateTimeString = isAllDay ? '$formattedDate, 하루종일' : '$startTime - $endTime';
          } else {
            if (isFirstDay) {
              // dateTimeString = isAllDay ? '$formattedDate, 하루종일' : '$startTime - $formattedLastDate $endTime';
              dateTimeString = isAllDay ? '$formattedDate, 하루종일' : '$startTime - 계속';
            } else if (isLastDay) {
              dateTimeString = isAllDay ? '$formattedDate, 하루종일' : '00:00 - $endTime';
            } else {
              dateTimeString = '하루종일';
            }
          }
        } catch (e) {
          dateTimeString = '시간 정보 없음';
        }

        return GestureDetector(
          onTap: () => _showScheduleDetails(schedule),
          child: _buildScheduleItem(
            Colors.lightBlue,
            schedule['title'].toString(),
            dateTimeString,
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
      String dateTimeInfo,
      String location,
      ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: 50,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text(dateTimeInfo, style: const TextStyle(color: Colors.black54, fontSize: 12)),
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

  String _getAlarmText(String? unit, int? value) {
    if (unit == null || value == null || unit == 'none') {
      return '알림 없음';
    }
    switch (unit) {
      case 'minutes':
        return value == 0 ? '정시' : '$value분 전';
      case 'hours':
        return '$value시간 전';
      case 'days':
        return '$value일 전';
      default:
        return '알림 없음';
    }
  }

  // --- ▼▼▼ [수정] 날짜/시간 포맷팅 로직 변경 ▼▼▼ ---
  String _formatScheduleDateTime(Map<String, dynamic> schedule) {
    final String? startDateStr = schedule['startDate'] as String?;
    final String? endDateStr = schedule['endDate'] as String?;
    final String? startTimeStr = schedule['startTime'] as String?;
    final String? endTimeStr = schedule['endTime'] as String?;

    if (startDateStr == null || endDateStr == null || startTimeStr == null || endTimeStr == null) {
      return "날짜/시간 정보 없음";
    }

    try {
      final startDate = DateTime.parse(startDateStr);
      final endDate = DateTime.parse(endDateStr);

      final isAllDay = (startTimeStr == '00:00' && endTimeStr == '23:59');
      final isSingleDay = isSameDay(startDate, endDate);

      final dateFormat = DateFormat('yy.MM.dd.(E)', 'ko_KR');
      final dateTimeFormat = DateFormat('yy.MM.dd.(E) HH:mm', 'ko_KR');

      if (isSingleDay) {
        // 1. 종일 일정 (당일)
        if (isAllDay) {
          return '${dateFormat.format(startDate)} 하루 종일';
        }
        // 2. 시간 일정 (당일)
        else {
          return '${dateFormat.format(startDate)} $startTimeStr - $endTimeStr';
        }
      } else {
        // 3. 종일 일정 (연속)
        if (isAllDay) {
          return '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}';
        }
        // 4. 시간 일정 (연속)
        else {
          final fullStartDate = DateTime.parse('${startDateStr.substring(0, 10)}T$startTimeStr');
          final fullEndDate = DateTime.parse('${endDateStr.substring(0, 10)}T$endTimeStr');
          return '${dateTimeFormat.format(fullStartDate)} - ${dateTimeFormat.format(fullEndDate)}';
        }
      }
    } catch (e) {
      return "날짜/시간 형식 오류";
    }
  }
  // --- ▲▲▲ [수정] 날짜/시간 포맷팅 로직 변경 ▲▲▲ ---

  @override
  Widget build(BuildContext context) {
    final String title = (schedule['title'] as String?) ?? '제목 없음';
    // --- ▼▼▼ [수정] _formatScheduleDateTime 메서드 호출로 변경 ▼▼▼ ---
    final String dateRange = _formatScheduleDateTime(schedule);
    // --- ▲▲▲ [수정] _formatScheduleDateTime 메서드 호출로 변경 ▲▲▲ ---
    final String? locationName = (schedule['location'] as String?)?.isNotEmpty == true ? schedule['location'] as String : null;
    final String? locationAddress = (schedule['locationAddress'] as String?)?.isNotEmpty == true ? schedule['locationAddress'] as String : null;
    final String? tpo1 = (schedule['tpo1'] as String?)?.isNotEmpty == true ? schedule['tpo1'] as String : null;
    final String? tpo2 = (schedule['tpo2'] as String?)?.isNotEmpty == true ? schedule['tpo2'] as String : null;
    final String explanation = (schedule['explanation'] as String?) ?? '설명 없음';
    final List<String> participants = (schedule['participants'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? [];
    final String alarmText = _getAlarmText(schedule['alarmUnit'] as String?, schedule['alarmValue'] as int?);

    return Dialog(
      alignment: Alignment.bottomCenter,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.only(bottom: 10, left: 10, right: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(onPressed: (){}, icon: const Icon(Icons.delete_outline)),
                  Column(
                    children: [
                      const Text('내 일정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('기본일정', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 45,
                      margin: const EdgeInsets.only(top: 4, right: 12),
                      decoration: BoxDecoration(
                        color: Colors.lightBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(dateRange, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: (){}, icon: const Icon(Icons.edit_outlined), constraints: const BoxConstraints()),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 110,
                      child: _buildInfoCard('알림설정', [alarmText], Icons.notifications_outlined),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 110,
                      child: _buildInfoCard('참가자', participants, Icons.people_outline),
                    ),
                  ),
                ],
              ),
              if (locationName != null) ...[
                const SizedBox(height: 16),
                _buildSectionCard(
                  icon: Icons.location_on_outlined,
                  title: locationName,
                  subtitle: locationAddress,
                ),
              ],
              if (tpo1 != null) ...[
                const SizedBox(height: 16),
                _buildSectionCard(
                  icon: Icons.sell_outlined,
                  title: tpo1,
                  subtitle: tpo2,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: Container(
                        height: 232,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12)
                        ),
                        child: const Center(child: Text("Look 정보 없음")),
                      )
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 110,
                          child: _buildInfoCard('날씨', ["정보 없음"], Icons.thermostat),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 110,
                          child: _buildInfoCard('설명', [explanation], Icons.notes),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, List<String> items, IconData icon) {
    final validItems = items.where((item) => item.isNotEmpty && item != '설명 없음').toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (validItems.isEmpty)
            Row(
              children: [
                Icon(icon, size: 16, color: Colors.grey[700]),
                const SizedBox(width: 8),
                const Expanded(child: Text("정보 없음", overflow: TextOverflow.ellipsis)),
              ],
            )
          else
            ...validItems.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12))),
                ],
              ),
            )).toList(),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required IconData icon, required String title, String? subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[800]),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              if (subtitle != null && subtitle.isNotEmpty)
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
            ],
          ),
        ],
      ),
    );
  }
}