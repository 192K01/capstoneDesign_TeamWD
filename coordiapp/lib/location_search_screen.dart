// 📂 lib/location_search_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({super.key});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isLoading = false;

  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    const String clientId = 'WkcnrhscDf9afdyTC9Cq';
    const String clientSecret = '7fKmpqhZlF';
    final url = Uri.parse('https://openapi.naver.com/v1/search/local.json?query=${Uri.encodeComponent(query)}&display=5');

    try {
      final response = await http.get(
        url,
        headers: {
          'X-Naver-Client-Id': clientId,
          'X-Naver-Client-Secret': clientSecret,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _searchResults = data['items'] ?? [];
        });
      } else {
        print('API 호출 에러: ${response.statusCode}');
        _searchResults = [];
      }
    } catch (e) {
      print('검색 중 예외 발생: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 검색'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '장소 또는 주소 검색',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    _searchAddress(_searchController.text);
                  },
                ),
              ),
              onSubmitted: (value) {
                _searchAddress(value);
              },
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final place = _searchResults[index];
                  final title = place['title']?.replaceAll(RegExp(r'<[^>]*>'), '') ?? '이름 없음';
                  final roadAddress = place['roadAddress'] ?? '주소 정보 없음';

                  return ListTile(
                    title: Text(title),
                    subtitle: Text(roadAddress),
                    onTap: () {
                      // ▼▼▼ 주소만 전달하던 것을, 장소 이름과 주소를 Map 형태로 전달하도록 수정 ▼▼▼
                      Navigator.pop(context, {
                        'name': title,
                        'address': roadAddress,
                      });
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
