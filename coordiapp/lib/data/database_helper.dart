import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async => _database ??= await _initDatabase();

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'fashion_app.db');
    return await openDatabase(
      path,
      version: 3, // ▼▼▼ 중요! 데이터베이스 구조가 바뀌었으므로 버전을 3으로 올립니다. ▼▼▼
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
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

    // ▼▼▼ [수정] 새로운 clothes 테이블 생성 ▼▼▼
    await db.execute('''
      CREATE TABLE clothes(
          id INTEGER PRIMARY KEY AUTOINCREMENT, 
          user_id INTEGER NOT NULL,
          name TEXT,
          subCategory TEXT,
          articleType TEXT,
          color TEXT,
          clothingImg TEXT,
          memo TEXT
      )
    ''');
    // ▲▲▲ [수정] 새로운 clothes 테이블 생성 ▲▲▲

    await _insertInitialData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 버전에 따라 테이블을 새로 만듭니다.
    if (oldVersion < 3) {
      await db.execute("DROP TABLE IF EXISTS clothes");
      await db.execute("DROP TABLE IF EXISTS schedule");
      await _onCreate(db, newVersion);
    }
  }

  Future<void> _insertInitialData(Database db) async {
    try {
      final String scheduleJson = await rootBundle.loadString(
        'repo/schedule_data.json',
      );
      final List<dynamic> schedules = jsonDecode(scheduleJson);
      for (var schedule in schedules) {
        await db.insert('schedule', schedule as Map<String, dynamic>);
      }
      print("스케줄 초기 데이터가 성공적으로 DB에 삽입되었습니다.");
    } catch (e) {
      print("스케줄 초기 데이터 삽입 중 에러 발생: $e");
    }

    // 초기 옷 데이터는 이제 사용하지 않으므로 주석 처리하거나 삭제합니다.
    /*
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
    */
  }

  Future<List<Map<String, dynamic>>> getSchedules() async {
    Database db = await instance.database;
    return await db.query('schedule');
  }

  // ▼▼▼ [수정] searchClothes 함수 단순화 (이름으로만 검색) ▼▼▼
  Future<List<Map<String, dynamic>>> searchClothes(String query) async {
    Database db = await instance.database;

    // WHERE 절을 사용하여 이름(name)으로 검색
    // user_id는 지금은 1로 고정하여 테스트합니다.
    return await db.query(
      'clothes',
      where: 'user_id = ? AND name LIKE ?',
      whereArgs: [1, '%$query%'],
    );
  }
  // ▲▲▲ [수정] searchClothes 함수 단순화 (이름으로만 검색) ▲▲▲

  // ▼▼▼ [수정] addCloth 함수 컬럼 이름 변경 ▼▼▼
  Future<int> addCloth(Map<String, dynamic> cloth) async {
    Database db = await instance.database;
    // clothes 테이블에 새로운 옷 데이터 삽입
    return await db.insert('clothes', cloth);
  }

  // ▲▲▲ [수정] addCloth 함수 컬럼 이름 변경 ▲▲▲
}
