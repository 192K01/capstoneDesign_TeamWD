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
  // 색상 옵션 Map
  final Map<String, List<String>> _colorOptions = {
    // '상의': [
    //   '화이트',
    //   '화이트 계열',
    //   '레드',
    //   '핑크',
    //   '오렌지',
    //   '옐로우',
    //   '그린',
    //   '블루',
    //   '네이비',
    //   '블랙',
    //   '그레이',
    // ],
    // '하의': ['연청', '진청', '베이지', '카키', '와인', '블랙', '화이트', '그레이'],
    // '상의' 색상 옵션
    '상의': ['화이트', '화이트 계열', '레드', '핑크', '오렌지', '옐로우',
      '그린', '블루', '네이비', '블랙', '그레이', '연청', '진청', '베이지', '카키', '와인'],
    // '하의' 색상 옵션
    '하의': ['화이트', '화이트 계열', '레드', '핑크', '오렌지', '옐로우',
      '그린', '블루', '네이비', '블랙', '그레이', '연청', '진청', '베이지', '카키', '와인'],
    // '신발' 색상 옵션
    '신발': ['화이트', '화이트 계열', '레드', '핑크', '오렌지', '옐로우',
      '그린', '블루', '네이비', '블랙', '그레이', '연청', '진청', '베이지', '카키', '와인'],
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
    // assets/colors.json 파일을 로드합니다. (이 파일에 L, a, b 값이 있어야 합니다)
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

  // --- ▼▼▼ [수정] RGB-to-Lab 변환 헬퍼 함수 추가 (및 print 구문 추가) ▼▼▼ ---
  List<double> _rgbToLab(Color color) {
    // --- ▼▼▼ [요청] RGB 값 출력 ▼▼▼ ---
    print('--- [Color Analysis] ---');
    print('Input RGB: R=${color.red}, G=${color.green}, B=${color.blue}');
    // --- ▲▲▲ [요청] RGB 값 출력 ▲▲▲ ---

    // 1. RGB to XYZ
    double r = color.red / 255.0;
    double g = color.green / 255.0;
    double b = color.blue / 255.0;

    r = (r > 0.04045) ? pow((r + 0.055) / 1.055, 2.4).toDouble() : r / 12.92;
    g = (g > 0.04045) ? pow((g + 0.055) / 1.055, 2.4).toDouble() : g / 12.92;
    b = (b > 0.04045) ? pow((b + 0.055) / 1.055, 2.4).toDouble() : b / 12.92;

    r *= 100.0;
    g *= 100.0;
    b *= 100.0;

    // D65/2° Illuminant
    double x = r * 0.4124564 + g * 0.3575761 + b * 0.1804375;
    double y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750;
    double z = r * 0.0193339 + g * 0.1191920 + b * 0.9503041;

    // 2. XYZ to Lab
    double refX = 95.047;
    double refY = 100.000;
    double refZ = 108.883;

    x /= refX;
    y /= refY;
    z /= refZ;

    x = (x > 0.008856) ? pow(x, 1.0 / 3.0).toDouble() : (7.787 * x) + (16.0 / 116.0);
    y = (y > 0.008856) ? pow(y, 1.0 / 3.0).toDouble() : (7.787 * y) + (16.0 / 116.0);
    z = (z > 0.008856) ? pow(z, 1.0 / 3.0).toDouble() : (7.787 * z) + (16.0 / 116.0);

    double l = (116.0 * y) - 16.0;
    double a = 500.0 * (x - y);
    double bLab = 200.0 * (y - z);

    // --- ▼▼▼ [요청] LAB 값 출력 ▼▼▼ ---
    print('Calculated LAB: L=${l.toStringAsFixed(2)}, a=${a.toStringAsFixed(2)}, b=${bLab.toStringAsFixed(2)}');
    print('------------------------');
    // --- ▲▲▲ [요청] LAB 값 출력 ▲▲▲ ---

    return [l, a, bLab];
  }
  // --- ▲▲▲ [수정] RGB-to-Lab 변환 헬퍼 함수 추가 (및 print 구문 추가) ▲▲▲ ---

  // --- ▼▼▼ [수정] Lab 값으로 유클리드 거리 계산 ▼▼▼ ---
  String _findClosestColor(
      Color dominantColor,
      List<Map<String, dynamic>> colorStandard,
      ) {
    // 1. 검정색 예외 처리 (Lab 변환 시 부정확할 수 있음)
    if (dominantColor.red < 50 &&
        dominantColor.green < 50 &&
        dominantColor.blue < 50) {
      return "블랙";
    }

    // 2. 주조색(RGB)을 Lab 값으로 변환
    final dominantLab = _rgbToLab(dominantColor);
    final dominantL = dominantLab[0];
    final dominantA = dominantLab[1];
    final dominantB = dominantLab[2];

    String closestColorName = '분석 불가';
    double minDistance = double.infinity;

    // 3. colorStandard (JSON)에 있는 Lab 값들과 거리 비교
    for (var colorData in colorStandard) {
      // JSON에서 L, a, b 값을 가져옵니다.
      // (num으로 받고 toDouble()을 사용하여 int/double 타입 모두 호환)
      final stdL = (colorData['L'] as num).toDouble();
      final stdA = (colorData['a'] as num).toDouble();
      final stdB = (colorData['b'] as num).toDouble();

      // 4. CIELAB 유클리드 거리 계산
      final distance = sqrt(
        pow(dominantL - stdL, 2) +
            pow(dominantA - stdA, 2) +
            pow(dominantB - stdB, 2),
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestColorName = colorData['name_ko'] as String;
      }
    }
    return closestColorName;
  }
  // --- ▲▲▲ [수정] Lab 값으로 유클리드 거리 계산 ▲▲▲ ---

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

    final imagePathToUpload =
        _processedImagePath ?? widget.imagePath; // 업로드할 이미지 경로
    final String memo = _memoController.text;

    // --- ▼▼▼ [추가] 이미지 업로드 로직 ▼▼▼ ---
    String? imageUrlOnServer; // 서버에 저장된 이미지 경로/URL
    try {
      setState(() => _processingStatusText = '이미지 업로드 중...');
      const String serverIp = '3.36.66.130';
      final uploadUri = Uri.parse('http://$serverIp:5000/upload_image');
      var request = http.MultipartRequest('POST', uploadUri);
      request.files.add(
        await http.MultipartFile.fromPath('image', imagePathToUpload),
      );

      var response = await request.send();

      if (response.statusCode == 201) {
        final responseBody = await response.stream.bytesToString();
        final data = jsonDecode(responseBody);
        imageUrlOnServer = data['image_url']; // 서버가 돌려준 경로/URL 저장
      } else {
        final errorBody = await response.stream.bytesToString(); // 오류 내용 확인
        print("Upload failed: ${response.statusCode}, $errorBody");
        throw Exception('이미지 업로드 실패 (${response.statusCode})');
      }
    } catch (e) {
      debugPrint("이미지 업로드 오류: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미지 업로드 실패. 저장을 중단합니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // 이미 업로드 시작했으므로 로딩 상태는 유지하거나, 실패 처리 후 종료
      if (mounted)
        setState(() => _processingStatusText = '업로드 실패'); // 상태 텍스트 변경
      // return; // 여기서 중단할지 여부 결정
    }
    // --- ▲▲▲ [추가] 이미지 업로드 로직 ▲▲▲ ---

    if (imageUrlOnServer != null) {
      try {
        if (mounted) setState(() => _processingStatusText = '옷 정보 저장 중...');
        const String serverIp = '3.36.66.130';
        final uri = Uri.parse('http://$serverIp:5000/clothes');

        final newCloth = {
          'email': userEmail,
          'name': name,
          'subCategory': _selectedSubCategory,
          'articleType': _selectedArticleType,
          'color': _selectedColor,
          // --- ▼▼▼ [핵심 수정] 로컬 경로 대신 서버 URL/경로 저장 ▼▼▼ ---
          'clothingImg': imageUrlOnServer,
          // --- ▲▲▲ [핵심 수정] 로컬 경로 대신 서버 URL/경로 저장 ▲▲▲ ---
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
            final errorData = jsonDecode(response.body);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '옷 정보 저장 실패: ${errorData['message'] ?? response.reasonPhrase}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint("옷 정보 저장 중 오류 발생: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('네트워크 오류로 저장에 실패했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessingImage = false); // 최종 로딩 종료
      }
    } else {
      // 이미지 업로드 자체가 실패했으면 로딩 종료
      if (mounted) setState(() => _isProcessingImage = false);
    }
    // --- ▲▲▲ [수정] 이미지 업로드가 성공했을 때만 옷 정보 저장 시도 ▲▲▲ ---
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
                  _selectedSubCategory != '하의' &&
                  _selectedSubCategory != '신발') // [수정] 신발도 포함
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