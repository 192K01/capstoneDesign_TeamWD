# server.py

import os
from werkzeug.utils import secure_filename
from datetime import datetime
import sqlite3
from werkzeug.security import generate_password_hash, check_password_hash
from flask import Flask, request, jsonify, send_from_directory
from PIL import Image
import numpy as np
import pandas as pd
import math

from predict import load_model, preprocess_image, predict_cloth_type
from database import init_db, DATABASE_NAME

app = Flask(__name__)

init_db()
load_model()

# --- ▼▼▼ [추가] 이미지 업로드를 위한 설정 ▼▼▼ ---
UPLOAD_FOLDER = 'uploads' # 이미지를 저장할 폴더 이름
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg'} # 허용할 확장자

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# 폴더가 없으면 생성
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS
# --- ▲▲▲ [추가] 이미지 업로드를 위한 설정 ▲▲▲ ---

# 날씨 규칙 정의
WEATHER_RULES = {
    'summer': { 'min_temp': 25, 'max_temp': 50, 'topwear': ['Tshirts', 'Dresses', 'Jumpsuit'], 'bottomwear': ['Shorts', 'Capris', 'Skirts'], 'shoes': ['Casual Shoes', 'Sandals', 'Flip Flops', 'Sports Sandals'] },
    'spring/fall': { 'min_temp': 15, 'max_temp': 24, 'topwear': ['Shirts', 'Tshirts', 'Blazers', 'Sweaters', 'Jackets', 'Sweatshirts'], 'bottomwear': ['Jeans', 'Trousers', 'Skirts', 'Jeggings', 'Leggings'], 'shoes': ['Casual Shoes', 'Formal Shoes', 'Flats', 'Sneakers', 'Sports Shoes'] },
    'early_winter': { 'min_temp': 5, 'max_temp': 14, 'topwear': ['Sweaters', 'Blazers', 'Jackets', 'Waistcoat', 'Sweatshirts'], 'bottomwear': ['Jeans', 'Trousers', 'Leggings'], 'shoes': ['Casual Shoes', 'Formal Shoes', 'Sneakers', 'Sports Shoes'] },
    'mid_winter': { 'min_temp': -50, 'max_temp': 4, 'topwear': ['Sweaters', 'Jackets'], 'bottomwear': ['Jeans', 'Trousers', 'Leggings'], 'shoes': ['Casual Shoes', 'Formal Shoes', 'Sports Shoes'] }
}

def get_weather_season(temp):
    """주어진 온도에 맞는 계절을 반환합니다."""
    if temp is None: return None
    for season, rules in WEATHER_RULES.items():
        if rules['min_temp'] <= temp <= rules['max_temp']:
            return season
    print(f"Warning: Temperature {temp} does not fit any season rule.")
    return None

def filter_by_weather(df, temp):
    """날씨에 맞는 옷들을 데이터프레임에서 필터링하여 반환합니다."""
    season = get_weather_season(temp)
    if not season:
        print("온도 정보가 없거나 맞는 계절 규칙이 없어 날씨 필터링을 건너뜁니다.")
        return df # 필터링 없이 원본 반환

    print(f"날씨 필터 적용: 현재 계절 '{season}' (온도: {temp})")
    season_rules = WEATHER_RULES[season]
    # 각 카테고리별 허용 목록 가져오기 (없으면 빈 리스트)
    allowed_tops = season_rules.get('topwear', [])
    allowed_bottoms = season_rules.get('bottomwear', [])
    allowed_shoes = season_rules.get('shoes', [])

    # 상의, 하의, 신발 각각 필터링 후 합치기
    filtered_df = pd.concat([
        df[(df['subCategory'] == '상의') & (df['articleType'].isin(allowed_tops))],
        df[(df['subCategory'] == '하의') & (df['articleType'].isin(allowed_bottoms))],
        df[(df['subCategory'] == '신발') & (df['articleType'].isin(allowed_shoes))]
    ]).copy() # .copy() 추가

    print(f"날씨 필터링 후 남은 옷 개수: {len(filtered_df)}")
    if filtered_df.empty:
         print("Warning: 날씨 필터링 후 남은 옷이 없습니다.")
    return filtered_df

