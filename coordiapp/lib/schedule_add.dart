// 📂 lib/schedule_add.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_search_screen.dart';

// 알림 옵션을 관리하기 위한 간단한 클래스
class AlarmOption {
  final String displayText; // 화면에 보여줄 텍스트 (예: '10분 전')
  final String unit; // 서버에 보낼 단위 (예: 'minutes')
  final int value; // 서버에 보낼 값 (예: 10)

  AlarmOption({
    required this.displayText,
    required this.unit,
    required this.value,
  });
}

class ScheduleAddScreen extends StatefulWidget {
  const ScheduleAddScreen({super.key});

  @override
  State<ScheduleAddScreen> createState() => _ScheduleAddScreenState();
}

class _ScheduleAddScreenState extends State<ScheduleAddScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _explanationController = TextEditingController();
  bool _isLoading = false;

  List<String> _participants = [];

  bool _isAllDay = false;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay(
    hour: (TimeOfDay.now().hour + 1) % 24,
    minute: TimeOfDay.now().minute,
  );

  String _locationName = '위치';
  String _locationAddress = '도로명주소';

  final List<AlarmOption> _alarmOptions = [
    AlarmOption(displayText: '알림 없음', unit: 'none', value: 0),
    AlarmOption(displayText: '정시', unit: 'minutes', value: 0),
    AlarmOption(displayText: '5분 전', unit: 'minutes', value: 5),
    AlarmOption(displayText: '10분 전', unit: 'minutes', value: 10),
    AlarmOption(displayText: '30분 전', unit: 'minutes', value: 30),
    AlarmOption(displayText: '1시간 전', unit: 'hours', value: 1),
    AlarmOption(displayText: '하루 전', unit: 'days', value: 1),
  ];
  late AlarmOption _selectedAlarmOption;

  // --- ▼▼▼ [수정] 'TPO 설정 없음' 옵션 추가 ▼▼▼ ---
  final Map<String, List<String>> _tpoData = {
    'TPO': [],
    '일상 & 캐주얼': ['친구와의 약속', '학교/캠퍼스 생활'],
    '비즈니스 & 포멀': ['출근/오피스', '비즈니스 미팅', '면접', '결혼식 하객'],
    '특별한 날 & 데이트': ['데이트', '파티/행사', '레스토랑', '전시회/공연 관람'],
    '활동적인 날': ['운동/액티비티', '나들이'],
  };
  String? _selectedTpo1;
  String? _selectedTpo2;
  // --- ▲▲▲ [수정] 'TPO 설정 없음' 옵션 추가 ▲▲▲ ---

  @override
  void initState() {
    super.initState();
    _selectedAlarmOption = _alarmOptions[0];
    _selectedTpo1 = _tpoData.keys.first; // 기본값을 'TPO 설정 없음'으로 설정
  }

  Future<void> _saveSchedule() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('일정 제목을 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('userEmail');

      if (userEmail == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('사용자 정보를 찾을 수 없습니다.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      const serverIp = '3.36.66.130';
      final url = Uri.parse('http://$serverIp:5000/schedule');

      final String startTimeString = _isAllDay
          ? '00:00'
          : '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
      final String endTimeString = _isAllDay
          ? '23:59'
          : '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}';

      final scheduleData = {
        'email': userEmail,
        'title': _titleController.text,
        'startDate': DateFormat('yyyy-MM-dd').format(_startDate),
        'endDate': DateFormat('yyyy-MM-dd').format(_endDate),
        'startTime': startTimeString,
        'endTime': endTimeString,
        'locationName': _locationName == '위치' ? null : _locationName,
        'locationAddress': _locationAddress == '도로명주소'
            ? null
            : _locationAddress,
        'explanation': _explanationController.text,
        'participants': _participants.join(','),
        'alarmUnit': _selectedAlarmOption.unit,
        'alarmValue': _selectedAlarmOption.value,
        // --- ▼▼▼ [수정] TPO 설정 없음을 null로 처리하여 전송 ▼▼▼ ---
        'tpo1': _selectedTpo1 == 'TPO' ? null : _selectedTpo1,
        'tpo2': _selectedTpo1 == 'TPO' ? null : _selectedTpo2,
        // --- ▲▲▲ [수정] TPO 설정 없음을 null로 처리하여 전송 ▲▲▲ ---
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
            SnackBar(
              content: Text(responseData['message']),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message']),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('일정 저장 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showAddParticipantDialog() async {
    final TextEditingController emailController = TextEditingController();
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('참가자 추가'),
          content: TextField(
            controller: emailController,
            decoration: const InputDecoration(hintText: "이메일 주소 입력"),
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('추가'),
              onPressed: () {
                final String email = emailController.text.trim();
                if (email.isNotEmpty && !_participants.contains(email)) {
                  setState(() {
                    _participants.add(email);
                  });
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

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
          if (_startDate.isAfter(_endDate)) _endDate = _startDate;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _showTimePicker(BuildContext context, bool isStartTime) {
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
                onPressed: () => Navigator.pop(context),
              ),
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

  void _showAlarmOptions() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 250,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: CupertinoPicker(
                  magnification: 1.22,
                  squeeze: 1.2,
                  useMagnifier: true,
                  itemExtent: 32.0,
                  scrollController: FixedExtentScrollController(
                    initialItem: _alarmOptions.indexOf(_selectedAlarmOption),
                  ),
                  onSelectedItemChanged: (int selectedItem) {
                    setState(() {
                      _selectedAlarmOption = _alarmOptions[selectedItem];
                    });
                  },
                  children: List<Widget>.generate(_alarmOptions.length, (
                    int index,
                  ) {
                    return Center(
                      child: Text(_alarmOptions[index].displayText),
                    );
                  }),
                ),
              ),
              CupertinoButton(
                child: const Text('확인'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTpoPicker() {
    int tpo1Index = _tpoData.keys.toList().indexOf(
      _selectedTpo1 ?? _tpoData.keys.first,
    );

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        List<String> currentTpo2Options =
            _tpoData[_tpoData.keys.elementAt(tpo1Index)]!;

        return StatefulBuilder(
          builder: (context, setPickerState) {
            return Container(
              height: 250,
              color: CupertinoColors.systemBackground.resolveFrom(context),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoPicker(
                              magnification: 1.22,
                              squeeze: 1.2,
                              useMagnifier: true,
                              itemExtent: 32.0,
                              scrollController: FixedExtentScrollController(
                                initialItem: tpo1Index,
                              ),
                              onSelectedItemChanged: (int selectedItem) {
                                setPickerState(() {
                                  tpo1Index = selectedItem;
                                  _selectedTpo1 = _tpoData.keys.elementAt(
                                    tpo1Index,
                                  );
                                  currentTpo2Options = _tpoData[_selectedTpo1]!;
                                  _selectedTpo2 = null;
                                });
                              },
                              children: _tpoData.keys
                                  .map((key) => Center(child: Text(key)))
                                  .toList(),
                            ),
                          ),
                          Expanded(
                            child: CupertinoPicker(
                              key: ValueKey(_selectedTpo1),
                              magnification: 1.22,
                              squeeze: 1.2,
                              useMagnifier: true,
                              itemExtent: 32.0,
                              onSelectedItemChanged: (int selectedItem) {
                                setPickerState(() {
                                  if (currentTpo2Options.isNotEmpty) {
                                    _selectedTpo2 =
                                        currentTpo2Options[selectedItem];
                                  }
                                });
                              },
                              children: currentTpo2Options
                                  .map((value) => Center(child: Text(value)))
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      child: const Text('확인'),
                      onPressed: () {
                        setState(() {
                          _selectedTpo1 = _tpoData.keys.elementAt(tpo1Index);
                          if (_selectedTpo1 != 'TPO' && _selectedTpo2 == null) {
                            _selectedTpo2 = _tpoData[_selectedTpo1]!.first;
                          } else if (_selectedTpo1 == 'TPO') {
                            _selectedTpo2 = null;
                          }
                        });
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
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
        title: const Text(
          '일정 추가',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: Center(child: CupertinoActivityIndicator()),
                )
              : IconButton(
                  icon: const Icon(Icons.check, color: Colors.black, size: 28),
                  onPressed: _saveSchedule,
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
          _buildOptionTile(
            icon: Icons.calendar_today_outlined,
            title: '기본일정',
            subtitle: '내 캘린더',
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _navigateToLocationSearch,
            child: _buildOptionTile(
              icon: Icons.location_on_outlined,
              title: _locationName,
              subtitle: _locationAddress,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _navigateToLocationSearch,
            child: _buildOptionTile(
              icon: Icons.location_on_outlined,
              title: _locationName,
              subtitle: _locationAddress,
            ),
          ),
          const SizedBox(height: 16),
          // --- ▼▼▼ [수정] TPO UI 표시 로직 변경 ▼▼▼ ---
          GestureDetector(
            onTap: _showTpoPicker,
            child: _buildOptionTile(
              icon: Icons.sell_outlined,
              title: _selectedTpo1 ?? 'TPO',
              subtitle: _selectedTpo1 == 'TPO' ? null : _selectedTpo2,
            ),
          ),
          // --- ▲▲▲ [수정] TPO UI 표시 로직 변경 ▲▲▲ ---
          const SizedBox(height: 16),
          _buildParticipantsSection(),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _showAlarmOptions,
            child: _buildOptionTile(
              icon: Icons.notifications_none,
              title: '알림설정',
              value: _selectedAlarmOption.displayText,
            ),
          ),
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
        controller: _titleController,
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
                onChanged: (bool value) => setState(() => _isAllDay = value),
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
                  child: Text(
                    formatter.format(_startDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              if (!_isAllDay)
                GestureDetector(
                  onTap: () => _showTimePicker(context, true),
                  child: Container(
                    color: Colors.transparent,
                    child: Text(
                      formatTimeOfDay(_startTime),
                      style: const TextStyle(fontSize: 16),
                    ),
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
                  child: Text(
                    formatter.format(_endDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              if (!_isAllDay)
                GestureDetector(
                  onTap: () => _showTimePicker(context, false),
                  child: Container(
                    color: Colors.transparent,
                    child: Text(
                      formatTimeOfDay(_endTime),
                      style: const TextStyle(fontSize: 16),
                    ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    String? value,
  }) {
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
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                if (subtitle != null && subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 0),
                    child: Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          if (value != null)
            Text(
              value,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.people_outline, size: 24),
                  SizedBox(width: 12),
                  Text('참가자', style: TextStyle(fontSize: 16)),
                ],
              ),
              IconButton(
                icon: Icon(Icons.add, color: Colors.grey[600]),
                onPressed: _showAddParticipantDialog,
              ),
            ],
          ),
          _participants.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 4.0, left: 36.0),
                  child: Text(
                    '참가자 없음',
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: _participants
                        .map(
                          (email) => Chip(
                            label: Text(email),
                            labelStyle: const TextStyle(color: Colors.black),
                            backgroundColor: Colors.white,
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () {
                              setState(() {
                                _participants.remove(email);
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
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
              controller: _explanationController,
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
