import 'package:flutter/material.dart';
import 'dart:io'; // File 클래스를 사용하기 위해 import

// 촬영한 사진과 정보를 입력하는 화면
class AddClothingScreen extends StatefulWidget {
  final String imagePath; // HomeScreen에서 전달받은 이미지 경로

  const AddClothingScreen({super.key, required this.imagePath});

  @override
  State<AddClothingScreen> createState() => _AddClothingScreenState();
}

class _AddClothingScreenState extends State<AddClothingScreen> {
  // 텍스트 필드 제어를 위한 컨트롤러
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  @override
  void dispose() {
    // 화면이 종료될 때 컨트롤러 리소스를 해제
    _nameController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('새 옷 정보 입력'),
        leading: IconButton(
          icon: const Icon(Icons.close), // 닫기 버튼
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 촬영한 사진 보여주기
            Container(
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  // 전달받은 경로(widget.imagePath)로 File 객체를 만들어 이미지 로드
                  image: FileImage(File(widget.imagePath)),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 2. 옷 이름 입력 필드
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '옷 이름',
                border: OutlineInputBorder(),
                hintText: '예: 파란색 맨투맨',
              ),
            ),
            const SizedBox(height: 16),

            // 3. 추가 정보(메모) 입력 필드
            TextField(
              controller: _memoController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
                border: OutlineInputBorder(),
                hintText: '예: 생일 선물로 받은 옷',
              ),
            ),
            const SizedBox(height: 32),

            // 4. 저장 버튼
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                // 저장 버튼 로직
                final String name = _nameController.text;
                final String memo = _memoController.text;

                // 간단히 콘솔에 출력 (실제 앱에서는 DB나 서버에 저장)
                debugPrint('옷 이름: $name');
                debugPrint('메모: $memo');
                debugPrint('이미지 경로: ${widget.imagePath}');

                // 저장 후 홈 화면으로 돌아가기
                Navigator.pop(context);

                // 저장 완료 스낵바 표시
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('옷이 저장되었습니다!')),
                );
              },
              child: const Text('저장하기'),
            ),
          ],
        ),
      ),
    );
  }
}