# TPO 점수 부여 규칙
TPO_SCORES = {
    'Casual & Daily': { 'Tshirts': 10, 'Shirts': 7, 'Sweaters': 8, 'Blazers': 3, 'Jackets': 6, 'Dresses': 9, 'Jumpsuit': 8, 'Waistcoat': 5, 'Jeans': 10, 'Shorts': 9, 'Skirts': 8, 'Track Pants': 9, 'Trousers': 6, 'Capris': 8, 'Leggings': 10, 'Casual Shoes': 10, 'Sports Shoes': 9, 'Flip Flops': 9, 'Sandals': 8, 'Formal Shoes': 2, 'Flats': 7, 'Heels': 3, 'Sports Sandals': 9 },
    'Business & Formal': { 'Tshirts': 1, 'Shirts': 10, 'Sweaters': 7, 'Blazers': 10, 'Jackets': 9, 'Dresses': 10, 'Jumpsuit': 7, 'Waistcoat': 9, 'Jeans': 2, 'Shorts': 1, 'Skirts': 9, 'Track Pants': 1, 'Trousers': 10, 'Capris': 2, 'Leggings': 1, 'Casual Shoes': 1, 'Sports Shoes': 1, 'Flip Flops': 1, 'Sandals': 1, 'Formal Shoes': 10, 'Flats': 8, 'Heels': 10, 'Sports Sandals': 1 },
    'Special Occasion & Date': { 'Tshirts': 4, 'Shirts': 9, 'Sweaters': 8, 'Blazers': 8, 'Jackets': 7, 'Dresses': 10, 'Jumpsuit': 9, 'Waistcoat': 6, 'Jeans': 5, 'Shorts': 3, 'Skirts': 10, 'Track Pants': 1, 'Trousers': 8, 'Capris': 4, 'Leggings': 2, 'Casual Shoes': 3, 'Sports Shoes': 2, 'Flip Flops': 2, 'Sandals': 5, 'Formal Shoes': 9, 'Flats': 8, 'Heels': 10, 'Sports Sandals': 2 },
    'Active Day': { 'Tshirts': 10, 'Shirts': 2, 'Sweaters': 4, 'Blazers': 1, 'Jackets': 8, 'Dresses': 1, 'Jumpsuit': 3, 'Waistcoat': 7, 'Jeans': 2, 'Shorts': 10, 'Skirts': 1, 'Track Pants': 10, 'Trousers': 3, 'Capris': 9, 'Leggings': 10, 'Casual Shoes': 9, 'Sports Shoes': 10, 'Flip Flops': 8, 'Sandals': 7, 'Formal Shoes': 1, 'Flats': 2, 'Heels': 1, 'Sports Sandals': 10 }
    # coordination.ipynb 와 TPO 이름 통일 필요 (예: '운동' -> 'Active Day')
}

# 색상 조합 규칙
COLOR_RULES = {
    'white': ['light blue', 'dark blue', 'beige', 'khaki', 'wine', 'black'],
    'white series': ['light blue', 'dark blue', 'beige', 'khaki', 'wine', 'black'],
    'red': ['beige', 'wine', 'black'],
    'pink': ['light blue', 'dark blue', 'beige', 'khaki', 'wine', 'black'],
    'orange': ['light blue', 'dark blue', 'beige', 'wine', 'black'],
    'yellow': ['light blue', 'dark blue', 'beige', 'khaki', 'wine', 'black'],
    'green': ['light blue', 'dark blue', 'beige', 'wine', 'black'],
    'blue': ['dark blue', 'beige', 'wine', 'black'],
    'navy': ['light blue', 'dark blue', 'beige', 'khaki', 'wine', 'black'],
    'black': ['light blue', 'dark blue', 'beige', 'khaki', 'wine', 'black', 'white', 'white series', 'gray'], # 검정 하의에 흰색/회색 상의 허용
    'gray': ['dark blue', 'beige', 'wine', 'black']
    # coordination.ipynb 와 색상 이름 통일 필요 (예: '화이트' -> 'white')
}

def get_color_matches(top_color, bottom_color):
    """상의와 하의 색상 조합 규칙에 맞는지 확인합니다."""
    # 색상값이 없거나(None 또는 NaN) 규칙에 없으면 True 반환 (조합 허용)
    if pd.isna(top_color) or top_color not in COLOR_RULES:
        return True
    if pd.isna(bottom_color):
        return True
    return bottom_color in COLOR_RULES.get(top_color, []) # .get 사용으로 키 에러 방지

# --- ▲▲▲ coordination.ipynb 로직 추가 ▲▲▲ ---

@app.route('/')
def home():
    return "AI 모델 서버가 작동 중입니다."

