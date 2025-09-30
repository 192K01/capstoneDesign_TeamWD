// 📂 lib/schedule_add_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class ScheduleAddScreen extends StatefulWidget {
  const ScheduleAddScreen({super.key});

  @override
  State<ScheduleAddScreen> createState() => _ScheduleAddScreenState();
}

class _ScheduleAddScreenState extends State<ScheduleAddScreen> {
  bool _isAllDay = false;

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
              const Text('3월 4일 화요일', style: TextStyle(fontSize: 16)),
              if (!_isAllDay)
                const Text('09:41', style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('3월 4일 화요일', style: TextStyle(fontSize: 16)),
              if (!_isAllDay)
                const Text('10:41', style: TextStyle(fontSize: 16)),
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

  // ▼▼▼ 이 함수 부분을 수정했습니다 ▼▼▼
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
                  // title이 '기본일정'일 경우에만 파란색 원 아이콘을 표시합니다.
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
                  // '기본일정'일 때만 subtitle의 왼쪽 여백을 줘서 줄을 맞춥니다.
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