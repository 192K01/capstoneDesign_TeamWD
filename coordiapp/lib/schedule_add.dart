// 📂 lib/schedule_add_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

class ScheduleAddScreen extends StatefulWidget {
  const ScheduleAddScreen({super.key});

  @override
  State<ScheduleAddScreen> createState() => _ScheduleAddScreenState();
}

class _ScheduleAddScreenState extends State<ScheduleAddScreen> {
  bool _isAllDay = false;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1);

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

  // ▼▼▼ 이 함수 부분을 수정했습니다 ▼▼▼
  // 스크롤 방식의 시간 선택기를 띄우는 함수
  void _showTimePicker(BuildContext context, bool isStartTime) {
    // 현재 선택된 시간을 DateTime 객체로 변환 (CupertinoDatePicker에 필요)
    final initialDateTime = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      isStartTime ? _startTime.hour : _endTime.hour,
      isStartTime ? _startTime.minute : _endTime.minute,
    );

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
                  use24hFormat: true, // 24시간 형식 사용
                  initialDateTime: initialDateTime,
                  onDateTimeChanged: (DateTime newDateTime) {
                    // 스크롤할 때마다 상태를 바로 업데이트
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
                  Navigator.pop(context); // 팝업 닫기
                },
              )
            ],
          ),
        );
      },
    );
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
          IconButton(
            icon: const Icon(Icons.check, color: Colors.black, size: 28),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
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
          _buildOptionTile(icon: Icons.location_on_outlined, title: '위치', subtitle: '도로명주소'),
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
      child: const TextField(
        decoration: InputDecoration(
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (title == '기본일정')
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(Icons.circle, color: Colors.blue, size: 12),
                    ),
                  Text(title, style: const TextStyle(fontSize: 16)),
                ],
              ),
              if (subtitle != null)
                Padding(
                  padding: EdgeInsets.only(left: title == '기본일정' ? 20 : 0),
                  child: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                )
            ],
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
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notes, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: TextField(
              maxLines: 3,
              decoration: InputDecoration.collapsed(
                hintText: '설명을 입력하세요.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}