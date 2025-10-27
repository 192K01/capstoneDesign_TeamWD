// 📂 lib/calendar_screen.dart
// [수정됨] 날씨 API 호출을 캐시하도록 로직 변경

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:convert';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'schedule_add.dart';
import 'package:flutter/cupertino.dart';


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
  String _currentTemp = "";
  String _skyCondition = "로딩 중...";
  IconData _skyIcon = Icons.cloud_outlined;
  String? _minTemp;
  String? _maxTemp;

  Position? _currentPosition;

  Map<String, dynamic>? _recommendedOutfit;
  bool _isRecommendLoading = true;
  String _recommendStatus = "Looks 로딩 중...";
  double? _rawTempForApi;

  // --- ▼▼▼ [신규] 날씨 캐시를 위한 상태 변수 추가 ▼▼▼ ---
  DateTime? _lastWeatherFetchTime; // 마지막으로 날씨를 가져온 시간
  DateTime? _lastWeatherFetchDay; // 마지막으로 날씨를 가져온 *날짜*
  // --- ▲▲▲ [신규] 날씨 캐시를 위한 상태 변수 추가 ▲▲▲ ---

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadInitialData();
  }

  Future<void> refreshData() async {
    // [수정] 새로고침 시 캐시 초기화
    _lastWeatherFetchTime = null;
    _lastWeatherFetchDay = null;

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

    _filterSchedules(_selectedDay!);
    _setDateString(_selectedDay!);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    _loadSecondaryData();
  }


  Future<void> _loadSecondaryData() async {
    if (mounted) {
      setState(() {
        _isWeatherLoading = true;
        _isRecommendLoading = true;
        _skyCondition = "로딩 중...";
      });
    }

    Position? fetchedPosition;
    String? locationError;

    try {
      fetchedPosition = await _getCurrentLocation();
    } catch (e) {
      locationError = e.toString();
    }

    if (mounted) {
      setState(() {
        if (fetchedPosition != null) {
          _currentPosition = fetchedPosition;
        }
        if (locationError != null) {
          _skyCondition = locationError;
        }
      });
    }

    if (_currentPosition != null) {
      // (기존) 날씨 로드
      await _fetchWeather(_currentPosition!, _selectedDay!);

      // (신규) 날씨 로드 성공 시 캐시 시간 저장
      if (mounted) {
        _lastWeatherFetchTime = DateTime.now();
        _lastWeatherFetchDay = _selectedDay;
        setState(() {
          _isWeatherLoading = false;
        });
      }
    }

    await _getRecommendation();
  }

  // ( ... _loadSchedulesFromServer, _filterSchedules, _setDateString ... )
  // (기존 코드와 동일)

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

    const serverIp = '3.36.66.130'; // 실제 서버 IP로 변경하세요
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

    _selectedDaySchedules.sort((a, b) {
      int getScheduleType(Map<String, dynamic> schedule, DateTime selected) {
        final startDate = DateTime.parse(schedule['startDate']);
        final endDate = DateTime.parse(schedule['endDate']);
        final selectedDay = DateTime(selected.year, selected.month, selected.day);

        final isTrueAllDay = schedule['startTime'] == '00:00' && schedule['endTime'] == '23:59';
        final isFirstDay = isSameDay(startDate, selectedDay);
        final isLastDay = isSameDay(endDate, selectedDay);
        final isMultiDay = !isSameDay(startDate, endDate);

        if (isTrueAllDay) return 1;
        if (isMultiDay && !isFirstDay && !isLastDay) return 1;
        if (isMultiDay && isLastDay) return 2;
        return 3;
      }

      final typeA = getScheduleType(a, selectedDate);
      final typeB = getScheduleType(b, selectedDate);

      if (typeA != typeB) {
        return typeA.compareTo(typeB);
      }

      final startTimeA = a['startTime'] ?? '00:00';
      final startTimeB = b['startTime'] ?? '00:00';
      int compare = startTimeA.compareTo(startTimeB);
      if (compare != 0) {
        return compare;
      }

      return 0;
    });
  }


  Future<void> _setDateString(DateTime date) async {
    _dateString = DateFormat('M. d. E', 'ko_KR').format(date);
  }

  // --- ▼▼▼ [핵심 수정] _onDaySelected에 캐시 로직 적용 ▼▼▼ ---
  Future<void> _onDaySelected(DateTime selectedDay, DateTime focusedDay) async {

    // 1. (공통) 날짜 및 일정 필터링은 항상 실행
    _selectedDay = selectedDay;
    _focusedDay = focusedDay;
    _filterSchedules(selectedDay);
    _setDateString(selectedDay);

    // 2. 캐시 유효성 검사
    bool isCacheValid = false;
    final bool isToday = isSameDay(selectedDay, DateTime.now());

    if (_lastWeatherFetchTime != null &&
        _lastWeatherFetchDay != null &&
        isSameDay(_lastWeatherFetchDay!, selectedDay)) {

      // A. 캐시가 '오늘' 날짜에 대한 것이라면, 1시간 유효
      if (isToday) {
        if (DateTime.now().difference(_lastWeatherFetchTime!) <
            const Duration(hours: 1)) {
          isCacheValid = true;
        }
      }
      // B. 캐시가 '과거/미래' 날짜에 대한 것이라면, 항상 유효
      else {
        isCacheValid = true;
      }
    }

    // 3. 캐시 상태에 따라 분기
    if (isCacheValid) {
      // [캐시 사용] 날씨는 그대로 두고, 코디 추천만 새로고침
      debugPrint("날씨 캐시 사용: $selectedDay");

      setState(() {
        // 날씨 관련 state는 재설정하지 않음 (로딩 스피너 X)
        // 코디 관련 state만 재설정
        _isRecommendLoading = true;
        _recommendedOutfit = null;
        _recommendStatus = "Looks 로딩 중...";
      });

      // 날씨(_rawTempForApi)는 캐시된 값을 사용
      await _getRecommendation();

    } else {
      // [캐시 무효화] 날씨와 코디 모두 새로고침 (기존 로직)
      debugPrint("날씨 캐시 무효화. API 호출: $selectedDay");

      // 1. 모든 관련 상태 변수를 리셋
      _isWeatherLoading = true; // 날씨 로딩 스피너 활성화
      _currentTemp = "";
      _skyCondition = "로딩 중...";
      _minTemp = null;
      _maxTemp = null;
      _rawTempForApi = null;

      _isRecommendLoading = true;
      _recommendedOutfit = null;
      _recommendStatus = "Looks 로딩 중...";

      // 2. 위에서 변경된 모든 상태를 UI에 한 번에 반영
      setState(() {
        // 이 블록은 UI 갱신을 트리거
      });

      // 3. 비동기 데이터 로드
      if (_currentPosition != null) {
        await _fetchWeather(_currentPosition!, selectedDay);
      }

      await _getRecommendation(); // 날씨 로드 후 코디 추천

      // 4. (신규) 새 데이터를 캐시에 저장
      _lastWeatherFetchTime = DateTime.now();
      _lastWeatherFetchDay = selectedDay;

      // 5. 날씨 로딩 상태 해제
      if (mounted) {
        setState(() {
          _isWeatherLoading = false;
        });
      }
    }
  }
  // --- ▲▲▲ [핵심 수정] _onDaySelected에 캐시 로직 적용 ▲▲▲ ---

  // ( ... _fetchWeather, _getCurrentLocation, _fetchTodayWeather ... )
  // ( ... _fetchCombinedForecast, _getPtyString, _getSkyString ... )
  // ( ... _getWeatherIcon, _convertToGrid, _deleteSchedule ... )
  // ( ... _showScheduleDetails, _navigateAndRefresh, build ... )
  // ( ... _buildCalendar, _buildScheduleHeader, _buildCombinedScheduleCard ... )
  // ( ... _buildDateWeatherCard, _buildLooksCard, _buildScheduleList ... )
  // ( ... _buildScheduleItem, _getTpoForSelectedDay, _getRecommendation ... )
  // ( ... ScheduleDetailDialog, RecommendedOutfitCard ... )
  // (*** 나머지 함수들은 이전과 동일합니다 ***)

  // (복사 편의를 위해 수정되지 않은 함수들도 아래에 포함합니다)

  Future<void> _fetchWeather(Position position, DateTime date) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(date.year, date.month, date.day);

    final bool isToday = selected.isAtSameMomentAs(today);
    final int dayDifference = selected.difference(today).inDays;

    if (isToday) {
      await Future.wait([
        _fetchTodayWeather(position.latitude, position.longitude),
        _fetchCombinedForecast(position.latitude, position.longitude, date)
      ]);
    }
    else if ((dayDifference > 0 && dayDifference <= 2) || (dayDifference < 0)) {
      await _fetchCombinedForecast(position.latitude, position.longitude, date);
    }
    else {
      if (mounted) {
        _rawTempForApi = null;
        setState(() {
          _currentTemp = "";
          _skyCondition = "예보 없음";
          _skyIcon = Icons.help_outline;
          _minTemp = null;
          _maxTemp = null;
        });
      }
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
      if (permission == LocationPermission.denied) {
        return Future.error('위치 권한 거부');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return Future.error('위치 권한 영구 거부');
    }
    return await Geolocator.getCurrentPosition();
  }

  Future<void> _fetchTodayWeather(double lat, double lng) async {
    try {
      const apiKey = 'ymOBx1J3Se-jgcdSdynvFg';
      final now = DateTime.now();
      DateTime targetTime = now.subtract(const Duration(minutes: 45));
      String baseDate = DateFormat('yyyyMMdd').format(targetTime);
      String baseTime = DateFormat('HH').format(targetTime) + '30';

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
            _rawTempForApi = double.tryParse(temp);
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

  Future<void> _fetchCombinedForecast(double lat, double lng, DateTime date) async {
    try {
      const apiKey = 'ymOBx1J3Se-jgcdSdynvFg';

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final selected = DateTime(date.year, date.month, date.day);

      final targetDate = DateFormat('yyyyMMdd').format(date); // 예보를 찾을 날짜 (fcstDate)
      String baseDate;
      const baseTime = '0200';

      if (selected.isAfter(today) || selected.isAtSameMomentAs(today)) {
        DateTime baseDateTime = now.hour < 2
            ? now.subtract(const Duration(days: 1))
            : now;
        baseDate = DateFormat('yyyyMMdd').format(baseDateTime);
      } else {
        baseDate = targetDate;
      }

      final gridCoords = _convertToGrid(lat, lng);
      final nx = gridCoords['x'];
      final ny = gridCoords['y'];
      final url = Uri.parse(
        'https://apihub.kma.go.kr/api/typ02/openApi/VilageFcstInfoService_2.0/getVilageFcst'
            '?authKey=$apiKey&pageNo=1&numOfRows=1000&dataType=JSON&base_date=$baseDate&base_time=$baseTime&nx=$nx&ny=$ny',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['response']['header']['resultCode'] == '00') {
          final items = data['response']['body']['items']['item'] as List;
          Map<String, String> weatherData1200 = {}; // 12시 예보
          String tmn = '', tmx = ''; // 최저/최고 기온

          for (var item in items) {
            if (item['fcstDate'] == targetDate) {
              if (item['fcstTime'] == '1200') {
                weatherData1200[item['category']] = item['fcstValue'];
              }
              if (item['category'] == 'TMN') tmn = item['fcstValue'];
              if (item['category'] == 'TMX') tmx = item['fcstValue'];
            }
          }

          String temp = weatherData1200['T3H'] ?? '';
          if (temp.isEmpty) {
            temp = weatherData1200['TMP'] ?? '';
          }
          String sky = weatherData1200['SKY'] ?? '';
          String pty = weatherData1200['PTY'] ?? '';

          final bool isToday = selected.isAtSameMomentAs(today);
          if (!isToday && temp.isNotEmpty && mounted) {
            final ptyString = _getPtyString(pty);
            final skyString = _getSkyString(sky);
            _rawTempForApi = double.tryParse(temp);
            setState(() {
              _currentTemp = "${double.parse(temp).toStringAsFixed(1)}°";
              _skyCondition = ptyString.isNotEmpty ? ptyString : skyString;
              _skyIcon = _getWeatherIcon(sky, pty);
            });
          } else if (!isToday) {
            _rawTempForApi = null;
            if (mounted) setState(() => _skyCondition = "예보 없음");
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
      if (mounted) setState(() => _skyCondition = "예보 오류");
      debugPrint("통합 예보 API 오류: $e");
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

  Future<void> _deleteSchedule(int scheduleId) async {
    const serverIp = '3.36.66.130';
    final url = Uri.parse('http://$serverIp:5000/schedule/$scheduleId');

    try {
      final response = await http.delete(url);

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('일정이 삭제되었습니다.'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pop();
          refreshData(); // [수정] 새로고침 시 캐시가 초기화됨
        } else {
          final responseData = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: ${responseData['message']}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 중 오류 발생: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showScheduleDetails(Map<String, dynamic> schedule) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return ScheduleDetailDialog(
          schedule: schedule,
          onDeleteConfirmed: () async {
            await _deleteSchedule(schedule['schedule_id']);
          },
          // 날씨 정보 전달
          currentTemp: _currentTemp,
          skyCondition: _skyCondition,
          skyIcon: _skyIcon,
          minTemp: _minTemp,
          maxTemp: _maxTemp,
          // 코디 정보 전달
          recommendedOutfit: _recommendedOutfit,
          isRecommendLoading: _isRecommendLoading,
          recommendStatus: _recommendStatus,
        );
      },
    );
  }


  void _navigateAndRefresh() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScheduleAddScreen()),
    );

    if (result == true) {
      refreshData(); // [수정] 새로고침 시 캐시가 초기화됨
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
        title: const Text('Calendar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.today, color: Colors.black),
            onPressed: () => _onDaySelected(DateTime.now(), DateTime.now()),
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = _selectedDay ?? now;
    final selectedDate = DateTime(selected.year, selected.month, selected.day);
    final bool isToday = selectedDate.isAtSameMomentAs(today);

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      // [수정] _isWeatherLoading 상태를 사용
      child: _isWeatherLoading
          ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
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
              Icon(_skyIcon, color: Colors.grey[800], size: 30),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isToday ? _currentTemp : _skyCondition,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (isToday)
                    Text(
                      _skyCondition,
                      style: TextStyle(color: Colors.grey[800], fontSize: 14),
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
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          // [수정] _isRecommendLoading 상태 사용
          child: _isRecommendLoading
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(strokeWidth: 2),
                const SizedBox(height: 8),
                Text(
                  _recommendStatus,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
              : _recommendedOutfit != null
              ? RecommendedOutfitCard(outfitData: _recommendedOutfit!)
              : Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _recommendStatus,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
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
          if (isSingleDay) {
            dateTimeString = isAllDay ? '$formattedDate, 하루종일' : '$startTime - $endTime';
          } else {
            if (isFirstDay) {
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

  String _getTpoForSelectedDay() {
    if (_selectedDaySchedules.isEmpty) {
      return 'Casual & Daily';
    }

    final firstSchedule = _selectedDaySchedules.first;
    const tpoMapping = {
      '일상 & 캐주얼': 'Casual & Daily',
      '비즈니스 & 포멀': 'Business & Formal',
      '특별한 날 & 데이트': 'Special Occasion & Date',
      '활동적인 날': 'Active Day',
    };

    final String? tpo1 = firstSchedule['tpo1'];
    final String? tpo2 = firstSchedule['tpo2'];
    final String rawTpo = (tpo1 != null && tpo1.isNotEmpty)
        ? tpo1
        : (tpo2 != null && tpo2.isNotEmpty)
        ? tpo2
        : '일상 & 캐주얼';

    return tpoMapping[rawTpo] ?? 'Casual & Daily';
  }

  Future<void> _getRecommendation() async {
    // [수정] _isRecommendLoading=true는 _onDaySelected에서 이미 처리됨
    // (단, _loadSecondaryData에서 호출 시에는 여기서 처리)
    if (!_isRecommendLoading && mounted) {
      setState(() {
        _isRecommendLoading = true;
        _recommendedOutfit = null;
        _recommendStatus = "코디 추천 로딩 중...";
      });
    }

    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail');
    if (userEmail == null) {
      if (mounted) {
        setState(() {
          _isRecommendLoading = false;
          _recommendStatus = "로그인 필요";
        });
      }
      return;
    }

    final tpoCategory = _getTpoForSelectedDay();
    final dateString = DateFormat('yyyy-MM-dd').format(_selectedDay!);
    final temperature = _rawTempForApi;

    try {
      const String serverIp = '3.36.66.130';
      final uri = Uri.parse('http://$serverIp:5000/recommend_today');

      final requestBody = jsonEncode({
        'email': userEmail,
        'date': dateString,
        'temperature': temperature,
      });

      debugPrint("Sending recommendation request: $requestBody");

      final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: requestBody
      );

      if (mounted) {
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final outfitsList = List<Map<String, dynamic>>.from(
            data['recommended_outfits_list'] ?? [],
          );
          final String effectiveTpo = data['tpo'] ?? tpoCategory;

          if (outfitsList.isNotEmpty) {
            setState(() {
              _recommendedOutfit = outfitsList.first;
              _recommendStatus = "'$effectiveTpo' 추천 코디";
            });
          } else {
            setState(() {
              _recommendStatus = "'$effectiveTpo'에 맞는 코디가 없습니다.";
            });
          }
        } else {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          debugPrint("Recommendation error: ${data['message']}");
          setState(() => _recommendStatus = data['message'] ?? '추천 실패');
        }
      }
    } catch (e) {
      debugPrint("Recommendation request error: $e");
      if (mounted) setState(() => _recommendStatus = '네트워크 오류');
    } finally {
      if (mounted) setState(() => _isRecommendLoading = false);
    }
  }

} // CalendarScreen 끝


// --- (이하 ScheduleDetailDialog, RecommendedOutfitCard 코드는 수정 없음) ---
// (이전 답변과 동일)

class ScheduleDetailDialog extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final VoidCallback onDeleteConfirmed;

  final String currentTemp;
  final String skyCondition;
  final IconData skyIcon;
  final String? minTemp;
  final String? maxTemp;

  final Map<String, dynamic>? recommendedOutfit;
  final bool isRecommendLoading;
  final String recommendStatus;

  const ScheduleDetailDialog({
    super.key,
    required this.schedule,
    required this.onDeleteConfirmed,
    required this.currentTemp,
    required this.skyCondition,
    required this.skyIcon,
    this.minTemp,
    this.maxTemp,
    this.recommendedOutfit,
    required this.isRecommendLoading,
    required this.recommendStatus,
  });

  Widget _buildWeatherCard(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime selectedDate;
    try {
      selectedDate = DateTime.parse(schedule['startDate'] as String? ?? '');
    } catch (e) {
      selectedDate = today;
    }

    final normalizedSelectedDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final bool isToday = normalizedSelectedDate.isAtSameMomentAs(today);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('날씨',
              style: TextStyle(
                  color: Colors.grey[600], fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(skyIcon, size: 24, color: Colors.grey[800]),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isToday ? currentTemp : skyCondition,
                      style:
                      const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isToday)
                      Text(
                        skyCondition,
                        style: TextStyle(color: Colors.grey[800], fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (minTemp != null && maxTemp != null)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(minTemp!,
                      style: const TextStyle(fontSize: 10, color: Colors.blue)),
                  Text(' / ',
                      style: TextStyle(fontSize: 10, color: Colors.grey[700])),
                  Text(maxTemp!,
                      style: const TextStyle(fontSize: 10, color: Colors.red)),
                ],
              ),
            ),
        ],
      ),
    );
  }

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

  String _formatScheduleDateTime(Map<String, dynamic> schedule) {
    final String? startDateStr = schedule['startDate'] as String?;
    final String? endDateStr = schedule['endDate'] as String?;
    final String? startTimeStr = schedule['startTime'] as String?;
    final String? endTimeStr = schedule['endTime'] as String?;

    if (startDateStr == null ||
        endDateStr == null ||
        startTimeStr == null ||
        endTimeStr == null) {
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
        if (isAllDay) {
          return '${dateFormat.format(startDate)} 하루 종일';
        } else {
          return '${dateFormat.format(startDate)} $startTimeStr - $endTimeStr';
        }
      } else {
        if (isAllDay) {
          return '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}';
        } else {
          final fullStartDate =
          DateTime.parse('${startDateStr.substring(0, 10)}T$startTimeStr');
          final fullEndDate =
          DateTime.parse('${endDateStr.substring(0, 10)}T$endTimeStr');
          return '${dateTimeFormat.format(fullStartDate)} - ${dateTimeFormat.format(fullEndDate)}';
        }
      }
    } catch (e) {
      return "날짜/시간 형식 오류";
    }
  }

  Future<void> _showDeleteConfirmationDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('일정 삭제'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('이 일정을 삭제할까요?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('확인', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onDeleteConfirmed();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String title = (schedule['title'] as String?) ?? '제목 없음';
    final String dateRange = _formatScheduleDateTime(schedule);
    final String? locationName =
    (schedule['location'] as String?)?.isNotEmpty == true
        ? schedule['location'] as String
        : null;
    final String? locationAddress =
    (schedule['locationAddress'] as String?)?.isNotEmpty == true
        ? schedule['locationAddress'] as String
        : null;
    final String? tpo1 = (schedule['tpo1'] as String?)?.isNotEmpty == true
        ? schedule['tpo1'] as String
        : null;
    final String? tpo2 = (schedule['tpo2'] as String?)?.isNotEmpty == true
        ? schedule['tpo2'] as String
        : null;
    final String explanation =
        (schedule['explanation'] as String?) ?? '설명 없음';
    final List<String> participants =
        (schedule['participants'] as String?)
            ?.split(',')
            .where((s) => s.isNotEmpty)
            .toList() ??
            [];
    final String alarmText = _getAlarmText(
        schedule['alarmUnit'] as String?,
        schedule['alarmValue'] as int?);

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
                  IconButton(
                      onPressed: () => _showDeleteConfirmationDialog(context),
                      icon: const Icon(Icons.delete_outline)),
                  Column(
                    children: [
                      const Text('내 일정',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('기본일정',
                          style:
                          TextStyle(color: Colors.grey[600], fontSize: 12)),
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
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(dateRange,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
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
                      child: _buildInfoCard(
                          '알림설정', [alarmText], Icons.notifications_outlined),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 110,
                      child: _buildInfoCard(
                          '참가자', participants, Icons.people_outline),
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
                        decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12)),
                        clipBehavior: Clip.antiAlias,
                        child: isRecommendLoading
                            ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(strokeWidth: 2),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  recommendStatus,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        )
                            : recommendedOutfit != null
                            ? RecommendedOutfitCard(
                            outfitData: recommendedOutfit!)
                            : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              recommendStatus,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      )),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 110,
                          child: _buildWeatherCard(context),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 110,
                          child:
                          _buildInfoCard('설명', [explanation], Icons.notes),
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
    final validItems =
    items.where((item) => item.isNotEmpty && item != '설명 없음').toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: Colors.grey[600], fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (validItems.isEmpty)
            Row(
              children: [
                Icon(icon, size: 16, color: Colors.grey[700]),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text("정보 없음", overflow: TextOverflow.ellipsis)),
              ],
            )
          else
            ...validItems
                .map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(item,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12))),
                ],
              ),
            ))
                .toList(),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
      {required IconData icon, required String title, String? subtitle}) {
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
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              if (subtitle != null && subtitle.isNotEmpty)
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700])),
            ],
          ),
        ],
      ),
    );
  }
}

