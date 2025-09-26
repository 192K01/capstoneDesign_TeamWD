import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  // Singleton 패턴: 앱 전체에서 이 클래스의 인스턴스를 하나만 생성하도록 보장합니다.
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async => _database ??= await _initDatabase();

  // 데이터베이스 파일 경로를 설정하고, 데이터베이스를 엽니다.
  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'fashion_app.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // 앱이 처음 설치될 때 한 번만 호출되어 테이블들을 생성합니다.
  Future _onCreate(Database db, int version) async {
    // 1. schedule 테이블 생성
    await db.execute('''
      CREATE TABLE schedule(
          schedule_id INTEGER PRIMARY KEY,
          user_id INTEGER,
          title TEXT,
          startDate TEXT,
          endDate TEXT,
          location TEXT,
          explanation TEXT,
          category TEXT,
          coordination_id INTEGER
      )
      ''');

    // 2. clothes 테이블 생성
    await db.execute('''
      CREATE TABLE clothes(
          cloth_id INTEGER PRIMARY KEY,
          user_id INTEGER,
          color TEXT,
          category1 TEXT,
          category2 TEXT,
          clothingImg TEXT,
          review TEXT,
          season TEXT
      )
    ''');

    // 3. 테이블 생성 후, 초기 데이터를 JSON 파일들에서 읽어와 삽입합니다.
    await _insertInitialData(db);
  }

  // 초기 데이터를 JSON에서 읽어와 각 테이블에 삽입하는 함수
  Future<void> _insertInitialData(Database db) async {
    // 스케줄 데이터 삽입
    try {
      final String scheduleJson = await rootBundle.loadString('repo/schedule_data.json');
      final List<dynamic> schedules = jsonDecode(scheduleJson);
      for (var schedule in schedules) {
        await db.insert('schedule', schedule as Map<String, dynamic>);
      }
      print("스케줄 초기 데이터가 성공적으로 DB에 삽입되었습니다.");
    } catch (e) {
      print("스케줄 초기 데이터 삽입 중 에러 발생: $e");
    }

    // 옷 데이터 삽입
    try {
      final String clothesJson = await rootBundle.loadString('repo/clothes_data.json');
      final List<dynamic> clothes = jsonDecode(clothesJson);
      for (var cloth in clothes) {
        await db.insert('clothes', cloth as Map<String, dynamic>);
      }
      print("옷 초기 데이터가 성공적으로 DB에 삽입되었습니다.");
    } catch (e) {
      print("옷 초기 데이터 삽입 중 에러 발생: $e");
    }
  }

  // schedule 테이블의 모든 데이터를 가져오는 함수
  Future<List<Map<String, dynamic>>> getSchedules() async {
    Database db = await instance.database;
    return await db.query('schedule');
  }

  // clothes 테이블을 검색하는 함수
  Future<List<Map<String, dynamic>>> searchClothes(String query) async {
    Database db = await instance.database;
    if (query.isEmpty) {
      return await db.query('clothes'); // 검색어가 없으면 모든 옷 반환
    }
    // category2(옷 이름), category1(종류), color 등에서 검색
    return await db.query(
      'clothes',
      where: 'category2 LIKE ? OR category1 LIKE ? OR color LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
    );
  }

// (나중에 추가할 기능들: 일정/옷 추가, 수정, 삭제 함수...)
}