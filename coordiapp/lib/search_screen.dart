import 'package:flutter/material.dart';
import 'dart:io'; // Image.file을 사용하기 위해 import
import '../data/database_helper.dart';


class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  // SearchScreenState 클래스를 공개로 유지합니다 (main.dart에서 사용).
  SearchScreenState createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen> {
  // performSearch 함수는 이제 아무 동작도 하지 않습니다.
  // main.dart에서 호출될 때 오류가 나지 않도록 형태만 남겨둡니다.
  Future<void> performSearch() async {
    // 아무 작업도 수행하지 않음
    return;
  }

  // --- ▼▼▼ [추가] 상세 정보 팝업을 띄우는 함수 ▼▼▼ ---
  void _showClothDetails(Map<String, dynamic> cloth) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // 별도의 위젯으로 분리하여 팝업 UI를 구성합니다.
        return ClothDetailDialog(cloth: cloth);
      },
    );
  }
  // --- ▲▲▲ [추가] 상세 정보 팝업을 띄우는 함수 ▲▲▲ ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: '옷 이름으로 검색',
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (value) => _performSearch(),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildFilterButtons(),
          if (_activeFilters.isNotEmpty) _buildActiveFilters(),
          Expanded(
            child: _buildResultsGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButtons() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          _buildFilterPopupMenu('스타일', _filterOptions['스타일']!),
          const SizedBox(width: 8),
          _buildFilterPopupMenu('TPO', _filterOptions['TPO']!),
        ],
      ),
    );
  }

  Widget _buildFilterPopupMenu(String title, List<String> options) {
    return PopupMenuButton<String>(
      onSelected: (String value) {
        if (!_activeFilters.contains(value)) {
          setState(() {
            _activeFilters.add(value);
          });
          _performSearch();
        }
      },
      itemBuilder: (BuildContext context) {
        return options.map((String choice) {
          return PopupMenuItem<String>(
            value: choice,
            child: Text(choice),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(title, style: const TextStyle(color: Colors.black)),
            const Icon(Icons.arrow_drop_down, color: Colors.black),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: _activeFilters.map((filter) => Chip(
                label: Text(filter),
                onDeleted: () {
                  setState(() {
                    _activeFilters.remove(filter);
                  });
                  _performSearch();
                },
                backgroundColor: Colors.black,
                labelStyle: const TextStyle(color: Colors.white),
                deleteIconColor: Colors.white,
              )).toList(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _activeFilters.clear();
              });
              _performSearch();
            },
            child: const Text('초기화'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsGrid() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults.isEmpty) {
      return const Center(child: Text('검색 결과가 없습니다.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.7,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final cloth = _searchResults[index];
        final imagePath = cloth['clothingImg'] as String?;

        // --- ▼▼▼ [수정] Card를 InkWell로 감싸서 탭 이벤트를 추가 ▼▼▼ ---
        return InkWell(
          onTap: () => _showClothDetails(cloth), // 탭하면 팝업 함수 호출
          borderRadius: BorderRadius.circular(12),
          child: Card(
            elevation: 0,
            color: Colors.grey[200],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: (imagePath != null && imagePath.isNotEmpty)
                      ? (imagePath.startsWith('assets/'))
                      ? Image.asset( // assets 이미지 처리
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Icon(Icons.error_outline, color: Colors.white)),
                  )
                      : Image.file( // 파일 경로 이미지 처리 (카메라/갤러리)
                    File(imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Icon(Icons.error_outline, color: Colors.white)),
                  )
                      : const Center(child: Icon(Icons.checkroom, size: 60, color: Colors.white)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    cloth['name'] ?? '이름 없음',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
        // --- ▲▲▲ [수정] Card를 InkWell로 감싸서 탭 이벤트를 추가 ▲▲▲ ---
      },
    );
  }
}

// --- ▼▼▼ [추가] 옷 상세정보 팝업 위젯 ▼▼▼ ---
class ClothDetailDialog extends StatelessWidget {
  final Map<String, dynamic> cloth;

  const ClothDetailDialog({super.key, required this.cloth});

  @override
  Widget build(BuildContext context) {
    final imagePath = cloth['clothingImg'] as String?;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 상단 이미지
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
              child: Container(
                height: 300,
                color: Colors.grey[200],
                child: (imagePath != null && imagePath.isNotEmpty)
                    ? (imagePath.startsWith('assets/'))
                    ? Image.asset(imagePath, fit: BoxFit.cover)
                    : Image.file(File(imagePath), fit: BoxFit.cover)
                    : const Center(child: Icon(Icons.checkroom, size: 80, color: Colors.white)),
              ),
            ),
            // 하단 정보
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cloth['name'] ?? '이름 없음',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  _buildDetailRow(Icons.color_lens_outlined, '색상', cloth['color']),
                  _buildDetailRow(Icons.category_outlined, '종류', '${cloth['category1'] ?? ''} > ${cloth['category2'] ?? ''}'),
                  _buildDetailRow(Icons.thermostat_outlined, '계절', cloth['season']),
                  _buildDetailRow(Icons.style_outlined, '스타일', cloth['style']),
                  _buildDetailRow(Icons.event_outlined, 'TPO', cloth['tpo']),
                  _buildDetailRow(Icons.notes_outlined, '리뷰', cloth['review']),
                ],
              ),
            ),
            // 수정 / 삭제 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // TODO: 수정 기능 구현
                        Navigator.pop(context);
                      },
                      child: const Text('수정'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // TODO: 삭제 기능 구현
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                      child: const Text('삭제'),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // 정보 행을 만드는 헬퍼 위젯
  Widget _buildDetailRow(IconData icon, String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
          const Spacer(),
          Text(value ?? '정보 없음', style: TextStyle(color: Colors.grey[800])),
        ],
      ),
    );
  }
}