@app.route('/predict', methods=['POST'])
def handle_prediction():
    if 'image' not in request.files:
        return jsonify({'error': '이미지 파일이 없습니다.'}), 400
    image_file = request.files['image']
    try:
        processed_image = preprocess_image(image_file.stream)
        prediction_result = predict_cloth_type(processed_image)
        return jsonify(prediction_result)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')
    name = data.get('name')
    gender = data.get('gender')
    birth_date = data.get('birth_date')
    phone_number = data.get('phone_number')

    if not email or not password or not name:
        return jsonify({'message': '필수 정보를 모두 입력해주세요.'}), 400

    conn = sqlite3.connect(DATABASE_NAME)
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM users WHERE email = ?", (email,))
    if cursor.fetchone():
        conn.close()
        return jsonify({'message': '이미 사용 중인 이메일입니다.'}), 409

    password_hash = generate_password_hash(password)
    try:
        cursor.execute('''
            INSERT INTO users (email, password_hash, name, gender, birth_date, phone_number)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (email, password_hash, name, gender, birth_date, phone_number))
        conn.commit()
        message = '회원가입이 완료되었습니다.'
        status_code = 200
    except sqlite3.Error as e:
        conn.rollback()
        message = f'데이터베이스 오류: {e}'
        status_code = 500
    finally:
        conn.close()
    return jsonify({'message': message}), status_code

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')

    if not email or not password:
        return jsonify({"message": "이메일과 비밀번호를 모두 입력해주세요."}), 400

    conn = sqlite3.connect(DATABASE_NAME)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM users WHERE email = ?", (email,))
    user = cursor.fetchone()
    conn.close()

    if user and check_password_hash(user['password_hash'], password):
        return jsonify({"message": "로그인 성공!", "userName": user['name']}), 200
    else:
        return jsonify({"message": "이메일 또는 비밀번호가 잘못되었습니다."}), 401

@app.route('/clothes/<email>', methods=['GET'])
def get_clothes(email):
    if not email:
        return jsonify({"message": "이메일 정보가 필요합니다."}), 400

    conn = sqlite3.connect(DATABASE_NAME)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute("SELECT id FROM users WHERE email = ?", (email,))
    user_row = cursor.fetchone()

    if user_row is None:
        conn.close()
        return jsonify({"message": "사용자를 찾을 수 없습니다."}), 404

    user_id = user_row['id']

    cursor.execute("SELECT * FROM clothes WHERE user_id = ?", (user_id,))
    clothes_rows = cursor.fetchall()
    conn.close()
    
    clothes_list = [dict(row) for row in clothes_rows]
    return jsonify(clothes_list)

# --- ▼▼▼ [추가됨] 옷 삭제 API 엔드포인트 ▼▼▼ ---
@app.route('/clothes/<int:cloth_id>', methods=['DELETE'])
def delete_cloth(cloth_id):
    conn = None
    try:
        conn = sqlite3.connect(DATABASE_NAME)
        cursor = conn.cursor()

        # 삭제하려는 옷이 존재하는지 확인
        cursor.execute("SELECT cloth_id FROM clothes WHERE cloth_id = ?", (cloth_id,))
        cloth_exists = cursor.fetchone()

        if not cloth_exists:
            conn.close()
            return jsonify({"message": "삭제할 옷을 찾을 수 없습니다."}), 404

        # 옷 삭제 실행
        cursor.execute("DELETE FROM clothes WHERE cloth_id = ?", (cloth_id,))
        conn.commit()

        # 삭제된 행의 수가 0보다 크면 성공
        if conn.total_changes > 0:
            return jsonify({"message": "옷이 성공적으로 삭제되었습니다."}), 200
        else:
            # 동시성 문제 등으로 삭제되지 않은 경우
            return jsonify({"message": "옷 삭제에 실패했습니다."}), 500

    except sqlite3.Error as e:
        if conn:
            conn.rollback()  # 오류 발생 시 롤백
        print(f"An error occurred in DELETE /clothes/<cloth_id>: {e}")
        return jsonify({"message": f"데이터베이스 오류: {e}"}), 500
    except Exception as e:
        print(f"An error occurred in DELETE /clothes/<cloth_id>: {e}")
        return jsonify({"message": f"서버 내부 오류: {e}"}), 500
    finally:
        if conn:
            conn.close()
# --- ▲▲▲ [추가됨] 옷 삭제 API 엔드포인트 ▲▲▲ ---

# --- ▼▼▼ [신규 추가] 옷 메모 수정 (PATCH) API 엔드포인트 ▼▼▼ ---
@app.route('/clothes/<int:cloth_id>', methods=['PATCH'])
def update_cloth_memo(cloth_id):
    data = request.get_json()
    new_memo = data.get('memo')

    if new_memo is None: # 'memo' 키가 없거나 값이 null일 경우
        return jsonify({"message": "메모 내용이 없습니다."}), 400

    conn = None
    try:
        conn = sqlite3.connect(DATABASE_NAME)
        cursor = conn.cursor()

        # 1. 해당 cloth_id가 존재하는지 확인
        cursor.execute("SELECT 1 FROM clothes WHERE cloth_id = ?", (cloth_id,))
        cloth_exists = cursor.fetchone()

        if not cloth_exists:
            return jsonify({"message": "수정할 옷을 찾을 수 없습니다."}), 404

        # 2. 메모 업데이트 실행
        cursor.execute('''
            UPDATE clothes 
            SET memo = ? 
            WHERE cloth_id = ?
        ''', (new_memo, cloth_id))
        conn.commit()

        # 3. 변경 사항 확인
        if conn.total_changes > 0:
            return jsonify({"message": "메모가 성공적으로 업데이트되었습니다.", "memo": new_memo}), 200
        else:
            # cloth_id는 있었지만, 왠지 모르게 업데이트가 안 됨
            return jsonify({"message": "메모 업데이트에 실패했습니다."}), 500

    except sqlite3.Error as e:
        if conn:
            conn.rollback()
        print(f"An error occurred in PATCH /clothes/<cloth_id>: {e}")
        return jsonify({"message": f"데이터베이스 오류: {e}"}), 500
    except Exception as e:
        print(f"An error occurred in PATCH /clothes/<cloth_id>: {e}")
        return jsonify({"message": f"서버 내부 오류: {e}"}), 500
    finally:
        if conn:
            conn.close()
# --- ▲▲▲ [신규 추가] 옷 메모 수정 (PATCH) API 엔드포인트 ▲▲▲ ---

# --- ▼▼▼ [추가] 일정 삭제 API 엔드포인트 ▼▼▼ ---
@app.route('/schedule/<int:schedule_id>', methods=['DELETE'])
def delete_schedule(schedule_id):
    conn = None
    try:
        conn = sqlite3.connect(DATABASE_NAME)
        cursor = conn.cursor()

        # 삭제하려는 일정이 존재하는지 먼저 확인 (선택 사항이지만 권장)
        cursor.execute("SELECT schedule_id FROM schedule WHERE schedule_id = ?", (schedule_id,))
        schedule_exists = cursor.fetchone()

        if not schedule_exists:
            return jsonify({"message": "삭제할 일정을 찾을 수 없습니다."}), 404

        # 일정 삭제 실행
        cursor.execute("DELETE FROM schedule WHERE schedule_id = ?", (schedule_id,))
        conn.commit()

        # 삭제된 행의 수가 0보다 크면 성공
        if conn.total_changes > 0:
            return jsonify({"message": "일정이 성공적으로 삭제되었습니다."}), 200
        else:
            # 혹시 모를 동시성 문제 등으로 삭제되지 않은 경우
            return jsonify({"message": "일정 삭제에 실패했습니다."}), 500

    except sqlite3.Error as e:
        if conn:
            conn.rollback() # 오류 발생 시 롤백
        print(f"An error occurred in DELETE /schedule/<schedule_id>: {e}")
        return jsonify({"message": f"데이터베이스 오류: {e}"}), 500
    except Exception as e:
        print(f"An error occurred in DELETE /schedule/<schedule_id>: {e}")
        return jsonify({"message": f"서버 내부 오류: {e}"}), 500
    finally:
        if conn:
            conn.close()
# --- ▲▲▲ [추가] 일정 삭제 API 엔드포인트 ▲▲▲ ---

# --- ▼▼▼ [수정] TPO 데이터 저장 로직 추가 ▼▼▼ ---
@app.route('/schedule', methods=['POST'])
def add_schedule():
    conn = None
    try:
        data = request.get_json()
        if not data:
            return jsonify({"message": "요청 본문이 비어있거나 JSON 형식이 아닙니다."}), 400

        email = data.get('email')
        title = data.get('title')

        if not email or not title:
            return jsonify({"message": "이메일과 일정 제목은 필수입니다."}), 400

        conn = sqlite3.connect(DATABASE_NAME)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()

        cursor.execute("SELECT id FROM users WHERE email = ?", (email,))
        user_row = cursor.fetchone()

        if user_row is None:
            return jsonify({"message": "사용자를 찾을 수 없습니다."}), 404
            
        user_id = user_row['id']
        
        cursor.execute('''
            INSERT INTO schedule (user_id, title, start_date, end_date, start_time, end_time, location_name, location_address, explanation, participants, recurrence_rule, alarm_unit, alarm_value, tpo1, tpo2)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            user_id, 
            title, 
            data.get('startDate'), 
            data.get('endDate'), 
            data.get('startTime'),
            data.get('endTime'),
            data.get('locationName'),
            data.get('locationAddress'),
            data.get('explanation'),
            data.get('participants'),
            data.get('recurrenceRule'),
            data.get('alarmUnit'),
            data.get('alarmValue'),
            data.get('tpo1'), # TPO1 데이터 추가
            data.get('tpo2')  # TPO2 데이터 추가
        ))
        conn.commit()
        
        return jsonify({"message": "일정이 성공적으로 추가되었습니다."}), 201

    except Exception as e:
        print(f"An error occurred in /schedule: {e}") 
        return jsonify({"message": f"서버 내부 오류가 발생했습니다: {e}"}), 500
    
    finally:
        if conn:
            conn.close()
