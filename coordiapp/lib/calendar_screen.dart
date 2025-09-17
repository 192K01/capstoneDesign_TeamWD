import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  String _weatherInfo = "로딩 중...";
  String _dateString = "";

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchWeather();
    _setDateString();
  }

  void _setDateString() {
    _dateString = DateFormat('M. d. E', 'ko_KR').format(DateTime.now());
  }

  // lib/calendar_screen.dart 파일의 _CalendarScreenState 클래스 내부

  Future<void> _fetchWeather() async {
    try {
      const apiKey = 'aea983582fed66f091aad69100146ccd';
      const lat = 37.1498;
      const lon = 127.0772;

      // ▼▼▼ 주소가 'https://' 로 시작하는지 확인하세요 ▼▼▼
      final url = Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=kr');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final description = data['weather'][0]['description'];
        final temp = data['main']['temp'];
        final tempMax = data['main']['temp_max'];
        if (mounted) {
          setState(() {
            _weatherInfo =
            "$description, ${temp.toStringAsFixed(0)}°C/${tempMax.toStringAsFixed(0)}°C";
          });
        }
      } else {
        // API 키가 틀리거나 비활성화 상태일 때 이 부분이 실행될 수 있습니다.
        print('!!! API 응답 에러: ${response.statusCode}');
        if (mounted) {
          setState(() {
            _weatherInfo = "날씨 정보 없음";
          });
        }
      }
    } catch (e) {
      // 인터넷 권한이 없거나, http로 요청했을 때 이 부분이 실행됩니다.
      print('!!! 날씨 API 에러 발생: $e');
      if (mounted) {
        setState(() {
          _weatherInfo = "오류 발생";
        });
      }
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
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(Icons.menu, color: Colors.black),
            const Text('Calender', style: TextStyle(color: Color.fromARGB(255, 96, 21, 112), fontWeight: FontWeight.bold, fontSize: 22)),
            const Icon(Icons.notifications_outlined, color: Colors.black),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _buildCalendar(),
          const SizedBox(height: 24),
          _buildScheduleHeader(),
          const SizedBox(height: 16),
          _buildScheduleAndLooksCard(),
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
      ),
      calendarStyle: const CalendarStyle(
        todayDecoration: BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
        selectedDecoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
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
        const Text("Today's schedule", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Icon(Icons.add, color: Colors.black),
      ],
    );
  }

  Widget _buildScheduleAndLooksCard() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
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
          Expanded(
            flex: 3,
            child: _buildScheduleList(),
          ),
        ],
      ),
    );
  }

  // ▼▼▼ 이 위젯이 수정되었습니다 ▼▼▼
  Widget _buildDateWeatherCard() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(_dateString, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. Text 위젯을 Expanded로 감싸서 공간을 유연하게 사용하도록 합니다.
              Expanded(
                child: Text(
                  _weatherInfo,
                  textAlign: TextAlign.center, // 텍스트를 가운데 정렬
                  overflow: TextOverflow.ellipsis, // 공간이 부족하면 ...으로 표시
                  maxLines: 1, // 한 줄로 제한
                  style: TextStyle(color: Colors.grey[800]),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.wb_sunny, color: Colors.orange, size: 20),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLooksCard() {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Looks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Icon(Icons.add, size: 20),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[300],
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
    return Column(
      children: [
        _buildScheduleItem(Colors.blue, '윤쓰코티 팝업', '3. 3.(월) 10:30 - ...'),
        const SizedBox(height: 12),
        _buildScheduleItem(Colors.green, '수강신청 정정기간', '3. 4.(화) - ...'),
        const SizedBox(height: 12),
        _buildScheduleItem(Colors.purple, '캡스톤 회의', '13:00 - 16:45'),
        const SizedBox(height: 12),
        _buildScheduleItem(Colors.orange, '미용실 예약', '18:00 - 19:00'),
      ],
    );
  }

  Widget _buildScheduleItem(Color color, String title, String time) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 4, height: 40, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}