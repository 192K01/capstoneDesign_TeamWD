import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('검색')),
      body: const Center(
        child: Text(
          '검색 기능은 준비 중입니다.',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ),
    );
  }
}
