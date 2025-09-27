import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  // DB 검색 결과를 담을 리스트
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  // 활성화된 필터 (UI용)
  final List<String> _activeFilters = [];
  final Map<String, List<String>> _filterOptions = {
    '스타일': ['캐주얼', '스트릿', '포멀', '비즈니스 캐주얼'],
    'TPO': ['일상 & 캐주얼', '비즈니스 & 포멀', '특별한 날 & 데이트', '활동적인 날'],
  };

  @override
  void initState() {
    super.initState();
    // 화면이 처음 열릴 때 모든 옷 데이터를 불러옴
    _performSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 데이터베이스에 검색 및 필터링을 요청하는 함수
  Future<void> _performSearch() async {
    setState(() {
      _isLoading = true;
    });

    final dbHelper = DatabaseHelper.instance;
    final query = _searchController.text;

    // 활성화된 필터를 '스타일'과 'TPO'로 구분
    final styleFilters = _activeFilters.where((filter) => _filterOptions['스타일']!.contains(filter)).toList();
    final tpoFilters = _activeFilters.where((filter) => _filterOptions['TPO']!.contains(filter)).toList();

    // DB 헬퍼에 검색어와 필터 목록을 전달
    final results = await dbHelper.searchClothes(query, styleFilters: styleFilters, tpoFilters: tpoFilters);

    setState(() {
      _searchResults = results;
      _isLoading = false;
    });
  }

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
              hintText: '옷 이름으로 검색', // 힌트 텍스트 변경
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
            // 텍스트가 변경될 때마다 검색 수행
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
          _performSearch(); // 필터가 추가되면 검색을 다시 수행
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
                  _performSearch(); // 필터가 제거되면 검색을 다시 수행
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
              _performSearch(); // 필터를 초기화하면 검색을 다시 수행
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

        return Card(
          elevation: 0,
          color: Colors.grey[200],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: imagePath != null && imagePath.isNotEmpty
                    ? Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(child: Icon(Icons.error_outline, color: Colors.white));
                  },
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
        );
      },
    );
  }
}