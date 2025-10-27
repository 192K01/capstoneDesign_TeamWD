# database.py

import sqlite3

DATABASE_NAME = 'users.db'

def init_db():
    """
    데이터베이스를 초기화하고, 모든 테이블 스키마를
    최신 상태로 자동 업데이트(마이그레이션)하는 함수.
    데이터를 삭제하지 않습니다.
    """
    conn = None
    try:
        # 1. 데이터베이스에 연결합니다.
        conn = sqlite3.connect(DATABASE_NAME)
        cursor = conn.cursor()
        print(f"* Database '{DATABASE_NAME}' connected.")

        # 2. 모든 테이블이 존재하는지 확인하고, 없으면 기본 구조로 생성합니다.
        # users 테이블
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT, email TEXT NOT NULL UNIQUE, password_hash TEXT NOT NULL,
                name TEXT NOT NULL, gender TEXT, birth_date TEXT, phone_number TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')

        # clothes 테이블
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS clothes (
                cloth_id INTEGER PRIMARY KEY AUTOINCREMENT, 
                user_id INTEGER, 
                name TEXT, 
                subCategory TEXT,
                articleType TEXT, 
                color TEXT, 
                clothingImg TEXT, memo TEXT,
                FOREIGN KEY(user_id) REFERENCES users(id)
            )
        ''')

	# --- ▼▼▼ [추가] 'outfits' 테이블 생성 ▼▼▼ ---
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS outfits (
                outfit_id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                name TEXT,
                top_cloth_id INTEGER,
                bottom_cloth_id INTEGER,
                shoes_cloth_id INTEGER,
	    tpo_category TEXT, -- 추천된 TPO 카테고리 저장 컬럼 추가
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users (id),
                FOREIGN KEY (top_cloth_id) REFERENCES clothes (cloth_id),    -- clothes 테이블 PK 참조
                FOREIGN KEY (bottom_cloth_id) REFERENCES clothes (cloth_id), -- clothes 테이블 PK 참조
                FOREIGN KEY (shoes_cloth_id) REFERENCES clothes (cloth_id)   -- clothes 테이블 PK 참조
            )
        ''')
        # --- ▲▲▲ [추가] 'outfits' 테이블 생성 ▲▲▲ ---

        print("* Basic table schemas checked/created.")

        # schedule 테이블 (컬럼이 빠져있을 수 있는 기본 구조)
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS schedule (
                schedule_id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, title TEXT,
                start_date TEXT, end_date TEXT, location_name TEXT, location_address TEXT,
                explanation TEXT, FOREIGN KEY(user_id) REFERENCES users(id)
            )
        ''')
        print("* Basic table schemas checked/created.")

        # 3. 'schedule' 테이블의 현재 컬럼 목록을 가져옵니다.
        cursor.execute("PRAGMA table_info(schedule)")
        columns = [column[1] for column in cursor.fetchall()]
	# --- ▼▼▼ [추가] 'outfits' 테이블 업데이트 로직 ▼▼▼ ---
        cursor.execute("PRAGMA table_info(outfits)")
        outfits_columns = [column[1] for column in cursor.fetchall()]

        # 'tpo_category' 컬럼이 없으면 추가
        if 'tpo_category' not in outfits_columns:
            print("  - Updating 'outfits' table... adding 'tpo_category' column.")
            cursor.execute("ALTER TABLE outfits ADD COLUMN tpo_category TEXT")
        # --- ▲▲▲ [추가] 'outfits' 테이블 업데이트 로직 ▲▲▲ ---

        # 4. 'start_time' 컬럼이 없으면 ALTER 명령어로 추가합니다.
        if 'start_time' not in columns:
            print("  - Updating 'schedule' table... adding 'start_time' column.")
            cursor.execute("ALTER TABLE schedule ADD COLUMN start_time TEXT")

        # 5. 'end_time' 컬럼이 없으면 ALTER 명령어로 추가합니다.
        if 'end_time' not in columns:
            print("  - Updating 'schedule' table... adding 'end_time' column.")
            cursor.execute("ALTER TABLE schedule ADD COLUMN end_time TEXT")
        
        # 6. 'participants' 컬럼이 없으면 ALTER 명령어로 추가합니다.
        if 'participants' not in columns:
            print("  - Updating 'schedule' table... adding 'participants' column.")
            cursor.execute("ALTER TABLE schedule ADD COLUMN participants TEXT")

        # 7. 'recurrence_rule' 컬럼이 없으면 추가합니다. (반복 규칙용)
        if 'recurrence_rule' not in columns:
            print("  - Updating 'schedule' table... adding 'recurrence_rule' column.")
            cursor.execute("ALTER TABLE schedule ADD COLUMN recurrence_rule TEXT")

        # 8. 'alarm_unit' 컬럼이 없으면 추가합니다. (알람 단위용)
        if 'alarm_unit' not in columns:
            print("  - Updating 'schedule' table... adding 'alarm_unit' column.")
            cursor.execute("ALTER TABLE schedule ADD COLUMN alarm_unit TEXT")

        # 9. 'alarm_value' 컬럼이 없으면 추가합니다. (알람 값용)
        if 'alarm_value' not in columns:
            print("  - Updating 'schedule' table... adding 'alarm_value' column.")
            cursor.execute("ALTER TABLE schedule ADD COLUMN alarm_value INTEGER")
            
        # --- ▼▼▼ [추가] TPO 컬럼 추가 ▼▼▼ ---
        if 'tpo1' not in columns:
            print("  - Updating 'schedule' table... adding 'tpo1' column.")
            cursor.execute("ALTER TABLE schedule ADD COLUMN tpo1 TEXT")
            
        if 'tpo2' not in columns:
            print("  - Updating 'schedule' table... adding 'tpo2' column.")
            cursor.execute("ALTER TABLE schedule ADD COLUMN tpo2 TEXT")
        # --- ▲▲▲ [추가] TPO 컬럼 추가 ▲▲▲ ---

        conn.commit()
        print("* Database schema is up to date. No data was deleted.")

    except sqlite3.Error as e:
        print(f"AN ERROR OCCURRED during database initialization: {e}")
    finally:
        if conn:
            conn.close()