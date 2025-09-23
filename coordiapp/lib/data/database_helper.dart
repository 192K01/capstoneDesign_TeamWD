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
    final path = join(documentsDirectory.path, 'schedules.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // 앱이 처음 설치될 때 한 번만 호출되어 테이블을 생성합니다.
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
    // 테이블 생성 후, 초기 데이터를 JSON 파일에서 읽어와 삽입합니다.
    await _insertInitialData(db);
  }

  // 초기 데이터를 JSON에서 읽어와 DB에 삽입하는 함수
  Future<void> _insertInitialData(Database db) async {
    try {
      final String jsonString = await rootBundle.loadString('repo/schedule_data.json');
      final List<dynamic> schedules = jsonDecode(jsonString);

      for (var schedule in schedules) {
        await db.insert('schedule', schedule as Map<String, dynamic>);
      }
      print("초기 데이터가 성공적으로 DB에 삽입되었습니다.");
    } catch (e) {
      print("초기 데이터 삽입 중 에러 발생: $e");
    }
  }

  // schedule 테이블의 모든 데이터를 가져오는 함수
  Future<List<Map<String, dynamic>>> getSchedules() async {
    Database db = await instance.database;
    return await db.query('schedule');
  }

// (나중에 추가할 기능들: 일정 추가, 수정, 삭제 함수...)
}