import 'package:flutter/material.dart';
import '../data/database_helper.dart'; // lib/data 폴더의 database_helper.dart를 import

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
    '스타일': ['상의', '하의', '아우터', '신발'],
    'TPO': ['일상 & 캐주얼', '비즈니스 & 포멀', '특별한 날 & 데이트', '활동적인 날'],
  };

  @override
  void initState() {
    super.initState();
    // 화면이 처음 열릴 때 모든 옷 데이터를 불러옴
    _performSearch('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 데이터베이스에 검색을 요청하는 함수
  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
    });

    final dbHelper = DatabaseHelper.instance;
    final results = await dbHelper.searchClothes(query);

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
              hintText: '옷 이름, 종류, 색상 등 검색',
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
            // 텍스트가 변경될 때마다 검색 수행
            onChanged: (value) => _performSearch(value),
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
          const SizedBox(width: 8),
          IconButton(onPressed: () {}, icon: const Icon(Icons.filter_list)),
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
          // 나중에 필터 로직을 여기에 추가할 수 있습니다.
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
          child: imagePath != null && imagePath.isNotEmpty
              ? Image.asset(
            imagePath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Center(child: Icon(Icons.error_outline, color: Colors.white));
            },
          )
              : const Center(child: Icon(Icons.checkroom, size: 60, color: Colors.white)),
        );
      },
    );
  }
}