# --- ▲▲▲ [수정] TPO 데이터 저장 로직 추가 ▲▲▲ ---

# --- ▼▼▼ [수정] TPO 데이터 조회 로직 추가 ▼▼▼ ---
@app.route('/schedule/<email>', methods=['GET'])
def get_schedules(email):
    if not email:
        return jsonify({"message": "이메일 정보가 필요합니다."}), 400

    conn = None
    try:
        conn = sqlite3.connect(DATABASE_NAME)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()

        cursor.execute("SELECT id FROM users WHERE email = ?", (email,))
        user_row = cursor.fetchone()

        if user_row is None:
            return jsonify({"message": "사용자를 찾을 수 없습니다."}), 404

        user_id = user_row['id']

        cursor.execute("SELECT * FROM schedule WHERE user_id = ?", (user_id,))
        schedule_rows = cursor.fetchall()
        
        schedule_list = [
            {
                "schedule_id": row["schedule_id"],
                "user_id": row["user_id"],
                "title": row["title"],
                "startDate": row["start_date"],
                "endDate": row["end_date"],
                "startTime": row["start_time"],
                "endTime": row["end_time"],
                "location": row["location_name"],
                "locationAddress": row["location_address"],
                "explanation": row["explanation"],
                "participants": row["participants"],
                "recurrenceRule": row["recurrence_rule"],
                "alarmUnit": row["alarm_unit"],
                "alarmValue": row["alarm_value"],
                "tpo1": row["tpo1"], # TPO1 데이터 추가
                "tpo2": row["tpo2"], # TPO2 데이터 추가
            }
            for row in schedule_rows
        ]
        
        return jsonify(schedule_list)

    except Exception as e:
        print(f"An error occurred in /schedule/<email>: {e}")   
        return jsonify({"message": f"서버 내부 오류: {e}"}), 500
    finally:
        if conn:
            conn.close()