class RecommendedOutfitCard extends StatelessWidget {
  final Map<String, dynamic> outfitData;
  const RecommendedOutfitCard({super.key, required this.outfitData});

  static const String serverBaseUrl = 'http://3.36.66.130:5000';

  @override
  Widget build(BuildContext context) {
    final topData = outfitData['top'] as Map<String, dynamic>?;
    final bottomData = outfitData['bottom'] as Map<String, dynamic>?;
    final shoesData = outfitData['shoes'] as Map<String, dynamic>?;

    return Container(
      child: Card(
        elevation: 0,
        color: Colors.grey[200],
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 2,
              child: _buildImage(topData),
            ),
            Expanded(
              flex: 2,
              child: _buildImage(bottomData),
            ),
            Expanded(
              flex: 1,
              child: _buildImage(shoesData),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(Map<String, dynamic>? itemData) {
    final imagePath = itemData?['clothingImg'] as String?;
    final bgColor = Colors.grey[200];

    if (itemData == null || imagePath == null || imagePath.isEmpty) {
      return Container(width: double.infinity, color: bgColor);
    }

    final imageUrl = imagePath.startsWith('http')
        ? imagePath
        : '$serverBaseUrl/$imagePath';
    return Container(
      width: double.infinity,
      color: bgColor,
      child: Image.network(
        imageUrl,
        fit: BoxFit.contain,
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