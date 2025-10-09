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
      version: 2, // ▼▼▼ 1. 데이터베이스 버전을 1에서 2로 올립니다. ▼▼▼
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // ▼▼▼ 2. 업그레이드 로직을 실행할 함수를 지정합니다. ▼▼▼
    );
  }

  // 앱이 처음 설치될 때 한 번만 호출되어 테이블들을 생성합니다.
  Future _onCreate(Database db, int version) async {
    // 1. schedule 테이블 생성 (수정)
    await db.execute('''
      CREATE TABLE schedule(
          schedule_id INTEGER PRIMARY KEY AUTOINCREMENT, // AUTOINCREMENT 추가
          user_id INTEGER,
          title TEXT,
          startDate TEXT,
          endDate TEXT,
          startTime TEXT, // 시작 시간 컬럼 추가
          endTime TEXT, // 종료 시간 컬럼 추가
          location TEXT,
          explanation TEXT,
          category TEXT,
          coordination_id INTEGER
      )
      ''');

    // 2. clothes 테이블 생성 (name, style, tpo 컬럼 추가)
    await db.execute('''
      CREATE TABLE clothes(
          cloth_id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER,
          name TEXT,
          color TEXT,
          category1 TEXT,
          category2 TEXT,
          clothingImg TEXT,
          review TEXT,
          season TEXT,
          style TEXT,
          tpo TEXT
      )
    ''');

    // 3. 테이블 생성 후, 초기 데이터를 JSON 파일들에서 읽어와 삽입합니다.
    await _insertInitialData(db);
  }

  // ▼▼▼ 3. 데이터베이스 버전이 올라갔을 때 실행될 업그레이드 함수입니다. ▼▼▼
  // 기존 테이블을 삭제하고 onCreate를 다시 호출하여 테이블을 새로 만듭니다.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("DROP TABLE IF EXISTS clothes");
      await db.execute("DROP TABLE IF EXISTS schedule");
      await _onCreate(db, newVersion);
    }
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

  // 옷 이름 검색 및 필터링 함수
  Future<List<Map<String, dynamic>>> searchClothes(String query, {List<String> styleFilters = const [], List<String> tpoFilters = const []}) async {
    Database db = await instance.database;

    // WHERE 절과 인자를 동적으로 구성
    String whereClause = 'name LIKE ?';
    List<dynamic> whereArgs = ['%$query%'];

    if (styleFilters.isNotEmpty) {
      // style 필터 추가
      whereClause += ' AND style IN (${styleFilters.map((_) => '?').join(', ')})';
      whereArgs.addAll(styleFilters);
    }
    if (tpoFilters.isNotEmpty) {
      // tpo 필터 추가
      whereClause += ' AND tpo IN (${tpoFilters.map((_) => '?').join(', ')})';
      whereArgs.addAll(tpoFilters);
    }

    return await db.query(
      'clothes',
      where: whereClause,
      whereArgs: whereArgs,
    );
  }

  // 옷 추가 함수
  Future<int> addCloth(Map<String, dynamic> cloth) async {
    Database db = await instance.database;
    return await db.insert('clothes', cloth);
  }
}