# --- ▲▲▲ [수정] TPO 데이터 조회 로직 추가 ▲▲▲ ---

# --- ▼▼▼ [추가] 이미지 업로드 API 엔드포인트 ▼▼▼ ---
@app.route('/upload_image', methods=['POST'])
def upload_image():
    if 'image' not in request.files:
        return jsonify({'error': '이미지 파일이 없습니다.'}), 400
    file = request.files['image']
    if file.filename == '':
        return jsonify({'error': '선택된 파일이 없습니다.'}), 400
    if file and allowed_file(file.filename):
        # 파일 이름을 안전하게 만들고 저장 경로 생성
        filename = secure_filename(f"{datetime.now().strftime('%Y%m%d%H%M%S')}_{file.filename}")
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(filepath)
        
        # 클라이언트에게 돌려줄 이미지 접근 경로 (예: 상대 경로)
        # 실제 운영 시에는 전체 URL (http://서버IP:포트/uploads/파일명)을 반환하는 것이 좋음
        image_url = f"{UPLOAD_FOLDER}/{filename}" 
        
        return jsonify({'message': '이미지 업로드 성공', 'image_url': image_url}), 201
    else:
        return jsonify({'error': '허용되지 않는 파일 형식입니다.'}), 400
# --- ▲▲▲ [추가] 이미지 업로드 API 엔드포인트 ▲▲▲ ---

# --- ▼▼▼ [추가] 업로드된 이미지 파일을 서빙하는 엔드포인트 ▼▼▼ ---
from flask import send_from_directory

@app.route('/uploads/<filename>')
def uploaded_file(filename):
    # UPLOAD_FOLDER에서 파일을 찾아 반환
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)
# --- ▲▲▲ [추가] 업로드된 이미지 파일을 서빙하는 엔드포인트 ▲▲▲ ---

