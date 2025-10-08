// 📂 lib/schedule_add.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http; // HTTP 통신을 위해 추가
import 'dart:convert'; // JSON 인코딩/디코딩을 위해 추가
import 'package:shared_preferences/shared_preferences.dart'; // 사용자 정보 조회를 위해 추가
import 'location_search_screen.dart';

class ScheduleAddScreen extends StatefulWidget {
  const ScheduleAddScreen({super.key});

  @override
  State<ScheduleAddScreen> createState() => _ScheduleAddScreenState();
}

class _ScheduleAddScreenState extends State<ScheduleAddScreen> {
  // ▼▼▼ [추가] 제목, 설명 컨트롤러 및 로딩 상태 변수 ▼▼▼
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _explanationController = TextEditingController();
  bool _isLoading = false;
  // ▲▲▲ [추가] 제목, 설명 컨트롤러 및 로딩 상태 변수 ▲▲▲

  bool _isAllDay = false;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay(hour: (TimeOfDay.now().hour + 1) % 24, minute: TimeOfDay.now().minute);

  String _locationName = '위치';
  String _locationAddress = '도로명주소';

  // --- ▼▼▼ [추가] 일정 저장 로직 ▼▼▼ ---
  Future<void> _saveSchedule() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일정 제목을 입력해주세요.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('userEmail');

      if (userEmail == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사용자 정보를 찾을 수 없습니다.'), backgroundColor: Colors.red),
        );
        return;
      }

      const serverIp = '3.36.66.130'; // 실제 서버 IP
      final url = Uri.parse('http://$serverIp:5000/schedule');

      final scheduleData = {
        'email': userEmail,
        'title': _titleController.text,
        'startDate': DateFormat('yyyy-MM-dd').format(_startDate),
        'endDate': DateFormat('yyyy-MM-dd').format(_endDate),
        'locationName': _locationName,
        'locationAddress': _locationAddress,
        'explanation': _explanationController.text,
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(scheduleData),
      );

      if (mounted) {
        final responseData = jsonDecode(response.body);
        if (response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseData['message']), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true); // 성공 시 true 반환하며 이전 화면으로
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseData['message']), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('일정 저장 중 오류가 발생했습니다: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  // --- ▲▲▲ [추가] 일정 저장 로직 ▲▲▲ ---

  @override
  void dispose() {
    _titleController.dispose();
    _explanationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != (isStartDate ? _startDate : _endDate)) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _showTimePicker(BuildContext context, bool isStartTime) {
    final initialDateTime = DateTime(DateTime.now().year, DateTime.now().month,
        DateTime.now().day, isStartTime ? _startTime.hour : _endTime.hour, isStartTime ? _startTime.minute : _endTime.minute);

    showModalBottomSheet(
      context: context,
      builder: (BuildContext builder) {
        return SizedBox(
          height: 250,
          child: Column(
            children: [
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: initialDateTime,
                  onDateTimeChanged: (DateTime newDateTime) {
                    setState(() {
                      if (isStartTime) {
                        _startTime = TimeOfDay.fromDateTime(newDateTime);
                      } else {
                        _endTime = TimeOfDay.fromDateTime(newDateTime);
                      }
                    });
                  },
                ),
              ),
              CupertinoButton(
                child: const Text('확인'),
                onPressed: () {
                  Navigator.pop(context);
                },
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _navigateToLocationSearch() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationSearchScreen()),
    );

    if (result != null && result is Map) {
      setState(() {
        _locationName = result['name'] ?? '위치';
        _locationAddress = result['address'] ?? '도로명주소';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('일정 추가', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          // ▼▼▼ [수정] 저장 버튼 로직 변경 ▼▼▼
          _isLoading
              ? const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Center(child: CupertinoActivityIndicator()),
          )
              : IconButton(
            icon: const Icon(Icons.check, color: Colors.black, size: 28),
            onPressed: _saveSchedule, // 저장 함수 호출
          ),
          // ▲▲▲ [수정] 저장 버튼 로직 변경 ▲▲▲
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildTitleInput(),
          const SizedBox(height: 16),
          _buildDateTimeSection(),
          const SizedBox(height: 16),
          _buildOptionTile(icon: Icons.repeat, title: '반복 설정', value: '반복안함'),
          const SizedBox(height: 16),
          _buildOptionTile(icon: Icons.calendar_today_outlined, title: '기본일정', subtitle: '내 캘린더'),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _navigateToLocationSearch,
            child: _buildOptionTile(icon: Icons.location_on_outlined, title: _locationName, subtitle: _locationAddress),
          ),
          const SizedBox(height: 16),
          _buildOptionTile(icon: Icons.people_outline, title: '참가자', value: '참가자 없음'),
          const SizedBox(height: 16),
          _buildOptionTile(icon: Icons.notifications_none, title: '알림설정', value: '알림 없음'),
          const SizedBox(height: 16),
          _buildDescriptionInput(),
        ],
      ),
    );
  }

  Widget _buildTitleInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _titleController, // 컨트롤러 연결
        decoration: const InputDecoration(
          icon: Icon(Icons.square_rounded, color: Colors.blue, size: 16),
          hintText: '일정을 입력하세요.',
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildDateTimeSection() {
    final DateFormat formatter = DateFormat('M월 d일 EEEE', 'ko_KR');

    String formatTimeOfDay(TimeOfDay tod) {
      final hour = tod.hour.toString().padLeft(2, '0');
      final minute = tod.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('하루종일', style: TextStyle(fontSize: 16)),
              CupertinoSwitch(
                value: _isAllDay,
                onChanged: (bool value) {
                  setState(() {
                    _isAllDay = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _selectDate(context, true),
                child: Container(
                  color: Colors.transparent,
                  child: Text(formatter.format(_startDate), style: const TextStyle(fontSize: 16)),
                ),
              ),
              if (!_isAllDay)
                GestureDetector(
                  onTap: () => _showTimePicker(context, true),
                  child: Container(
                    color: Colors.transparent,
                    child: Text(formatTimeOfDay(_startTime), style: const TextStyle(fontSize: 16)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _selectDate(context, false),
                child: Container(
                  color: Colors.transparent,
                  child: Text(formatter.format(_endDate), style: const TextStyle(fontSize: 16)),
                ),
              ),
              if (!_isAllDay)
                GestureDetector(
                  onTap: () => _showTimePicker(context, false),
                  child: Container(
                    color: Colors.transparent,
                    child: Text(formatTimeOfDay(_endTime), style: const TextStyle(fontSize: 16)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.public, size: 24),
              SizedBox(width: 12),
              Text('대한민국 표준시', style: TextStyle(fontSize: 16)),
              Spacer(),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildOptionTile({required IconData icon, required String title, String? subtitle, String? value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (title == '기본일정')
                      const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: Icon(Icons.circle, color: Colors.blue, size: 12),
                      ),
                    Text(title, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
                  ],
                ),
                if (subtitle != null)
                  Padding(
                    padding: EdgeInsets.only(left: title == '기본일정' ? 20 : 0),
                    child: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 14), overflow: TextOverflow.ellipsis),
                  )
              ],
            ),
          ),
          const Spacer(),
          if (value != null)
            Text(value, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildDescriptionInput() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notes, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _explanationController, // 컨트롤러 연결
              maxLines: 3,
              decoration: const InputDecoration.collapsed(
                hintText: '설명을 입력하세요.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}