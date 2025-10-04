import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
// database_helper.dart가 lib/data/ 폴더에 있다면 아래 import를 사용하세요.
import 'data/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String _processingStatusText = '분석 준비 중...';

  // AI 분석 결과와 사용자의 최종 선택을 분리하여 관리
  String? _selectedSubCategory;
  String? _selectedArticleType;
  String? _selectedColor;

  List<Map<String, dynamic>> _colorStandard = [];

  // 선택 옵션 목록
  final Map<String, String> _subCategoryMap = {
    'Topwear': '상의',
    'Bottomwear': '하의',
    'Shoes': '신발',
  };

  final Map<String, List<String>> _articleTypeOptions = {
    '상의': [
      'Tshirts',
      'Sweaters',
      'Shirts',
      'Dresses',
      'Waistcoat',
      'Jumpsuit',
      'Blazers',
      'Jackets',
    ],
    '하의': [
      'Shorts',
      'Jeans',
      'Skirts',
      'Track Pants',
      'Trousers',
      'Capris',
      'Leggings',
    ],
    '신발': [
      'Casual Shoes',
      'Flip Flops',
      'Sandals',
      'Formal Shoes',
      'Flats',
      'Sports Shoes',
      'Heels',
      'Sports Sandals',
    ],
  };

  final Map<String, List<String>> _colorOptions = {
    '상의': [
      '화이트',
      '화이트 계열',
      '레드',
      '핑크',
      '오렌지',
      '옐로우',
      '그린',
      '블루',
      '네이비',
      '블랙',
      '그레이',
    ],
    '하의': ['연청', '진청', '베이지', '카키', '와인', '블랙', '화이트', '그레이'],
  };

  @override
  void initState() {
    super.initState();
    _initializeAndProcessImage();
  }

  // --- ▼▼▼ [수정] 요청하신 분석 순서대로 로직 변경 ▼▼▼ ---
  Future<void> _initializeAndProcessImage() async {
    // 1. 색상 기준 정보 미리 로드
    await _loadColorData();

    // 2. 배경 제거 실행
    if (mounted) setState(() => _processingStatusText = '배경 제거 중...');
    final newPath = await _removeBackground(widget.imagePath);
    if (mounted) {
      setState(() => _processedImagePath = newPath);
    }

    // 분석에 사용할 이미지 경로 결정 (배경 제거 성공 시 새 경로, 실패 시 원본 경로)
    final imagePathForAnalysis = newPath ?? widget.imagePath;

    // 3. 옷 종류 분석 실행
    if (mounted) setState(() => _processingStatusText = '옷 종류 분석 중...');
    await _analyzeClothType(imagePathForAnalysis);

    // 4. 색상 분석 실행
    if (mounted) setState(() => _processingStatusText = '색상 분석 중...');
    final dominantColor = await _findDominantColor(imagePathForAnalysis);
    if (dominantColor != null) {
      final closestColorName = _findClosestColor(dominantColor, _colorStandard);
      if (mounted) {
        setState(() => _selectedColor = closestColorName);
      }
    }

    // 5. 모든 처리 완료
    if (mounted) setState(() => _isProcessingImage = false);
  }
  // --- ▲▲▲ [수정] 요청하신 분석 순서대로 로직 변경 ▲▲▲ ---

  Future<void> _analyzeClothType(String imagePath) async {
    try {
      const String serverIp = '3.36.66.130';
      final uri = Uri.parse('http://$serverIp:5000/predict');

      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('image', imagePath));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final data = jsonDecode(responseBody);

        if (mounted) {
          setState(() {
            _selectedSubCategory = _subCategoryMap[data['subCategory']];
            _selectedArticleType = data['articleType'];
          });
        }
      } else {
        if (mounted) setState(() => _selectedArticleType = '분석 실패 (서버 오류)');
      }
    } catch (e) {
      debugPrint('옷 종류 분석 중 예외 발생: $e');
      if (mounted) setState(() => _selectedArticleType = '분석 실패 (연결 오류)');
    }
  }

  Future<void> _loadColorData() async {
    final String jsonString = await rootBundle.loadString('assets/colors.json');
    final List<dynamic> jsonResponse = jsonDecode(jsonString);
    _colorStandard = jsonResponse.cast<Map<String, dynamic>>();
  }

  Future<String?> _removeBackground(String imagePath) async {
    const String apiKey = 'HSmQd4FFG1ACQzMgTzU6iiyf'; // 실제 API 키로 교체하세요
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.remove.bg/v1.0/removebg'),
    );
    request.headers['X-Api-Key'] = apiKey;
    request.files.add(
      await http.MultipartFile.fromPath('image_file', imagePath),
    );
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
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('배경 제거 실패. 원본 이미지로 분석합니다.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('배경 제거 중 예외 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('배경 제거 중 오류 발생. 원본 이미지로 분석합니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            pixel.b.toInt(),
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

  String _findClosestColor(
    Color dominantColor,
    List<Map<String, dynamic>> colorStandard,
  ) {
    if (dominantColor.red < 50 &&
        dominantColor.green < 50 &&
        dominantColor.blue < 50) {
      return "블랙";
    }
    String closestColorName = '분석 불가';
    double minDistance = double.infinity;
    for (var colorData in colorStandard) {
      final r = colorData['r'] as int;
      final g = colorData['g'] as int;
      final b = colorData['b'] as int;
      final distance = sqrt(
        pow(dominantColor.red - r, 2) +
            pow(dominantColor.green - g, 2) +
            pow(dominantColor.blue - b, 2),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('아직 이미지 처리 중입니다.')));
      return;
    }
    final String name = _nameController.text;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('옷 이름을 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // --- ▼▼▼ [추가] 저장된 사용자 이메일 불러오기 ▼▼▼ ---
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail');

    if (userEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인 정보가 없습니다. 다시 로그인해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    // --- ▲▲▲ [추가] 저장된 사용자 이메일 불러오기 ▲▲▲ ---

    final imagePathToSave = _processedImagePath ?? widget.imagePath;
    final String memo = _memoController.text;

    try {
      const String serverIp = '3.36.66.130';
      final uri = Uri.parse('http://$serverIp:5000/clothes');

      final newCloth = {
        'email': userEmail, // 이메일을 함께 보냅니다.
        'name': name,
        'subCategory': _selectedSubCategory,
        'articleType': _selectedArticleType,
        'color': _selectedColor,
        'clothingImg': imagePathToSave,
        'memo': memo,
      };

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(newCloth),
      );

      if (mounted) {
        if (response.statusCode == 201) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('옷이 옷장에 저장되었습니다!')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('저장에 실패했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("저장 중 오류 발생: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('네트워크 오류로 저장에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 드롭다운 값 유효성 검사 (화면을 그릴 때마다 실행)
    final articleTypeOptions = _articleTypeOptions[_selectedSubCategory] ?? [];
    final validArticleType = articleTypeOptions.contains(_selectedArticleType)
        ? _selectedArticleType
        : null;

    final colorOptions = _colorOptions[_selectedSubCategory] ?? [];
    final validColor = colorOptions.contains(_selectedColor)
        ? _selectedColor
        : null;

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
                        ? Image.file(
                            File(_processedImagePath!),
                            fit: BoxFit.cover,
                          )
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
                          Text(
                            _processingStatusText,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // --- ▼▼▼ [수정] 드롭다운 UI ▼▼▼ ---
            DropdownButtonFormField<String>(
              value: _selectedSubCategory,
              isExpanded: true, // 너비를 꽉 채우도록 설정
              decoration: const InputDecoration(
                labelText: '중분류',
                border: OutlineInputBorder(),
              ),
              onChanged: _isProcessingImage
                  ? null
                  : (String? newValue) {
                      setState(() {
                        _selectedSubCategory = newValue;
                        _selectedArticleType = null;
                        _selectedColor = null;
                      });
                    },
              items: _subCategoryMap.values.map<DropdownMenuItem<String>>((
                String value,
              ) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: validArticleType,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '상세 품목',
                border: OutlineInputBorder(),
              ),
              onChanged: (_selectedSubCategory == null || _isProcessingImage)
                  ? null
                  : (String? newValue) {
                      setState(() => _selectedArticleType = newValue);
                    },
              items: articleTypeOptions.map<DropdownMenuItem<String>>((
                String value,
              ) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: validColor,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '색상',
                border: OutlineInputBorder(),
              ),
              onChanged:
                  (_selectedSubCategory != '상의' &&
                          _selectedSubCategory != '하의' ||
                      _isProcessingImage)
                  ? null
                  : (String? newValue) {
                      setState(() => _selectedColor = newValue);
                    },
              items: colorOptions.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),

            // --- ▲▲▲ [수정] 드롭다운 UI ▲▲▲ ---
            const SizedBox(height: 16),
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
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