# --- ▼▼▼ [수정] 옷 추가 API (user_id 찾기, 오류 처리 추가) ▼▼▼ ---
@app.route('/clothes', methods=['POST'])
def add_cloth():
    data = request.get_json()
    email = data.get('email')
    name = data.get('name')
    clothingImg = data.get('clothingImg')

    if not email or not name:
        return jsonify({"message": "이메일과 옷 이름은 필수입니다."}), 400
    if not clothingImg:
         return jsonify({"message": "이미지 경로가 없습니다."}), 400

    conn = None # finally 에서 사용하기 위해 try 밖에 선언
    try:
        conn = sqlite3.connect(DATABASE_NAME)
        conn.row_factory = sqlite3.Row # 결과를 dictionary처럼 사용하기 위해 추가
        cursor = conn.cursor()

        # 1. 이메일로 user_id를 찾습니다.
        cursor.execute("SELECT id FROM users WHERE email = ?", (email,))
        user_row = cursor.fetchone()

        if user_row is None:
             # conn.close() 는 finally 에서 처리하므로 여기서 닫지 않음
             return jsonify({"message": "사용자를 찾을 수 없습니다."}), 404
        user_id = user_row['id']

        # 2. 찾은 user_id와 함께 옷 정보를 저장합니다.
        cursor.execute('''
            INSERT INTO clothes (user_id, name, subCategory, articleType, color, clothingImg, memo)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (user_id, name, data.get('subCategory'), data.get('articleType'), data.get('color'), clothingImg, data.get('memo')))
        conn.commit()
        return jsonify({"message": "옷이 성공적으로 추가되었습니다."}), 201

    except sqlite3.Error as e: # 데이터베이스 관련 오류 처리
        if conn:
            conn.rollback() # 오류 발생 시 롤백
        print(f"Database error in add_cloth: {e}")
        return jsonify({"message": f"데이터베이스 오류: {e}"}), 500
    except Exception as e: # 그 외 모든 예외 처리
        print(f"An error occurred in add_cloth: {e}")
        return jsonify({"message": f"서버 내부 오류: {e}"}), 500
    finally: # 성공하든 실패하든 항상 실행
        if conn:
            conn.close() # 데이터베이스 연결 종료
# --- ▲▲▲ [수정] 옷 추가 API (user_id 찾기, 오류 처리 추가) ▲▲▲ ---

# --- ▼▼▼ [추가] DataFrame Row를 JSON 직렬화 가능한 dict로 변환하는 함수 ▼▼▼ ---
def convert_row_to_serializable_dict(row):
            if row is None:
                return None
            
            serializable_dict = {}
            row_dict = row.to_dict()
            for key, value in row_dict.items():
                if pd.isna(value):
                    serializable_dict[key] = None
                elif isinstance(value, (np.int_, np.intc, np.intp, np.int8, np.int16, np.int32, np.int64, np.uint8, np.uint16, np.uint32, np.uint64)):
                    serializable_dict[key] = int(value)
                elif isinstance(value, (np.float16, np.float32, np.float64)):
                    serializable_dict[key] = float(value)
                elif isinstance(value, (np.ndarray,)): # Numpy 배열 처리 (필요시)
                    serializable_dict[key] = value.tolist() # 파이썬 리스트로 변환
                elif isinstance(value, (np.bool_)):
                    serializable_dict[key] = bool(value)
                else:
                    serializable_dict[key] = value # 나머지는 그대로 사용
            return serializable_dict
 # --- ▲▲▲ [추가] DataFrame Row를 JSON 직렬화 가능한 dict로 변환하는 함수 ▲▲▲ ---

# --- ▼▼▼ [수정] 오늘의 코디 추천 API (DB 컬럼명 'cloth_id'로 수정) ▼▼▼ ---
@app.route('/recommend_today', methods=['POST'])
def recommend_today():
    data = request.get_json()
    email = data.get('email')
    today_date_str = data.get('date')
    temperature = data.get('temperature') # 앱에서 보낸 온도 받기

    if not email or not today_date_str:
        return jsonify({"message": "이메일과 날짜 정보가 필요합니다."}), 400

    # 온도 데이터 처리
    try:
        temp_float = float(temperature) if temperature is not None else None
    except (ValueError, TypeError):
        print(f"Warning: Invalid temperature format received: {temperature}")
        temp_float = None

    conn = None
    try:
        today_date = datetime.strptime(today_date_str, '%Y-%m-%d').date()

        conn = sqlite3.connect(DATABASE_NAME)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()

        # 1. 사용자 ID 찾기
        cursor.execute("SELECT id FROM users WHERE email = ?", (email,))
        user_row = cursor.fetchone()
        if user_row is None: return jsonify({"message": "사용자를 찾을 수 없습니다."}), 404
        user_id = user_row['id']

        # 2. 오늘 첫 일정의 TPO 찾기
        cursor.execute("""
            SELECT tpo1, tpo2 FROM schedule
            WHERE user_id = ? AND date(start_date) = ?
            ORDER BY start_time ASC LIMIT 1
        """, (user_id, today_date_str))
        schedule_row = cursor.fetchone()

        tpo_mapping = {
            '일상&캐주얼': 'Casual & Daily',
            '비즈니스&포멀': 'Business & Formal',
            '특별한 날&데이트': 'Special Occasion & Date',
            '활동적인 날': 'Active Day'
        }
        today_tpo_raw = None
        if schedule_row:
            today_tpo_raw = schedule_row['tpo1'] if schedule_row['tpo1'] else schedule_row['tpo2']

        today_tpo = tpo_mapping.get(today_tpo_raw, 'Casual & Daily')
        if today_tpo not in TPO_SCORES:
             print(f"Warning: Mapped TPO '{today_tpo}' (from '{today_tpo_raw}') not found. Using 'Casual & Daily'.")
             today_tpo = 'Casual & Daily'

        print(f"Determined TPO for {today_date_str}: {today_tpo}")

        # 3. 사용자 옷 목록 가져오기 (DB 컬럼명 'cloth_id'로 수정)
        # --- ▼▼▼ [핵심 수정] 'id' -> 'cloth_id'로 변경 ▼▼▼ ---
        cursor.execute("SELECT cloth_id, name, subCategory, articleType, color, clothingImg FROM clothes WHERE user_id = ?", (user_id,))
        # --- ▲▲▲ [핵심 수정] 'id' -> 'cloth_id'로 변경 ▲▲▲ ---
        clothes_rows = cursor.fetchall()
        if not clothes_rows: return jsonify({"message": "옷장에 등록된 옷이 없습니다."}), 404
        user_clothes_df = pd.DataFrame([dict(row) for row in clothes_rows])

        # 4. 날씨 필터링
        weather_filtered_df = filter_by_weather(user_clothes_df, temp_float)
        if weather_filtered_df.empty:
            return jsonify({"message": f"{today_tpo}와 현재 날씨({temp_float}°C)에 맞는 옷이 옷장에 없습니다."}), 404

        # 5. TPO 점수 적용
        tpo_score_map = TPO_SCORES[today_tpo]
        weather_filtered_df['articleType'] = weather_filtered_df['articleType'].fillna('')
        weather_filtered_df['tpo_score'] = weather_filtered_df['articleType'].apply(lambda x: tpo_score_map.get(x, 0))

        # 6. 카테고리 분리 및 필터링
        topwear_df = weather_filtered_df[(weather_filtered_df['subCategory'] == '상의') & (weather_filtered_df['tpo_score'] > 0)].sort_values(by=['tpo_score', 'cloth_id'], ascending=[False, False])
        bottomwear_df = weather_filtered_df[(weather_filtered_df['subCategory'] == '하의') & (weather_filtered_df['tpo_score'] > 0)].sort_values(by=['tpo_score', 'cloth_id'], ascending=[False, False])
        shoes_df = weather_filtered_df[(weather_filtered_df['subCategory'] == '신발') & (weather_filtered_df['tpo_score'] > 0)].sort_values(by=['tpo_score', 'cloth_id'], ascending=[False, False])

        if topwear_df.empty or bottomwear_df.empty:
             return jsonify({"message": f"{today_tpo}와 날씨({temp_float}°C)에 맞는 상의 또는 하의가 없습니다."}), 404

        # 7. 색상 조합 고려하여 최종 코디 추천
        recommended_outfits_rows = []
        MAX_ITEMS_PER_CATEGORY = 5
        for _, top_row in topwear_df.head(MAX_ITEMS_PER_CATEGORY).iterrows():
            for _, bottom_row in bottomwear_df.head(MAX_ITEMS_PER_CATEGORY).iterrows():
                top_color = str(top_row['color']).lower() if pd.notna(top_row['color']) else None
                bottom_color = str(bottom_row['color']).lower() if pd.notna(bottom_row['color']) else None

                if get_color_matches(top_color, bottom_color):
                    current_base_score = top_row['tpo_score'] + bottom_row['tpo_score']
                    shoe_row = None
                    current_score = current_base_score
                    if not shoes_df.empty:
                        shoe_row = shoes_df.iloc[0]
                        current_score += shoe_row['tpo_score']
                    recommended_outfits_rows.append((top_row, bottom_row, shoe_row, current_score))

        if not recommended_outfits_rows:
             return jsonify({"message": f"{today_tpo}와 날씨({temp_float}°C), 색상 조합에 맞는 추천 코디를 찾을 수 없습니다."}), 404

        recommended_outfits_rows.sort(key=lambda x: x[3], reverse=True)
        top_5_outfits_rows = recommended_outfits_rows[:5]

        # 8. JSON 직렬화 가능한 dict 리스트로 변환
        top_5_outfits_serializable = []
        for top_r, bottom_r, shoes_r, score in top_5_outfits_rows:
            outfit = {
                'top': convert_row_to_serializable_dict(top_r),
                'bottom': convert_row_to_serializable_dict(bottom_r),
                'shoes': convert_row_to_serializable_dict(shoes_r),
                'score': float(score)
            }
            top_5_outfits_serializable.append(outfit)

        # 9. 코디 조합 저장 (DB 컬럼명 'cloth_id'로 수정)
        if top_5_outfits_serializable:
             try:
                 best_outfit = top_5_outfits_serializable[0]
                 # --- ▼▼▼ [핵심 수정] 'id' -> 'cloth_id'로 변경 ▼▼▼ ---
                 top_id = best_outfit['top']['cloth_id'] if best_outfit.get('top') else None
                 bottom_id = best_outfit['bottom']['cloth_id'] if best_outfit.get('bottom') else None
                 shoes_id = best_outfit['shoes']['cloth_id'] if best_outfit.get('shoes') else None
                 # --- ▲▲▲ [핵심 수정] 'id' -> 'cloth_id'로 변경 ▲▲▲ ---
                 outfit_name = f"{today_date_str} {today_tpo} 추천"

                 cursor.execute('''
                     INSERT INTO outfits (user_id, name, top_cloth_id, bottom_cloth_id, shoes_cloth_id, tpo_category)
                     VALUES (?, ?, ?, ?, ?, ?)
                 ''', (user_id, outfit_name, top_id, bottom_id, shoes_id, today_tpo))
                 conn.commit()
                 print(f"Top recommended outfit saved for user {user_id} with TPO '{today_tpo}'")
             except sqlite3.Error as db_err:
                 if conn: conn.rollback()
                 print(f"Error saving recommended outfit to DB: {db_err}")

        # 10. 결과 반환
        return jsonify({
            "recommended_outfits_list": top_5_outfits_serializable,
            "tpo": today_tpo
        })

    except sqlite3.Error as e: print(f"Database error in /recommend_today: {e}"); return jsonify({"message": f"데이터베이스 오류: {e}"}), 500
    except ValueError as e: print(f"Value error in /recommend_today: {e}"); return jsonify({"message": f"잘못된 입력값 오류: {e}"}), 400
    except Exception as e: print(f"An error occurred in /recommend_today: {e}"); return jsonify({"message": f"서버 내부 오류: {e}"}), 500
    finally:
        if conn: conn.close()
# --- ▲▲▲ [수정] 오늘의 코디 추천 API ▲▲▲ ---

# --- ▼▼▼ [추가] 저장된 코디 목록(outfits)을 TPO별로 조회하는 API ▼▼▼ ---
@app.route('/outfits/<email>', methods=['GET'])
def get_user_outfits(email):
    conn = None
    try:
        conn = sqlite3.connect(DATABASE_NAME)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()

        # 1. 이메일로 user_id 찾기
        cursor.execute("SELECT id FROM users WHERE email = ?", (email,))
        user_row = cursor.fetchone()
        if user_row is None:
            return jsonify({"message": "사용자를 찾을 수 없습니다."}), 404
        user_id = user_row['id']

        # 2. 쿼리 파라미터에서 TPO 필터 값 가져오기
        # (예: /outfits/aaa@aaa.com?tpo=Casual%20%26%20Daily)
        tpo_filter = request.args.get('tpo')

        # 3. SQL 쿼리 작성
        # outfits 테이블(o)과 clothes 테이블(t, b, s)을 3번 JOIN
        base_query = """
            SELECT
                o.outfit_id, o.name as outfit_name, o.tpo_category, o.created_at,
                
                -- 상의(top) 정보 (clothes 테이블 PK가 'cloth_id'인지 확인!)
                t.cloth_id as top_cloth_id, t.name as top_name, t.clothingImg as top_clothingImg,
                t.color as top_color, t.articleType as top_articleType, t.subCategory as top_subCategory,
                
                -- 하의(bottom) 정보
                b.cloth_id as bottom_cloth_id, b.name as bottom_name, b.clothingImg as bottom_clothingImg,
                b.color as bottom_color, b.articleType as bottom_articleType, b.subCategory as bottom_subCategory,
                
                -- 신발(shoes) 정보
                s.cloth_id as shoes_cloth_id, s.name as shoes_name, s.clothingImg as shoes_clothingImg,
                s.color as shoes_color, s.articleType as shoes_articleType, s.subCategory as shoes_subCategory
                
            FROM outfits o
            LEFT JOIN clothes t ON o.top_cloth_id = t.cloth_id
            LEFT JOIN clothes b ON o.bottom_cloth_id = b.cloth_id
            LEFT JOIN clothes s ON o.shoes_cloth_id = s.cloth_id
            WHERE o.user_id = ?
        """
        params = [user_id] # SQL 쿼리에 바인딩할 파라미터 리스트

        # TPO 필터가 있으면 쿼리에 추가
        if tpo_filter:
            base_query += " AND o.tpo_category = ?"
            params.append(tpo_filter)
        
        base_query += " ORDER BY o.created_at DESC" # 최신순 정렬

        cursor.execute(base_query, tuple(params))
        outfit_rows = cursor.fetchall()

        # 4. 결과를 앱이 원하는 JSON 구조(중첩된 dict)로 포맷팅
        outfits_list = []
        for row in outfit_rows:
            outfit = {
                "outfit_id": row["outfit_id"],
                "outfit_name": row["outfit_name"],
                "tpo_category": row["tpo_category"],
                "created_at": row["created_at"],
                # 상의 정보가 있을 때(top_cloth_id가 NULL이 아닐 때)만 dict 생성
                "top": {
                    "cloth_id": row["top_cloth_id"],
                    "name": row["top_name"],
                    "clothingImg": row["top_clothingImg"],
                    "color": row["top_color"],
                    "articleType": row["top_articleType"],
                    "subCategory": row["top_subCategory"]
                } if row["top_cloth_id"] is not None else None,
                # 하의 정보
                "bottom": {
                    "cloth_id": row["bottom_cloth_id"],
                    "name": row["bottom_name"],
                    "clothingImg": row["bottom_clothingImg"],
                    "color": row["bottom_color"],
                    "articleType": row["bottom_articleType"],
                    "subCategory": row["bottom_subCategory"]
                } if row["bottom_cloth_id"] is not None else None,
                # 신발 정보
                "shoes": {
                    "cloth_id": row["shoes_cloth_id"],
                    "name": row["shoes_name"],
                    "clothingImg": row["shoes_clothingImg"],
                    "color": row["shoes_color"],
                    "articleType": row["shoes_articleType"],
                    "subCategory": row["shoes_subCategory"]
                } if row["shoes_cloth_id"] is not None else None
            }
            outfits_list.append(outfit)

        # 5. 최종 JSON 리스트 반환
        return jsonify(outfits_list)

    except sqlite3.Error as e:
        print(f"Error fetching outfits: {e}")
        return jsonify({"message": f"데이터베이스 오류: {e}"}), 500
    except Exception as e:
        print(f"An error occurred in /outfits/<email>: {e}")
        return jsonify({"message": f"서버 내부 오류: {e}"}), 500
    finally:
        if conn:
            conn.close()
# --- ▲▲▲ [추가] 저장된 코디 목록(outfits)을 TPO별로 조회하는 API ▲▲▲ ---

# --- ▼▼▼ [추가] 선택된 코디 다중 삭제 API 엔드포인트 ▼▼▼ ---
@app.route('/outfits/delete', methods=['POST'])
def delete_outfits():
    data = request.get_json()
    outfit_ids = data.get('outfit_ids') # Flutter에서 보낸 ID 리스트

    if not outfit_ids or not isinstance(outfit_ids, list):
        return jsonify({"message": "삭제할 코디 ID 리스트(outfit_ids)가 필요합니다."}), 400

    conn = None
    try:
        conn = sqlite3.connect(DATABASE_NAME)
        cursor = conn.cursor()

        # 리스트에 있는 모든 ID를 순회하며 삭제
        # (더 효율적인 방법: 'DELETE FROM outfits WHERE outfit_id IN (?, ?, ...)' 
        #  하지만 이 방식이 구현하기 더 간단합니다.)
        deleted_count = 0
        for outfit_id in outfit_ids:
            cursor.execute("DELETE FROM outfits WHERE outfit_id = ?", (outfit_id,))
            if cursor.rowcount > 0:
                deleted_count += 1
        
        conn.commit()

        return jsonify({
            "message": f"총 {len(outfit_ids)}개 요청 중 {deleted_count}개의 코디가 삭제되었습니다."
        }), 200

    except sqlite3.Error as e:
        if conn:
            conn.rollback()
        print(f"An error occurred in POST /outfits/delete: {e}")
        return jsonify({"message": f"데이터베이스 오류: {e}"}), 500
    except Exception as e:
        print(f"An error occurred in POST /outfits/delete: {e}")
        return jsonify({"message": f"서버 내부 오류: {e}"}), 500
    finally:
        if conn:
            conn.close()
# --- ▲▲▲ [추가] 선택된 코디 다중 삭제 API 엔드포인트 ▲▲▲ ---

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)