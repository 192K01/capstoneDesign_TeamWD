import 'package:flutter/material.dart';
import 'dart:io'; // File 클래스를 사용하기 위해 import
import 'package:path_provider/path_provider.dart'; // ▼▼▼ [수정] import 추가 ▼▼▼

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

  // ▼▼▼▼▼▼ [추가] 이미지 저장 함수 ▼▼▼▼▼▼
  Future<String> _saveImage(String tempPath) async {
    // 1. 앱의 문서(Document) 디렉토리 경로를 가져옵니다.
    final directory = await getApplicationDocumentsDirectory();
    final imageDirectory = Directory('${directory.path}/image');

    // 2. '/image' 폴더가 없으면 새로 생성합니다.
    if (!await imageDirectory.exists()) {
      await imageDirectory.create(recursive: true);
    }

    // 3. 파일 이름과 경로를 설정합니다. (고유한 파일 이름을 위해 현재 시간 사용)
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final newPath = '${imageDirectory.path}/$fileName';

    // 4. 임시 경로에 있는 파일을 새 경로로 복사합니다.
    final File newImage = await File(tempPath).copy(newPath);

    return newImage.path; // 저장된 새 파일의 경로를 반환합니다.
  }
  // ▲▲▲▲▲▲ [추가] 함수 끝 ▲▲▲▲▲▲

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
              // ▼▼▼▼▼▼ [수정] onPressed 콜백 수정 ▼▼▼▼▼▼
              onPressed: () async {
                final String name = _nameController.text;
                final String memo = _memoController.text;

                // 1. _saveImage 함수를 호출하여 사진을 영구 저장소에 저장
                final String savedImagePath = await _saveImage(widget.imagePath);

                // 2. 콘솔에 저장된 정보 출력
                debugPrint('옷 이름: $name');
                debugPrint('메모: $memo');
                debugPrint('영구 저장된 이미지 경로: $savedImagePath');

                // 3. 홈 화면으로 돌아가기
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('옷이 저장되었습니다!')),
                  );
                }
              },
              // ▲▲▲▲▲▲ [수정] 콜백 수정 끝 ▲▲▲▲▲▲
              child: const Text('저장하기'),
            ),
          ],
        ),
      ),
    );
  }
}