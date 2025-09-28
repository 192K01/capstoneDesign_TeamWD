// 📂 lib/camera.dart

import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class AddClothingScreen extends StatefulWidget {
  final String imagePath;
  const AddClothingScreen({super.key, required this.imagePath});

  @override
  State<AddClothingScreen> createState() => _AddClothingScreenState();
}

class _AddClothingScreenState extends State<AddClothingScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  String? _processedImagePath;
  bool _isProcessingImage = true;
  String _processingStatusText = '배경 제거 중...';

  String? _analyzedColorName;
  List<Map<String, dynamic>> _colorStandard = [];

  @override
  void initState() {
    super.initState();
    _initializeAndProcessImage();
  }

  Future<void> _initializeAndProcessImage() async {
    await _loadColorData();

    final newPath = await _removeBackground(widget.imagePath);
    if (mounted) setState(() => _processedImagePath = newPath);

    if (newPath != null) {
      if (mounted) setState(() => _processingStatusText = '색상 분석 중...');
      final dominantColor = await _findDominantColor(newPath);

      if (dominantColor != null) {
        final closestColorName = _findClosestColor(dominantColor, _colorStandard);
        if (mounted) setState(() => _analyzedColorName = closestColorName);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('배경 제거에 실패했습니다. 원본 이미지로 진행합니다.')),
        );
      }
    }

    if (mounted) setState(() => _isProcessingImage = false);
  }

  Future<void> _loadColorData() async {
    final String jsonString = await rootBundle.loadString('assets/colors.json');
    final List<dynamic> jsonResponse = jsonDecode(jsonString);
    _colorStandard = jsonResponse.cast<Map<String, dynamic>>();
  }

  Future<String?> _removeBackground(String imagePath) async {
    const String apiKey = 'Hks4J4Kbnp7bEZRb1V64UPGt';
    final request = http.MultipartRequest('POST', Uri.parse('https://api.remove.bg/v1.0/removebg'));
    request.headers['X-Api-Key'] = apiKey;
    request.files.add(await http.MultipartFile.fromPath('image_file', imagePath));
    try {
      final streamedResponse = await request.send();
      if (streamedResponse.statusCode == 200) {
        final bytes = await streamedResponse.stream.toBytes();
        final directory = await getApplicationDocumentsDirectory();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_no_bg.png';
        final newPath = '${directory.path}/$fileName';
        final file = File(newPath);
        await file.writeAsBytes(bytes);
        return newPath;
      }
    } catch (e) {
      debugPrint('배경 제거 중 예외 발생: $e');
    }
    return null;
  }

  Future<Color?> _findDominantColor(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    Map<int, int> colorCounts = {};
    int maxCount = 0;
    int dominantColor = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        if (pixel.a > 0) {
          final color = Color.fromARGB(
              pixel.a.toInt(),
              pixel.r.toInt(),
              pixel.g.toInt(),
              pixel.b.toInt()
          ).value;

          colorCounts[color] = (colorCounts[color] ?? 0) + 1;
          if (colorCounts[color]! > maxCount) {
            maxCount = colorCounts[color]!;
            dominantColor = color;
          }
        }
      }
    }
    return Color(dominantColor);
  }

  // 👇👇👇 이 함수가 수정되었습니다 👇👇👇
  String _findClosestColor(Color dominantColor, List<Map<String, dynamic>> colorStandard) {
    // ✨✨✨ 추가된 임계값 로직 ✨✨✨
    // R, G, B 값이 모두 50보다 작으면 충분히 어두운 색으로 간주하여 '블랙'으로 바로 반환합니다.
    if (dominantColor.red < 50 && dominantColor.green < 50 && dominantColor.blue < 50) {
      return "블랙";
    }
    // ✨✨✨ 여기까지 추가 ✨✨✨

    String closestColorName = '분석 불가';
    double minDistance = double.infinity;

    for (var colorData in colorStandard) {
      final r = colorData['r'] as int;
      final g = colorData['g'] as int;
      final b = colorData['b'] as int;

      final distance = sqrt(
          pow(dominantColor.red - r, 2) +
              pow(dominantColor.green - g, 2) +
              pow(dominantColor.blue - b, 2)
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestColorName = colorData['name_ko'] as String;
      }
    }
    return closestColorName;
  }

  Future<void> _saveClothingItem() async {
    if (_isProcessingImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아직 이미지 처리 중입니다.')),
      );
      return;
    }
    final imagePathToSave = _processedImagePath ?? widget.imagePath;
    final String name = _nameController.text;
    final String memo = _memoController.text;

    debugPrint('--- 저장된 옷 정보 ---');
    debugPrint('옷 이름: $name');
    debugPrint('메모: $memo');
    debugPrint('분석된 색상: $_analyzedColorName');
    debugPrint('최종 저장 이미지 경로: $imagePathToSave');
    debugPrint('--------------------');

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('옷이 저장되었습니다!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('새 옷 정보 입력'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 300,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: _processedImagePath != null
                        ? Image.file(File(_processedImagePath!), fit: BoxFit.cover)
                        : Image.file(File(widget.imagePath), fit: BoxFit.cover),
                  ),
                ),
                if (_isProcessingImage)
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 12),
                          Text(_processingStatusText, style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (_analyzedColorName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: TextField(
                  readOnly: true,
                  controller: TextEditingController(text: _analyzedColorName),
                  decoration: InputDecoration(
                    labelText: '분석된 색상',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[200],
                  ),
                ),
              ),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '옷 이름',
                border: OutlineInputBorder(),
                hintText: '예: 파란색 맨투맨',
              ),
            ),
            const SizedBox(height: 16),
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              onPressed: _isProcessingImage ? null : _saveClothingItem,
              child: const Text('저장하기'),
            ),
          ],
        ),
      ),
    );
  }
}